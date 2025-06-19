import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:map_try/model/route_loader.dart';

final Distance _distance = Distance();
double walkingDistance = 0.0;
List<Polyline> walkingPolylines = [];
double segmentDistance = 0.0;

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

List<Polyline> createDottedLine(LatLng start, LatLng end) {
  final List<Polyline> dotted = [];
  const double segmentLength = 3.0;
  final double totalDistance = _distance(start, end);
  final int segments = (totalDistance / segmentLength).floor();

  for (int i = 0; i < segments; i += 2) {
    final double f1 = i / segments;
    final double f2 = (i + 1) / segments;

    final LatLng segStart = LatLng(
      start.latitude + (end.latitude - start.latitude) * f1,
      start.longitude + (end.longitude - start.longitude) * f1,
    );

    final LatLng segEnd = LatLng(
      start.latitude + (end.latitude - start.latitude) * f2,
      start.longitude + (end.longitude - start.longitude) * f2,
    );

    dotted.add(
      Polyline(points: [segStart, segEnd], color: Colors.black, strokeWidth: 3),
    );
  }

  return dotted;
}

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

  @override
  void initState() {
    super.initState();
    _destinationNotifier = widget.destinationNotifier;

    _initializeLocation().then((_) {
      _destinationNotifier.addListener(() {
        final newDestination = _destinationNotifier.value;
        if (newDestination != null && _currentLocation != null) {
          _destination = newDestination;
          loadRouteData();
          // print("Current Location: $_currentLocation");
          // print(
          //   "New Destination: $newDestination",
          // ); // uses jeepney route, not OSRM anymore
        }
      });
    });
  }

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

    // // For debugging: Use a fixed location in Iloilo City
    // const LatLng debuggingLocation = LatLng(
    //   // 10.732143,
    //   // 122.559791, //tabuc suba jollibe
    //   // 10.731958,
    //   // 122.560223, //sulodlon debug
    //   // 10.732178,
    //   // 122.559673, //tabuc suba sa piyak
    //   // 10.733472,
    //   // 122.548947, //tubang CPU
    //   10.732610,
    //   122.548220, // mt building
    //   // 10.715609,
    //   // 122.562715, // ColdZone West
    //   // 10.725203,
    //   // 122.556715, //Jaro plaza
    //   // 10.696694,
    //   // 122.545582, //Molo Plazas
    //   // 10.694928, 122.564686, //Rob Main
    //   // 10.753623,
    //   // 122.538430, //Gt mall
    //   // 10.714335,
    //   // 122.551852, // Sm City
    //   // 10.731993,
    //   // 122.549291, //promenade cpu
    // );

    // setState(() {
    //   _currentLocation = debuggingLocation;
    //   isLoading = false;
    // });
    // _destinationNotifier.value = const LatLng(
    //   // 10.731068,
    //   // 122.551723, //sarap station
    //   // 10.732143, 122.559791, //tabuc suba jollibe
    //   10.715609,
    //   122.562715, // ColdZone West
    //   // 10.733472, 122.548947, //tubang CPU
    //   // 10.696694, 122.545582, //Molo Plazas
    //   // 10.694928,
    //   // 122.564686, //Rob Main
    //   // 10.753623,
    //   // 122.538430, //Gt mall
    //   // 10.727482,
    //   // 122.558188, // alicias
    //   // 10.714335,
    //   // 122.551852, // Sm City
    // ); // your test destination
    // _destination = _destinationNotifier.value;

    // loadRouteData(); // Load jeepney routes based on this location
  }

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

  void _decodePolyline(String encodedPolyline) {
    final polylinePoints = PolylinePoints();
    final decodePoints = polylinePoints.decodePolyline(encodedPolyline);

    setState(() {
      _route =
          decodePoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
    });
  }

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
      final segment = extractSegment(
        _currentLocation!,
        _destination!,
        matchingRoute.coordinates,
      );

      segmentDistance = calculateSegmentDistance(segment);

      setState(() {
        _route = segment;
        _matchedRoute = matchingRoute;
      });
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                "No matching jeepney route found from your location to destination.",
              ),
              duration: Duration(seconds: 5),
            ),
          );
      }
    }
  }

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
                    // Close modal if dragged to min size
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

                        // unod sang route modal
                        ListTile(
                          leading: const Icon(Icons.directions_walk),
                          title: const Text(
                            "Walk to the nearest jeep route",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            walkingDistance > 0
                                ? "Estimated walking distance: ${walkingDistance.toStringAsFixed(0)} meters (${getWalkingTimeEstimate(walkingDistance)})"
                                : "You are already near a jeepney route yey!.",
                          ), // optional
                        ),
                        ListTile(
                          leading: const Icon(Icons.directions_bus),
                          title: Text(
                            "Sakay ka Jeepney Route: \n #${_matchedRoute?.routeNumber ?? ''}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrangeAccent,
                            ),
                          ),
                          subtitle: Text(
                            "Route Direction: ${_matchedRoute?.direction ?? ''}",
                          ),
                        ),

                        ListTile(
                          leading: const Icon(Icons.timelapse),
                          title: Text(
                            "From current to Destination resto: ",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "Estimated Disttance: ${(segmentDistance / 1000).toStringAsFixed(2)} Km \nEstimated Travel Time: ${estimateJeepneyTime(segmentDistance)} \nDirection: CurrentLocation to Resto Name", //logic here for fetching data from firestore
                          ),
                        ),
                        // if (userWalk) ...[
                        //   ListTile(
                        //     leading: const Icon(Icons.directions_walk),
                        //     title: const Text(
                        //       "Cross the road to catch the jeep",
                        //     ),
                        //     subtitle: const Text(
                        //       "The jeepney on your side goes away from your destination.\nCross the road to ride the correct one going your way.",
                        //     ),
                        //   ),
                        // ],
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

  JeepneyRoute? getMatchingRoute(
    LatLng current,
    LatLng destination,
    List<JeepneyRoute> routes,
  ) {
    for (final route in allRoutes) {
      bool nearCurrent = route.isPointNearRoute(
        current,
        1000,
      ); // 500, 1000 edit later after debugging
      bool nearDestination = route.isPointNearRoute(destination, 1000);

      // DEBUG: print distances to destination for this route
      double minDistToDest = double.infinity;
      for (var point in route.coordinates) {
        double dist = Distance().as(LengthUnit.Meter, destination, point);
        if (dist < minDistToDest) minDistToDest = dist;
      }
      // print(
      //   "Route ${route.routeNumber} minimum distance to destination: $minDistToDest meters",
      // );

      // print(
      //   "Checking route ${route.routeNumber}: "
      //   "near current? $nearCurrent | "
      //   "near destination? $nearDestination",
      // );

      if (nearCurrent && nearDestination) {
        return route;
      }
    }
    return null;
  }

  List<JeepneyRoute> getTopNearbyRoutes(
    LatLng current,
    LatLng destination,
    List<JeepneyRoute> routes, {
    int limit = 1,
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

  //trying matvhing locgic

  List<LatLng> extractSegment(
    LatLng current,
    LatLng destination,
    List<LatLng> routeCoords,
  ) {
    final Distance distance = Distance();

    int startIndex = 0;
    int endIndex = routeCoords.length - 1;

    double minStartDistance = double.infinity;
    double minEndDistance = double.infinity;

    for (int i = 0; i < routeCoords.length; i++) {
      double dStart = distance.as(LengthUnit.Meter, current, routeCoords[i]);
      double dEnd = distance.as(LengthUnit.Meter, destination, routeCoords[i]);

      if (dStart < minStartDistance) {
        minStartDistance = dStart;
        startIndex = i;
      }
      if (dEnd < minEndDistance) {
        minEndDistance = dEnd;
        endIndex = i;
      }
    }

    if (startIndex < endIndex) {
      return routeCoords.sublist(startIndex, endIndex + 1);
    } else {
      return routeCoords.sublist(endIndex, startIndex + 1).reversed.toList();
    }

    // // Ensure segment follows route direction (no reversing)
    // if (startIndex > endIndex) {
    //   // If destination is behind, return an empty list or just end early
    //   return [];
    // }
    // return routeCoords.sublist(startIndex, endIndex + 1);
  }

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

    return total; //convert to kilometers
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
    if (_currentLocation != null && allRoutes.isNotEmpty) {
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
        walkingPolylines = createDottedLine(_currentLocation!, nearestPoint);
      } else {
        walkingDistance = 0;
      }
    }

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
              backgroundColor: const Color.fromRGBO(
                255,
                255,
                255,
                0.01,
              ), // semi-transparent
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.login, color: Colors.deepOrangeAccent),
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
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
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          // CurrentLocationLayer(
          //   style: LocationMarkerStyle(
          //     marker: DefaultLocationMarker(
          //       child: Icon(Icons.location_pin, color: Colors.blue),
          //     ),
          //     markerSize: const Size(35, 35),

          //     markerDirection: MarkerDirection.heading,
          //   ),
          // ),

          // //currentlocation debugger
          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          //delete the above for debuf only
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
          if (allRoutes.isNotEmpty)
            PolylineLayer(
              polylines:
                  allRoutes.map((route) {
                    return Polyline(
                      points: route.coordinates,
                      color: _getColorForRoute(
                        route.routeNumber,
                      ).withAlpha((0.5 * 255).toInt()), //7 opacity
                      strokeWidth: 6,
                    );
                  }).toList(),
            ),
          if (_matchedRoute != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _matchedRoute!.coordinates,
                  color: _getColorForRoute(
                    _matchedRoute!.routeNumber,
                  ).withAlpha((0.1 * 255).toInt()), // 20% opacity
                  strokeWidth: 10,
                ),
              ],
            ),
          // Walking dotted line
          if (walkingPolylines.isNotEmpty)
            PolylineLayer(polylines: walkingPolylines),
          if (_route.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _route,
                  color: Colors.blue, // cropped segment (may bug)
                  strokeWidth: 4,
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
              backgroundColor: Colors.deepOrangeAccent,
              child: const Icon(
                Icons.my_location,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
          if (_matchedRoute != null)
            Positioned(
              bottom: 80, // space above the other FAB
              right: 16,
              child: FloatingActionButton.extended(
                label: const Text('Route'),
                icon: const Icon(Icons.route),
                backgroundColor: Colors.lightGreenAccent,
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

Color _getColorForRoute(String routeNumber) {
  switch (routeNumber) {
    case '3':
      return const Color.fromARGB(255, 241, 41, 41);
    case '10':
      return const Color.fromARGB(255, 31, 118, 34);
    case '11':
      return Colors.purple;
    case '2':
      return const Color.fromARGB(255, 116, 73, 8);
    case '4':
      return const Color.fromARGB(255, 72, 233, 77);
    case '25':
      return Colors.black;
    case '1A':
      return const Color.fromARGB(255, 210, 92, 131);
    case '1B':
      return const Color.fromARGB(255, 11, 50, 243);
    default:
      return Colors.black;
  }
}
