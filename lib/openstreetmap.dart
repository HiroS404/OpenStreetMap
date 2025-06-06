import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:map_try/route_loader.dart';

class OpenstreetmapScreen extends StatefulWidget {
  final ValueNotifier<LatLng?> destinationNotifier;
  const OpenstreetmapScreen({super.key, required this.destinationNotifier});

  @override
  State<OpenstreetmapScreen> createState() => _OpenstreetmapScreenState();
}

class _OpenstreetmapScreenState extends State<OpenstreetmapScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  late final ValueNotifier<LatLng?> _destinationNotifier;
  LatLng? _destination;
  List<LatLng> _route = [];
  List<JeepneyRoute> allRoutes = [];
  JeepneyRoute? _matchedRoute;

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
          print("Current Location: $_currentLocation");
          print(
            "New Destination: $newDestination",
          ); // uses jeepney route, not OSRM anymore
        }
      });
    });
  }

  Future<void> _initializeLocation() async {
    // bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    // if (!serviceEnabled) {
    //   _showError("Location services are disabled.");
    //   return;
    // }

    // LocationPermission permission = await Geolocator.checkPermission();
    // if (permission == LocationPermission.denied) {
    //   permission = await Geolocator.requestPermission();
    //   if (permission == LocationPermission.denied) {
    //     _showError("Location permissions are denied.");
    //     return;
    //   }
    // }

    // if (permission == LocationPermission.deniedForever) {
    //   _showError("Location permissions are permanently denied.");
    //   return;
    // }

    // Position position = await Geolocator.getCurrentPosition();
    // setState(() {
    //   _currentLocation = LatLng(position.latitude, position.longitude);
    //   isLoading = false;
    // });
    // loadRouteData();

    // For debugging: Use a fixed location in Iloilo City
    const LatLng debuggingLocation = LatLng(
      // 10.732143,
      // 122.559791,
      10.733472,
      122.548947,
      // 10.715609,
      // 122.562715,
    ); // SM City Iloilo

    setState(() {
      _currentLocation = debuggingLocation;
      isLoading = false;
    });
    _destinationNotifier.value = const LatLng(
      10.731068,
      122.551723,
      // 10.732143,
      // 122.559791,
      // 10.715609,
      // 122.562715,
      // 10.733472,
      // 122.548947,
    ); // your test destination
    _destination = _destinationNotifier.value;

    loadRouteData(); // Load jeepney routes based on this location
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
      setState(() {
        _route = segment;
        _matchedRoute = matchingRoute;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Using Jeepney Route: ${matchingRoute.routeNumber} (${matchingRoute.direction})",
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No matching jeepney route found from your location to destination.",
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
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
        500,
      ); // increased threshold
      bool nearDestination = route.isPointNearRoute(destination, 1000);

      // DEBUG: print distances to destination for this route
      double minDistToDest = double.infinity;
      for (var point in route.coordinates) {
        double dist = Distance().as(LengthUnit.Meter, destination, point);
        if (dist < minDistToDest) minDistToDest = dist;
      }
      print(
        "Route ${route.routeNumber} minimum distance to destination: $minDistToDest meters",
      );

      print(
        "Checking route ${route.routeNumber}: "
        "near current? $nearCurrent | "
        "near destination? $nearDestination",
      );

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
    int limit = 2,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MAPAkaon',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
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
          //       child: Icon(Icons.location_pin, color: Colors.white),
          //     ),
          //     markerSize: const Size(35, 35),
          //     markerDirection: MarkerDirection.heading,
          //   ),
          // ),
          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    size: 50,
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
                      ).withAlpha((0.3 * 255).toInt()), // 30% opacity
                      strokeWidth: 10,
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
                  ).withAlpha((0.4 * 255).toInt()), // 70% opacity
                  strokeWidth: 10,
                ),
              ],
            ),
          if (_route.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _route,
                  color:
                      Colors
                          .blue, // full opacity, distinct color for cropped segment
                  strokeWidth: 10,
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _userCurrentLocation,
        backgroundColor: Colors.deepOrangeAccent,
        child: const Icon(Icons.my_location, size: 30, color: Colors.white),
      ),
    );
  }
}

Color _getColorForRoute(int routeNumber) {
  switch (routeNumber) {
    case 3:
      return Colors.red;
    case 10:
      return Colors.black;
    case 11:
      return Colors.purple;
    default:
      return Colors.green;
  }
}
