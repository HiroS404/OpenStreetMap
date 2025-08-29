import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
// import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:map_try/model/route_loader.dart';
import 'package:map_try/services/mapbox_service.dart';
import 'package:map_try/services/ors_service.dart';

const String kYourOrsApiKey =
    "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImE5MGM0OTU0Nzg1ODRmNzdiZGJhZWFiYWVkYTY1ODE1IiwiaCI6Im11cm11cjY0In0=";

// --- bearing utilities ---
double bearing(LatLng from, LatLng to) {
  final dLon = (to.longitude - from.longitude) * pi / 180;
  final lat1 = from.latitude * pi / 180;
  final lat2 = to.latitude * pi / 180;

  final y = sin(dLon) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

bool isForward(
  double routeBearing,
  double targetBearing, {
  double tolerance = 60,
}) {
  // normalize difference to [-180, 180]
  double diff = (routeBearing - targetBearing + 540) % 360 - 180;
  return diff.abs() <= tolerance;
}

// for walking distance and polylines
final Distance _distance = Distance();
double walkingDistance = 0.0;
List<Polyline> walkingPolylines = [];
double segmentDistance = 0.0;

double endWalkingDistance = 0.0;
List<Polyline> endWalkingPolylines = [];

// Find nearest point on all jeepney routes
LatLng findNearestPointOnAllRoutes(
  LatLng userLocation,
  List<JeepneyRoute> allRoutes,
) {
  LatLng? nearestPoint;
  double minDistance = double.infinity;

  for (final route in allRoutes) {
    for (final coord in route.coordinates) {
      final double dist = _distance(userLocation, coord);
      if (dist < minDistance) {
        minDistance = dist;
        nearestPoint = coord;
      }
    }
  }

  return nearestPoint!;
}

//dotted line for walking distance
// Builds a dotted polyline from a full path.
// Each small segment is drawn, then a gap, then another segment, etc.
List<Polyline> createDottedPolyline(
  List<LatLng> path, {
  double dashLengthMeters = 8, // length of each drawn dash
  double gapLengthMeters = 6, // length of the gap
  double strokeWidth = 3,
  Color color = Colors.blue,
}) {
  final List<Polyline> out = [];
  if (path.length < 2) return out;

  // simple linear interpolation between two points
  LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t,
  );

  for (int i = 0; i < path.length - 1; i++) {
    final a = path[i];
    final b = path[i + 1];
    final double segDist = _distance.as(LengthUnit.Meter, a, b);
    if (segDist <= 0) continue;

    double pos = 0.0;
    while (pos < segDist) {
      final double end = (pos + dashLengthMeters).clamp(0.0, segDist);
      final double t1 = pos / segDist;
      final double t2 = end / segDist;

      out.add(
        Polyline(
          points: [_lerp(a, b, t1), _lerp(a, b, t2)],
          color: color,
          strokeWidth: strokeWidth,
        ),
      );

      pos += dashLengthMeters + gapLengthMeters;
    }
  }
  return out;
}

//Main OpenStreetMap screen

class OpenstreetmapScreen extends StatefulWidget {
  final ValueNotifier<LatLng?> destinationNotifier;

  const OpenstreetmapScreen({super.key, required this.destinationNotifier});

  @override
  State<OpenstreetmapScreen> createState() => _OpenstreetmapScreenState();
}

class _OpenstreetmapScreenState extends State<OpenstreetmapScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  late final ValueNotifier<LatLng?> _destinationNotifier;

  LatLng? _destination;
  List<LatLng> _route = [];
  List<JeepneyRoute> allRoutes = [];
  JeepneyRoute? _matchedRoute;
  bool _isModalOpen = false;

  bool isLoading = true;

  final Map<String, List<LatLng>> _orsCache = {};
  bool _isRequestingWalking = false;
  late OrsService _orsService;

  List<Polyline> _startWalkingPolylines = []; // walk from user to jeepney start
  List<Polyline> _endWalkingPolylines =
      []; // walk from jeepney end to destination
  bool _walkingPolylinesCalculated = false;

  @override
  void initState() {
    super.initState();
    _destinationNotifier = widget.destinationNotifier;
    _orsService = OrsService(kYourOrsApiKey);

    _initializeLocation().then((_) {
      _destinationNotifier.addListener(() {
        final newDestination = _destinationNotifier.value;
        if (newDestination != null && _currentLocation != null) {
          _destination = newDestination;
          loadRouteData();
          // print("Current Location: $_currentLocation");
          // print(
          //   "New Destination: $newDestination",
          // ); // uses jeepney route, not OSRM anymore (route base on jeepney_routes.json)
        }
      });
    });
  }

  // helper to create a cache key
  String _orsCacheKey(LatLng a, LatLng b, String profile) =>
      '${a.latitude},${a.longitude}_${b.latitude},${b.longitude}_$profile';

  // call this after you set _matchedRoute, _currentLocation or _destination
  Future<void> _updateAllWalkingPolylines() async {
    if (_currentLocation == null ||
        _destination == null ||
        _matchedRoute == null) {
      return;
    }

    final segment = findBestRouteSegment(
      _currentLocation!,
      _destination!,
      _matchedRoute!.coordinates,
    );

    if (segment == null) return;

    // Clear existing polylines
    setState(() {
      _startWalkingPolylines = [];
      _endWalkingPolylines = [];
    });

    // Get jeepney start and end points
    final LatLng jeepneyStartPoint =
        _matchedRoute!.coordinates[segment.startIndex];
    final LatLng jeepneyEndPoint = _matchedRoute!.coordinates[segment.endIndex];

    // Update walking distances
    walkingDistance = segment.startWalkDistance;
    endWalkingDistance = segment.endWalkDistance;

    // Create both walking routes concurrently
    final futures = <Future<void>>[];

    // Start walking route (user → jeepney start)
    if (segment.startWalkDistance > 10) {
      futures.add(
        _orsService
            .getRoute(
              _currentLocation!,
              jeepneyStartPoint,
              profile: "foot-walking",
            )
            .then((route) {
              if (route != null && mounted) {
                setState(() {
                  _startWalkingPolylines = createDottedPolyline(
                    route,
                    color: Colors.blue,
                    strokeWidth: 3,
                  );
                });
              }
            }),
      );
    }

    // End walking route (jeepney end → destination)
    if (segment.endWalkDistance > 10) {
      futures.add(
        _orsService
            .getRoute(jeepneyEndPoint, _destination!, profile: "foot-walking")
            .then((route) {
              if (route != null && mounted) {
                setState(() {
                  _endWalkingPolylines = createDottedPolyline(
                    route,
                    color: Colors.green,
                    strokeWidth: 3,
                  );
                });
              }
            }),
      );
    }

    // Wait for both requests to complete
    await Future.wait(futures);

    setState(() {
      _walkingPolylinesCalculated = true;
    });
  }

  //location initialization
  Future<void> _initializeLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError("Location services are disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError("Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError("Location permissions are permanently denied.");
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      isLoading = false;
    });
    loadRouteData();

    // For debugging DO NOT DELETE: Use a fixed location in Iloilo City
    const LatLng debuggingLocation = LatLng(
      // 10.732143,
      // 122.559791, //tabuc suba jollibe
      // 10.731958,
      // 122.560223, //sulodlon debug
      // 10.732178,
      // 122.559673, //tabuc suba sa piyak
      // 10.733472,
      // 122.548947, //tubang CPU
      10.732610,
      122.548220, // mt building
      // 10.715609,
      // 122.562715, // ColdZone West
      // 10.725203,
      // 122.556715, //Jaro plaza
      // 10.696694,
      // 122.545582, //Molo Plazas
      // 10.694928, 122.564686, //Rob Main
      // 10.753623,
      // 122.538430, //Gt mall
      // 10.714335,
      // 122.551852, // Sm City
      // 10.731993,
      // 122.549291, //promenade cpu
      // 10.692037,
      // 122.583255, // CT Parola
      // 10.726009,
      // 122.557774, // lapit alicias ah
      // 10.726947,
      // 122.558021, // lapit pgd
      // 10.695724,
      // 122.566170
      // Center city proper
      // 10.695522,
      // 122.566212
      // Center City proper across
    );

    setState(() {
      _currentLocation = debuggingLocation;
      isLoading = false;
    });
    _destinationNotifier.value = const LatLng(
      // 10.731068,
      // 122.551723, //sarap station
      // 10.732143, 122.559791, //tabuc suba jollibe
      // 10.715609,
      // 122.562715, // ColdZone West
      10.716225933976629,
      122.56377696990968, // somewhere further coldzone west
      // 10.733472,
      // 122.548947, //tubang CPU
      // 10.696694, 122.545582, //Molo Plazas
      // 10.694928,
      // 122.564686, //Rob Main
      // 10.753623,
      // 122.538430, //Gt mall
      // 10.727482,
      // 122.558188, // alicias
      // 10.714335,
      // 122.551852, // Sm City
      // 10.697643,
      // 122.543888 // Molo
      // 10.693202,
      // 122.500595, // mohon term
    ); // your test destination
    _destination = _destinationNotifier.value;

    loadRouteData(); // Load jeepney routes based on this location
  }

  //initial map zoom and center
  void _fitMapToRoute() {
    if (_route.isEmpty) return;

    final latitudes = _route.map((p) => p.latitude).toList();
    final longitudes = _route.map((p) => p.longitude).toList();

    final southWest = LatLng(latitudes.reduce(min), longitudes.reduce(min));

    final northEast = LatLng(latitudes.reduce(max), longitudes.reduce(max));

    final center = LatLng(
      (southWest.latitude + northEast.latitude) / 2,
      (southWest.longitude + northEast.longitude) / 2,
    );

    _mapController.move(center, 15.0);
  }

  //getting route and displaying
  Future<void> fetchRoute(LatLng destination) async {
    if (_currentLocation == null) return;

    final url = Uri.parse(
      "https://router.project-osrm.org/route/v1/driving/"
      "${_currentLocation!.longitude},${_currentLocation!.latitude};"
      "${destination.longitude},${destination.latitude}?overview=full&geometries=polyline",
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['routes'].isNotEmpty) {
        final geometry = data['routes'][0]['geometry'];
        _decodePolyline(geometry);
        _fitMapToRoute();
      } else {
        _showError('No route found');
      }
    } else {
      _showError('Error fetching route');
    }
  }

  //polyline decoding
  void _decodePolyline(String encodedPolyline) {
    final polylinePoints = PolylinePoints();
    final decodePoints = polylinePoints.decodePolyline(encodedPolyline);

    setState(() {
      _route =
          decodePoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
    });
  }

  //displaying user current location
  Future<void> _userCurrentLocation() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fetching location...')));
      await _initializeLocation();
    } else {
      _mapController.move(_currentLocation!, 15.0);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  //loading jeepney routes from jepney_routes.json and matching with user location and destination
  //loading jeepney routes from jepney_routes.json and matching with user location and destination
  void loadRouteData() async {
    List<JeepneyRoute> jeepneyRoutes = await loadRoutesFromJson();
    if (!mounted || _currentLocation == null || _destination == null) return;

    allRoutes = getTopNearbyRoutes(
      _currentLocation!,
      _destination!,
      jeepneyRoutes,
    );

    final matchingRoute = getMatchingRoute(
      _currentLocation!,
      _destination!,
      jeepneyRoutes,
    );

    if (matchingRoute != null) {
      // find closest indices along the matched route
      final int startIndex = getClosestPointIndex(
        matchingRoute.coordinates,
        _currentLocation!,
      );
      final int endIndex = getClosestPointIndex(
        matchingRoute.coordinates,
        _destination!,
      );

      // enforce ordering (start must be before end)
      final int fromIndex = startIndex < endIndex ? startIndex : endIndex;
      final int toIndex = startIndex < endIndex ? endIndex : startIndex;

      final segment = matchingRoute.coordinates.sublist(fromIndex, toIndex + 1);
      segmentDistance = calculateSegmentDistance(segment);

      setState(() {
        _route = segment;
        _matchedRoute = matchingRoute;
        _walkingPolylinesCalculated = false; // Reset flag
      });

      // Update walking polylines
      _updateAllWalkingPolylines();
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                "No matching jeepney route found from your location to destination.",
              ),
              duration: Duration(seconds: 8),
            ),
          );
      }
    }
  }

  //showing route modal with details (button will be shown if a route is matched)
  void showRouteModal(BuildContext context) {
    _isModalOpen = true;
    final animationController = BottomSheet.createAnimationController(this);
    animationController.duration = const Duration(milliseconds: 1000);
    animationController.reverseDuration = const Duration(milliseconds: 300);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      transitionAnimationController: animationController,
      builder: (context) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          padding: MediaQuery.of(context).viewInsets,
          child: FractionallySizedBox(
            heightFactor: 1,
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.2,
              maxChildSize: 1.0,
              builder: (context, scrollController) {
                return NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    if (notification.extent <= notification.minExtent + 0.05) {
                      Navigator.of(context).pop();
                      _isModalOpen = false;
                    }
                    return true;
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: ListView(
                      controller: scrollController,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),

                        // STEP 1: Walk to jeepney start
                        ListTile(
                          leading: const Icon(
                            Icons.directions_walk,
                            color: Colors.blue,
                          ),
                          title: const Text(
                            "Step 1: Walk to the nearest jeep route",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            walkingDistance > 10
                                ? "Walk ${walkingDistance.toStringAsFixed(0)} meters (${getWalkingTimeEstimate(walkingDistance)})"
                                : "You are already at the jeepney route!",
                          ),
                        ),
                        const SizedBox(height: 8),

                        // STEP 2: Ride the jeepney
                        ListTile(
                          leading: const Icon(
                            Icons.directions_bus,
                            color: Colors.orange,
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Step 2: Ride Jeepney Route ${_matchedRoute?.routeNumber ?? ''}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepOrangeAccent,
                                ),
                              ),
                              Image.asset(
                                "Assets/route_pics/${_matchedRoute?.routeNumber}.png",
                                height: 250,
                                width: 250,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (context, error, stackTrace) => Container(
                                      height: 120,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            "Route Direction: ${_matchedRoute?.direction ?? ''}\n"
                            "Ride Distance: ${(segmentDistance / 1000).toStringAsFixed(2)} km\n"
                            "Estimated Travel Time: ${estimateJeepneyTime(segmentDistance)}",
                          ),
                        ),
                        const SizedBox(height: 8),

                        // STEP 3: Walk to destination (NEW)
                        ListTile(
                          leading: const Icon(
                            Icons.directions_walk,
                            color: Colors.green,
                          ),
                          title: const Text(
                            "Step 3: Walk to your destination",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            endWalkingDistance > 10
                                ? "Walk ${endWalkingDistance.toStringAsFixed(0)} meters (${getWalkingTimeEstimate(endWalkingDistance)})"
                                : "You'll arrive directly at your destination!",
                          ),
                        ),
                        const SizedBox(height: 16),

                        // SUMMARY
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Trip Summary",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.directions_walk,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Walk: ${(walkingDistance + endWalkingDistance).toStringAsFixed(0)}m",
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.directions_bus,
                                    size: 16,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Ride: ${(segmentDistance / 1000).toStringAsFixed(2)}km",
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.timer,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Total Est. Time: ${_getTotalEstimatedTime()}",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ).whenComplete(() {
      _isModalOpen = false;
    });
  }

  // ADD this helper function for total time calculation
  String _getTotalEstimatedTime() {
    final walkTime1 = walkingDistance / 1.4; // seconds
    final walkTime2 = endWalkingDistance / 1.4; // seconds
    final totalWalkSeconds = walkTime1 + walkTime2;

    final jeepneyMinutes = segmentDistance / 333.33; // minutes
    final totalWalkMinutes = totalWalkSeconds / 60;

    final totalMinutes = jeepneyMinutes + totalWalkMinutes;

    return "${totalMinutes.toStringAsFixed(1)} minutes";
  }

  //unco
  // ignore: unused_element
  JeepneyRoute _getClosestRoute(List<JeepneyRoute> routes) {
    double closestDistance = double.infinity;
    JeepneyRoute? closestRoute;

    for (var route in routes) {
      for (LatLng point in route.coordinates) {
        double distance = _calculateDistance(_currentLocation!, point);
        if (distance < closestDistance) {
          closestDistance = distance;
          closestRoute = route;
        }
      }
    }

    return closestRoute ?? routes.first;
  }

  // Improved function to get closest point index with direction consideration
  int getClosestPointIndex(List<LatLng> coords, LatLng target) {
    final distance = Distance();
    double minDist = double.infinity;
    int closestIndex = -1;

    for (int i = 0; i < coords.length; i++) {
      final d = distance.as(LengthUnit.Meter, target, coords[i]);
      if (d < minDist) {
        minDist = d;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  JeepneyRoute? getMatchingRoute(
    LatLng current,
    LatLng destination,
    List<JeepneyRoute> routes,
  ) {
    RouteSegment? bestSegment;
    JeepneyRoute? bestRoute;
    double bestScore = double.infinity;

    for (final route in routes) {
      final segment = findBestRouteSegment(
        current,
        destination,
        route.coordinates,
      );

      if (segment != null) {
        double score = segment.totalCost; // ✅ use total cost
        if (score < bestScore) {
          bestScore = score;
          bestSegment = segment;
          bestRoute = route;
        }

        // print(
        //   "Route ${route.routeNumber}: "
        //   "startIndex=${segment.startIndex}, "
        //   "endIndex=${segment.endIndex}, "
        //   "walkStart=${segment.startWalkDistance.toStringAsFixed(0)}m, "
        //   "ride=${segment.rideDistance.toStringAsFixed(0)}m, "
        //   "walkEnd=${segment.endWalkDistance.toStringAsFixed(0)}m, "
        //   "totalCost=${segment.totalCost.toStringAsFixed(0)}",
        // );
      }
    }

    if (bestRoute != null && bestSegment != null) {
      // print("Best route selected: ${bestRoute.routeNumber}");
    }

    return bestRoute;
  }

  List<JeepneyRoute> getTopNearbyRoutes(
    LatLng current,
    LatLng destination,
    List<JeepneyRoute> routes, {
    int limit = 999, // routes debugger colorerd
  }) {
    List<MapEntry<JeepneyRoute, double>> scoredRoutes = [];

    for (final route in routes) {
      double currentDist = route.minDistanceToPoint(current);
      double destinationDist = route.minDistanceToPoint(destination);

      double score = currentDist + destinationDist; // total distance score

      scoredRoutes.add(MapEntry(route, score));
    }

    // Sort by distance
    scoredRoutes.sort((a, b) => a.value.compareTo(b.value));

    // Return top 'limit' routes
    return scoredRoutes.take(limit).map((e) => e.key).toList();
  }

  //trying matvhing locgic (route segment from current to destination)

  // Updated extractSegment function to work with RouteSegment
  List<LatLng> extractSegmentFromRoute(
    LatLng current,
    LatLng destination,
    List<LatLng> coords,
  ) {
    final segment = findBestRouteSegment(current, destination, coords);

    if (segment != null) {
      return coords.sublist(segment.startIndex, segment.endIndex + 1);
    } else {
      return [];
    }
  }

  //haversine formulaaaa (for earth radius)
  double _calculateDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371;
    double dLat = _degToRad(b.latitude - a.latitude);
    double dLon = _degToRad(b.longitude - a.longitude);
    double lat1 = _degToRad(a.latitude);
    double lat2 = _degToRad(b.latitude);

    double aCalc =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(aCalc), sqrt(1 - aCalc));

    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (pi / 180.0);
  //for walking time estimation
  String getWalkingTimeEstimate(double distanceInMeters) {
    if (distanceInMeters <= 0) return '';

    // Estimate time in seconds
    final seconds = distanceInMeters / 1.4;

    if (seconds < 60) {
      return "~${seconds.toStringAsFixed(0)} seconds";
    } else {
      final minutes = seconds / 60;
      return "~${minutes.toStringAsFixed(0)} minutes";
    }
  }

  //calulate segment distance in meters
  double calculateSegmentDistance(List<LatLng> segment) {
    final Distance distance = Distance();
    double total = 0.0;

    for (int i = 0; i < segment.length - 1; i++) {
      total += distance.as(LengthUnit.Meter, segment[i], segment[i + 1]);
    }

    return total;
  }

  //calculate time for current loc to destination estimated
  String estimateJeepneyTime(double distanceMeters) {
    const double jeepneySpeedMetersPerMinute = 333.33; // ≈ 20 km/h
    final double timeInMinutes = distanceMeters / jeepneySpeedMetersPerMinute;
    return "${timeInMinutes.toStringAsFixed(1)} minutes";
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    //dotted line
    if (_currentLocation != null &&
        allRoutes.isNotEmpty &&
        _destination != null) {
      final segment = findBestRouteSegment(
        _currentLocation!,
        _destination!,
        _matchedRoute?.coordinates ?? [],
      );

      if (segment != null && _matchedRoute != null) {
        final ors = OrsService("YOUR_ORS_API_KEY");

        // Start walking polyline (current location → jeepney start)
        if (segment.startWalkDistance > 10) {
          final LatLng jeepneyStartPoint =
              _matchedRoute!.coordinates[segment.startIndex];
          walkingDistance = segment.startWalkDistance;

          ors
              .getRoute(
                _currentLocation!,
                jeepneyStartPoint,
                profile: "foot-walking",
              )
              .then((orsRoute) {
                if (orsRoute != null) {
                  setState(() {
                    walkingPolylines = createDottedPolyline(
                      orsRoute,
                      color: Colors.blue,
                    );
                  });
                }
              });
        } else {
          walkingDistance = 0;
          walkingPolylines = [];
        }

        // End walking polyline (jeepney end → destination)
        if (segment.endWalkDistance > 10) {
          final LatLng jeepneyEndPoint =
              _matchedRoute!.coordinates[segment.endIndex];
          endWalkingDistance = segment.endWalkDistance;

          ors
              .getRoute(jeepneyEndPoint, _destination!, profile: "foot-walking")
              .then((orsRoute) {
                if (orsRoute != null) {
                  setState(() {
                    endWalkingPolylines = createDottedPolyline(
                      orsRoute,
                      color: Colors.green,
                    );
                  });
                }
              });
        } else {
          endWalkingDistance = 0;
          endWalkingPolylines = [];
        }
      } else {
        // Fallback to old logic if no segment found
        final bool isNear = allRoutes.any(
          (route) => route.isPointNearRoute(_currentLocation!, 10),
        );

        if (!isNear) {
          final LatLng nearestPoint = findNearestPointOnAllRoutes(
            _currentLocation!,
            allRoutes,
          );

          walkingDistance = Distance().as(
            LengthUnit.Meter,
            _currentLocation!,
            nearestPoint,
          );

          final ors = OrsService("YOUR_ORS_API_KEY");

          ors
              .getRoute(
                _currentLocation!,
                nearestPoint,
                profile: "foot-walking",
              )
              .then((orsRoute) {
                if (orsRoute != null) {
                  setState(() {
                    walkingPolylines = createDottedPolyline(
                      orsRoute,
                      color: Colors.blue,
                    );
                  });
                }
              });
        } else {
          walkingDistance = 0;
          walkingPolylines = [];
        }

        // Clear end walking polylines if no segment
        endWalkingDistance = 0;
        endWalkingPolylines = [];
      }
    }
    //main OpenStreetMap widget with layers and controls
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              title: const Text(
                'MAPAkaon',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrangeAccent,
                ),
              ),
              centerTitle: true,
              backgroundColor: const Color.fromRGBO(255, 255, 255, 0.01),
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.map, color: Colors.deepOrangeAccent),
                  onPressed: () {
                    // Navigator.pushNamed(context, '/login');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentLocation ?? const LatLng(10.7202, 122.5621),
          initialZoom: 14.0,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://api.mapbox.com/styles/v1/$styleId/tiles/256/{z}/{x}/{y}@2x?access_token=$mapboxAccess',
            tileProvider: CancellableNetworkTileProvider(),
          ),
          CurrentLocationLayer(
            style: LocationMarkerStyle(
              marker: DefaultLocationMarker(
                child: Icon(Icons.location_pin, color: Colors.blue),
              ),
              markerSize: const Size(35, 35),
              markerDirection: MarkerDirection.heading,
            ),
          ),

          // START Walking dotted line (current to jeepney start) - BLUE
          if (_startWalkingPolylines.isNotEmpty)
            PolylineLayer(polylines: _startWalkingPolylines),

          // END Walking dotted line (jeepney end to destination) - GREEN
          if (_endWalkingPolylines.isNotEmpty)
            PolylineLayer(polylines: _endWalkingPolylines),

          // Jeepney route segment - ORANGE
          if (_route.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _route,
                  color: const Color.fromARGB(255, 255, 143, 0),
                  strokeWidth: 4,
                ),
              ],
            ),

          // Current location debugger for fixed location
          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.person_pin_circle_outlined,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

          // Destination marker
          if (_destinationNotifier.value != null)
            MarkerLayer(
              markers: [
                Marker(
                  width: 50.0,
                  height: 50.0,
                  point: _destinationNotifier.value!,
                  child: const Icon(
                    Icons.location_pin,
                    size: 40,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'user-location-fab',
              onPressed: _userCurrentLocation,
              backgroundColor: Colors.orangeAccent,
              child: const Icon(
                Icons.my_location,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
          if (_matchedRoute != null)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton.extended(
                label: const Text('Route'),
                icon: const Icon(Icons.route),
                backgroundColor: Colors.white,
                onPressed: () {
                  if (!_isModalOpen) {
                    showRouteModal(context);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
//for debugging route
// Color _getColorForRoute(String routeNumber) {
//   switch (routeNumber) {
//     // case '3':
//     //   return const Color.fromARGB(255, 51, 181, 103);
//     // case '11':
//     //   return const Color.fromARGB(255, 233, 23, 248);
//     // case '15':
//     //   return const Color.fromARGB(255, 255, 77, 0);
//     // case '2':
//     //   return const Color.fromARGB(255, 255, 204, 0);
//     // case '4':
//     //   return const Color.fromARGB(255, 72, 233, 77);
//     //   case '5':
//     //   return const Color.fromARGB(255, 0, 26, 255);
//     // case '25':
//     //   return const Color.fromARGB(255, 255, 234, 0);
//     // case '1':
//     //   return const Color.fromARGB(255, 255, 255, 255);
//     // case '7':
//     //   return const Color.fromARGB(255, 87, 25, 78);
//     // case '9':
//     //   return const Color.fromARGB(255, 66, 41, 28);
//     // // case '1A':
//     // //   return const Color.fromARGB(255, 210, 92, 131);
//     // // case '1B':
//     // //   return const Color.fromARGB(255, 11, 50, 243);
//     default:
//       return Colors.transparent; // Default color if route number not matched
//   }
// }

// Function to find the best segment considering route direction
RouteSegment? findBestRouteSegment(
  LatLng current,
  LatLng destination,
  List<LatLng> coords, {
  double maxWalkDistance = 200,
  double snapThreshold = 25, // allow across-street snapping
}) {
  final distance = Distance();
  final targetBearing = bearing(current, destination);

  List<RouteSegment> candidates = [];

  for (int i = 0; i < coords.length - 1; i++) {
    final segBearing = bearing(coords[i], coords[i + 1]);
    final dStart = distance.as(LengthUnit.Meter, current, coords[i]);

    // Skip far away points
    if (dStart > maxWalkDistance && dStart > snapThreshold) continue;

    // Snap-to-route override OR forward check
    if (dStart <= snapThreshold ||
        isForward(segBearing, targetBearing, tolerance: 60)) {
      // Find best endIndex after i
      int? bestEnd;
      double bestEndDist = double.infinity;
      for (int j = i + 1; j < coords.length; j++) {
        final dEnd = distance.as(LengthUnit.Meter, destination, coords[j]);
        if (dEnd < bestEndDist && dEnd <= maxWalkDistance) {
          bestEnd = j;
          bestEndDist = dEnd;
        }
      }
      if (bestEnd == null) continue;

      // Compute ride distance
      double rideDist = 0.0;
      for (int k = i; k < bestEnd; k++) {
        rideDist += distance.as(LengthUnit.Meter, coords[k], coords[k + 1]);
      }

      // Total trip cost (you can weight walk more if you want)
      double totalCost = dStart + rideDist + bestEndDist;

      candidates.add(
        RouteSegment(
          startIndex: i,
          endIndex: bestEnd,
          startWalkDistance: dStart,
          endWalkDistance: bestEndDist,
          rideDistance: rideDist,
          totalCost: totalCost,
        ),
      );
    }
  }

  if (candidates.isEmpty) return null;

  // Pick best candidate by total cost
  candidates.sort((a, b) => a.totalCost.compareTo(b.totalCost));
  return candidates.first;
}

// Helper class to store route segment information
class RouteSegment {
  final int startIndex;
  final int endIndex;
  final double startWalkDistance;
  final double endWalkDistance;
  final double rideDistance;
  final double totalCost;

  RouteSegment({
    required this.startIndex,
    required this.endIndex,
    required this.startWalkDistance,
    required this.endWalkDistance,
    required this.rideDistance,
    required this.totalCost,
  });
}
