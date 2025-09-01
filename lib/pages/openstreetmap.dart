import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
// import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:map_try/model/route_loader.dart';
import 'package:map_try/services/mapbox_service.dart';
import 'package:map_try/services/ors_service.dart';
import 'package:flutter/services.dart' show rootBundle;

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

  late OrsService _orsService;

  List<Polyline> _startWalkingPolylines = []; // walk from user to jeepney start
  List<Polyline> _endWalkingPolylines =
      []; // walk from jeepney end to destination
  bool _walkingPolylinesCalculated = false;

  MultiRouteResult? _bestRoute;
  List<JeepneyRoute> _selectedRoutes =
      []; // Only the routes in the best solution

  @override
  void initState() {
    super.initState();
    _destinationNotifier = widget.destinationNotifier;
    _orsService = OrsService(ORSApiKey);

    _initializeLocation().then((_) {
      _destinationNotifier.addListener(() {
        final newDestination = _destinationNotifier.value;
        if (newDestination != null && _currentLocation != null) {
          // Close any open modals first
          if (_isModalOpen) {
            Navigator.of(context, rootNavigator: true).pop();
            _isModalOpen = false;
          }

          _destination = newDestination;
          loadRouteData();
          print("Current Location: $_currentLocation");
          print("New Destination: $newDestination");
        }
      });
    });
  }

  void _clearRouteData() {
    setState(() {
      _route = [];
      _matchedRoute = null;
      _selectedRoutes = [];
      _bestRoute = null;
      _startWalkingPolylines = [];
      _endWalkingPolylines = [];
      _walkingPolylinesCalculated = false;
      walkingDistance = 0.0;
      endWalkingDistance = 0.0;
      segmentDistance = 0.0;
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
    // Removed the > 10m threshold to show all walking routes
    if (segment.startWalkDistance > 5) {
      // Lowered from 10m to 5m
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
    if (segment.endWalkDistance > 5) {
      // Lowered from 10m to 5m
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
    //   // 10.692037,
    //   // 122.583255, // CT Parola
    //   // 10.726009,
    //   // 122.557774, // lapit alicias ah
    //   // 10.726947,
    //   // 122.558021, // lapit pgd
    //   // 10.695724,
    //   // 122.566170
    //   // Center city proper
    //   // 10.695522,
    //   // 122.566212
    //   // Center City proper across
    //   // 10.69321774107972,
    //   // 122.49947369098665, // mohon term
    //   // 10.74472415057673,
    //   // 122.56394863128664 // hause ni mhar
    // );

    // setState(() {
    //   _currentLocation = debuggingLocation;
    //   isLoading = false;
    // });
    // _destinationNotifier.value = const LatLng(
    //   // 10.731068,
    //   // 122.551723, //sarap station
    //   // 10.732143, 122.559791, //tabuc suba jollibe
    //   // 10.715609,
    //   // 122.562715, // ColdZone West
    //   // 10.716225933976629,
    //   // 122.56377696990968, // somewhere further coldzone west
    //   // 10.733472,
    //   // 122.548947, //tubang CPU
    //   // 10.696694, 122.545582, //Molo Plazas
    //   // 10.694928,
    //   // 122.564686, //Rob Main
    //   // 10.753623,
    //   // 122.538430, //Gt mall
    //   // 10.727482,
    //   // 122.558188, // alicias
    //   // 10.714335,
    //   // 122.551852, // Sm City
    //   // 10.697643,
    //   // 122.543888 // Molo
    //   // 10.693202,
    //   // 122.500595, // mohon term
    //   // 10.725203,
    //   // 122.556715, //Jaro plaza
    // ); // your test destination
    // _destination = _destinationNotifier.value;

    // loadRouteData(); // Load jeepney routes based on this location
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
  void loadRouteData() async {
    // Clear previous route data before loading new data
    _clearRouteData();

    print("🚀 Starting loadRouteData");

    List<JeepneyRoute> jeepneyRoutes = await loadRoutesFromJson();
    print("📊 Loaded ${jeepneyRoutes.length} jeepney routes");

    List<TransferSpot> transferSpots = [];

    try {
      transferSpots = await loadTransferSpotsFromJson();
      print("🔄 Loaded ${transferSpots.length} transfer spots");
    } catch (e) {
      print("⚠️ Transfer spots not found, using single routes only: $e");
      transferSpots = [];
    }

    if (!mounted || _currentLocation == null || _destination == null) {
      print("⚠️ Not mounted or missing location data");
      return;
    }

    print("📍 Current: $_currentLocation");
    print("🎯 Destination: $_destination");

    allRoutes = getTopNearbyRoutes(
      _currentLocation!,
      _destination!,
      jeepneyRoutes,
    );
    print("🛣️ Found ${allRoutes.length} nearby routes");

    // Use the new multi-route system
    final bestRoute = findBestRoute(
      _currentLocation!,
      _destination!,
      jeepneyRoutes,
      transferSpots,
    );

    if (bestRoute != null) {
      print("✅ Found best route with ${bestRoute.tripCount} trip(s)");
      print("   Routes: ${bestRoute.routeNumbers}");
      print(
        "   Total walk: ${bestRoute.totalWalkDistance.toStringAsFixed(0)}m",
      );
      print(
        "   Total ride: ${bestRoute.totalRideDistance.toStringAsFixed(0)}m",
      );

      // Store the best route solution and get the actual route objects
      _bestRoute = bestRoute;
      _selectedRoutes = [];

      for (final routeNumber in bestRoute.routeNumbers) {
        final route = jeepneyRoutes.firstWhere(
          (r) => r.routeNumber == routeNumber,
          orElse: () => jeepneyRoutes.first, // fallback
        );
        _selectedRoutes.add(route);
      }

      setState(() {
        if (bestRoute.tripCount == 1) {
          print("🚌 Handling single route");
          _handleSingleRoute(bestRoute, jeepneyRoutes);
        } else {
          print("🔄 Handling multi-route");
          _handleMultiRoute(bestRoute, jeepneyRoutes);
        }
      });
    } else {
      print("⚠️ No best route found, using fallback");
      _handleFallbackSingleRoute(jeepneyRoutes);
    }
  }

  void _handleSingleRoute(
    MultiRouteResult singleRoute,
    List<JeepneyRoute> allRoutes,
  ) {
    final segment = singleRoute.segments.first;
    final routeNumber = singleRoute.routeNumbers.first;

    // Find the route by route number instead of trying to match segments
    final matchingRoute = allRoutes.firstWhere(
      (route) => route.routeNumber == routeNumber,
      orElse: () => throw Exception('Route $routeNumber not found'),
    );

    // Extract the route segment using the indices from the best route result
    final routeSegment = matchingRoute.coordinates.sublist(
      segment.startIndex,
      segment.endIndex + 1,
    );

    setState(() {
      _route = routeSegment;
      _matchedRoute = matchingRoute;
      segmentDistance = calculateSegmentDistance(routeSegment);

      // Update the global walking distance variables for the modal
      walkingDistance = segment.startWalkDistance;
      endWalkingDistance = segment.endWalkDistance;

      _walkingPolylinesCalculated = false;
    });

    // Update walking polylines after setting the state
    _updateAllWalkingPolylines();
  }

  // Add this helper function for transfer spots loading
  Future<List<TransferSpot>> loadTransferSpotsFromJson() async {
    final String jsonString = await rootBundle.loadString(
      'assets/transfer_spots.json',
    );
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => TransferSpot.fromJson(json)).toList();
  }

  // Enhanced multi-route handling
  void _handleMultiRoute(
    MultiRouteResult multiRoute,
    List<JeepneyRoute> allRoutes,
  ) {
    // For now, combine all route segments into one polyline
    List<LatLng> combinedRoute = [];
    JeepneyRoute? firstRoute;

    for (int i = 0; i < multiRoute.segments.length; i++) {
      final segment = multiRoute.segments[i];

      // Find matching route for this segment
      JeepneyRoute? segmentRoute;
      LatLng segmentStart, segmentEnd;

      if (i == 0) {
        // First segment: start -> first transfer point
        segmentStart = _currentLocation!;
        segmentEnd = multiRoute.transferPoints.first;
      } else if (i == multiRoute.segments.length - 1) {
        // Last segment: last transfer point -> destination
        segmentStart = multiRoute.transferPoints[i - 1];
        segmentEnd = _destination!;
      } else {
        // Middle segment: transfer point -> transfer point
        segmentStart = multiRoute.transferPoints[i - 1];
        segmentEnd = multiRoute.transferPoints[i];
      }

      // Find the route that best matches this segment
      for (final route in allRoutes) {
        final testSegment = findBestRouteSegment(
          segmentStart,
          segmentEnd,
          route.coordinates,
        );

        if (testSegment != null) {
          segmentRoute = route;
          firstRoute ??= route;

          // Add this segment's coordinates to combined route
          final segmentCoords = route.coordinates.sublist(
            testSegment.startIndex,
            testSegment.endIndex + 1,
          );

          if (combinedRoute.isEmpty) {
            combinedRoute.addAll(segmentCoords);
          } else {
            // Add without duplicating the connection point
            combinedRoute.addAll(segmentCoords.skip(1));
          }
          break;
        }
      }
    }

    if (combinedRoute.isNotEmpty && firstRoute != null) {
      _route = combinedRoute;
      _matchedRoute = firstRoute; // Use first route for reference
      segmentDistance = calculateSegmentDistance(combinedRoute);
      _walkingPolylinesCalculated = false;

      // Update walking polylines for multi-route
      _updateMultiRouteWalkingPolylines(multiRoute);
    }
  }

  Future<void> _updateMultiRouteWalkingPolylines(
    MultiRouteResult multiRoute,
  ) async {
    setState(() {
      _startWalkingPolylines = [];
      _endWalkingPolylines = [];
    });

    final futures = <Future<void>>[];

    // Start walking (user -> first route start)
    final firstSegment = multiRoute.segments.first;
    if (firstSegment.startWalkDistance > 5) {
      walkingDistance = firstSegment.startWalkDistance;

      futures.add(
        _orsService
            .getRoute(
              _currentLocation!,
              _route.first, // Start of combined route
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

    // End walking (last route end -> destination)
    final lastSegment = multiRoute.segments.last;
    if (lastSegment.endWalkDistance > 5) {
      endWalkingDistance = lastSegment.endWalkDistance;

      futures.add(
        _orsService
            .getRoute(
              _route.last, // End of combined route
              _destination!,
              profile: "foot-walking",
            )
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

    await Future.wait(futures);

    setState(() {
      _walkingPolylinesCalculated = true;
    });
  }

  void _handleFallbackSingleRoute(List<JeepneyRoute> jeepneyRoutes) {
    final matchedRoute = getMatchingRoute(
      _currentLocation!,
      _destination!,
      jeepneyRoutes,
    );

    if (matchedRoute != null) {
      final segment = findBestRouteSegment(
        _currentLocation!,
        _destination!,
        matchedRoute.coordinates,
      );

      if (segment != null) {
        final routeSegment = matchedRoute.coordinates.sublist(
          segment.startIndex,
          segment.endIndex + 1,
        );

        _route = routeSegment;
        _matchedRoute = matchedRoute;
        segmentDistance = calculateSegmentDistance(routeSegment);
        _walkingPolylinesCalculated = false;

        _updateAllWalkingPolylines();
      }
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

  void showRouteModal(BuildContext context) {
    if (_isModalOpen) return; // Prevent multiple modals

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
                    }
                    return true;
                  }, //here ang container nga ga cause ui problem
                  child: ListView(
                    scrollDirection: Axis.vertical,

                    // controller: scrollController,
                    children: [
                      // Drag handle
                      // Center(
                      //   child: Container(
                      //     width: 40,
                      //     height: 4,
                      //     margin: const EdgeInsets.only(bottom: 12),
                      //     decoration: BoxDecoration(
                      //       color: Colors.grey[300],
                      //       borderRadius: BorderRadius.circular(4),
                      //     ),
                      //   ),
                      // ),

                      // Step 1: Walk to first jeepney
                      ListTile(
                        leading: const Icon(
                          Icons.directions_walk,
                          color: Colors.blue,
                        ),
                        title: const Text(
                          "Step 1: Walk to the nearest jeepney route",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          walkingDistance > 10
                              ? "Walk ${walkingDistance.toStringAsFixed(0)} meters (${getWalkingTimeEstimate(walkingDistance)})"
                              : "You are already at the jeepney route!",
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Display ONLY the selected routes from the best solution
                      if (_route.isNotEmpty && _selectedRoutes.isNotEmpty) ...[
                        // Use _selectedRoutes instead of allRoutes!
                        for (int i = 0; i < _selectedRoutes.length; i++) ...[
                          ListTile(
                            leading: const Icon(
                              Icons.directions_bus,
                              color: Colors.orange,
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Step ${i + 2}: Ride Jeepney Route ${_selectedRoutes[i].routeNumber}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrangeAccent,
                                  ),
                                ),
                                Image.asset(
                                  "Assets/route_pics/${_selectedRoutes[i].routeNumber}.png",
                                  height: 200,
                                  fit: BoxFit.contain,
                                  errorBuilder:
                                      (context, error, stackTrace) => Container(
                                        height: 100,
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
                              "Direction: ${_selectedRoutes[i].direction}\n"
                              "Estimated Distance: ${(calculateSegmentDistance(_selectedRoutes[i].coordinates) / 1000).toStringAsFixed(2)} km",
                            ),
                          ),

                          // Add transfer step between routes (but not after the last route)
                          if (i < _selectedRoutes.length - 1)
                            ListTile(
                              leading: const Icon(
                                Icons.transfer_within_a_station,
                                color: Colors.purple,
                              ),
                              title: Text(
                                "Step ${i + 3}: Transfer to Route ${_selectedRoutes[i + 1].routeNumber}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: const Text(
                                "Get off and transfer to the next route",
                              ),
                            ),
                        ],
                      ] else if (_route.isNotEmpty &&
                          _matchedRoute != null) ...[
                        // Single route fallback (when _selectedRoutes is empty)
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
                                height: 200,
                                fit: BoxFit.contain,
                                errorBuilder:
                                    (context, error, stackTrace) => Container(
                                      height: 100,
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
                            "Direction: ${_matchedRoute?.direction ?? ''}\n"
                            "Ride Distance: ${(segmentDistance / 1000).toStringAsFixed(2)} km\n"
                            "Estimated Time: ${estimateJeepneyTime(segmentDistance)}",
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      // Final step: Walk to destination
                      ListTile(
                        leading: const Icon(
                          Icons.directions_walk,
                          color: Colors.green,
                        ),
                        title: const Text(
                          "Final Step: Walk to your destination",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          endWalkingDistance > 10
                              ? "Walk ${endWalkingDistance.toStringAsFixed(0)} meters (${getWalkingTimeEstimate(endWalkingDistance)})"
                              : "You'll arrive directly at your destination!",
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Trip Summary
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
                                  "Jeepney trips: ${_selectedRoutes.isNotEmpty ? _selectedRoutes.length : 1}",
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text("Total Time: ${_getTotalEstimatedTime()}"),
                            if (_bestRoute != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Routes: ${_bestRoute!.routeNumbers.join(' → ')}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    ).then((_) {
      // This executes when the modal is closed
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

  // Remove the ENTIRE polyline logic from your build() method
  // Replace the build method section starting from "//dotted line" comment with this:

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // REMOVED ALL THE OLD POLYLINE LOGIC FROM HERE
    // The new multi-route system handles polylines in the functions above

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

          // CurrentLocationLayer(
          //   style: LocationMarkerStyle(
          //     marker: DefaultLocationMarker(
          //       child: Icon(Icons.location_pin, color: Colors.blue),
          //     ),
          //     markerSize: const Size(35, 35),
          //     markerDirection: MarkerDirection.heading,
          //   ),
          // ),

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

          // Current location GPS
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
          if (_matchedRoute != null ||
              (_selectedRoutes.isNotEmpty && _route.isNotEmpty))
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
}

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

// Function to find the best segment considering route direction
RouteSegment? findBestRouteSegment(
  LatLng current,
  LatLng destination,
  List<LatLng> coords, {
  double maxWalkDistance = 800, // Increased from 200m to 800m
  double preferredWalkDistance = 300, // Preferred distance for scoring
  double snapThreshold = 25,
  double maxTotalWalk = 1200, // Maximum combined walking distance
}) {
  final distance = Distance();
  final targetBearing = bearing(current, destination);

  List<RouteSegment> candidates = [];

  for (int i = 0; i < coords.length - 1; i++) {
    final segBearing = bearing(coords[i], coords[i + 1]);
    final dStart = distance.as(LengthUnit.Meter, current, coords[i]);

    // More lenient filtering - allow longer walks but penalize them in scoring
    if (dStart > maxWalkDistance && dStart > snapThreshold) continue;

    // Snap-to-route override OR forward check
    if (dStart <= snapThreshold ||
        isForward(segBearing, targetBearing, tolerance: 60)) {
      // Find best endIndex AFTER i
      int? bestEnd;
      double bestEndDist = double.infinity;

      for (int j = i + 1; j < coords.length; j++) {
        final dEnd = distance.as(LengthUnit.Meter, destination, coords[j]);

        // Allow longer end walking distances, but check total walking
        if (dEnd <= maxWalkDistance && (dStart + dEnd) <= maxTotalWalk) {
          if (dEnd < bestEndDist) {
            bestEnd = j;
            bestEndDist = dEnd;
          }
        }
      }

      if (bestEnd == null) continue;

      // Compute ride distance
      double rideDist = 0.0;
      for (int k = i; k < bestEnd; k++) {
        rideDist += distance.as(LengthUnit.Meter, coords[k], coords[k + 1]);
      }

      // Enhanced scoring that penalizes long walks but doesn't eliminate them
      double walkPenalty = 0.0;

      // Penalize walks longer than preferred distance
      if (dStart > preferredWalkDistance) {
        walkPenalty +=
            (dStart - preferredWalkDistance) *
            2; // 2x penalty for excess walking
      }
      if (bestEndDist > preferredWalkDistance) {
        walkPenalty += (bestEndDist - preferredWalkDistance) * 2;
      }

      // Total trip cost with walking penalty
      double totalCost = dStart + rideDist + bestEndDist + walkPenalty;

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

  // Pick best candidate by total cost (now includes walking penalties)
  candidates.sort((a, b) => a.totalCost.compareTo(b.totalCost));
  return candidates.first;
}

RouteSegment? findTransferRouteSegment(
  LatLng current,
  LatLng destination,
  List<LatLng> coords, {
  double maxWalkDistance = 1500, // More lenient for transfers
  double preferredWalkDistance = 500,
  double snapThreshold = 50, // Increased snap threshold
  double maxTotalWalk = 2000,
}) {
  final distance = Distance();

  List<RouteSegment> candidates = [];

  for (int i = 0; i < coords.length - 1; i++) {
    final dStart = distance.as(LengthUnit.Meter, current, coords[i]);

    // More lenient filtering for transfers
    if (dStart > maxWalkDistance) continue;

    // Find best endIndex AFTER i
    int? bestEnd;
    double bestEndDist = double.infinity;

    for (int j = i + 1; j < coords.length; j++) {
      final dEnd = distance.as(LengthUnit.Meter, destination, coords[j]);

      if (dEnd <= maxWalkDistance && (dStart + dEnd) <= maxTotalWalk) {
        if (dEnd < bestEndDist) {
          bestEnd = j;
          bestEndDist = dEnd;
        }
      }
    }

    if (bestEnd == null) continue;

    // Compute ride distance
    double rideDist = 0.0;
    for (int k = i; k < bestEnd; k++) {
      rideDist += distance.as(LengthUnit.Meter, coords[k], coords[k + 1]);
    }

    // Simpler scoring for transfers - less strict on direction
    double walkPenalty = 0.0;
    if (dStart > preferredWalkDistance) {
      walkPenalty += (dStart - preferredWalkDistance);
    }
    if (bestEndDist > preferredWalkDistance) {
      walkPenalty += (bestEndDist - preferredWalkDistance);
    }

    double totalCost = dStart + rideDist + bestEndDist + walkPenalty;

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

  if (candidates.isEmpty) return null;

  // Pick best candidate by total cost
  candidates.sort((a, b) => a.totalCost.compareTo(b.totalCost));
  return candidates.first;
}

// Update your RouteSegment class to include trip count
class RouteSegment {
  final int startIndex;
  final int endIndex;
  final double startWalkDistance;
  final double endWalkDistance;
  final double rideDistance;
  final double totalCost;
  final int tripCount; // Add this

  RouteSegment({
    required this.startIndex,
    required this.endIndex,
    required this.startWalkDistance,
    required this.endWalkDistance,
    required this.rideDistance,
    required this.totalCost,
    this.tripCount = 1, // Default for single route
  });
}

// Multi-route result class
class MultiRouteResult {
  final List<RouteSegment> segments;
  final List<LatLng> transferPoints;
  final double totalWalkDistance;
  final double totalRideDistance;
  final double totalCost;
  final int tripCount;

  final List<int> routeNumbers;

  MultiRouteResult({
    required this.segments,
    required this.transferPoints,
    required this.totalWalkDistance,
    required this.totalRideDistance,
    required this.totalCost,
    required this.tripCount,

    required this.routeNumbers,
  });
}

// Updated comparison logic
MultiRouteResult? findBestRoute(
  LatLng start,
  LatLng destination,
  List<JeepneyRoute> allRoutes,
  List<TransferSpot> transferSpots,
) {
  // print("🎯 Finding best route...");
  List<MultiRouteResult> allOptions = [];

  // ALWAYS try single route options first with more lenient parameters
  final singleOptions = findSingleRouteOptions(start, destination, allRoutes);
  // print("Found ${singleOptions.length} single route options");

  if (singleOptions.isNotEmpty) {
    // Check if any single route has reasonable walking distance
    final reasonableSingleRoutes =
        singleOptions.where((option) {
          return option.totalWalkDistance <=
              1500; // Allow up to 1.5km walking for single route
        }).toList();

    if (reasonableSingleRoutes.isNotEmpty) {
      // print("✅ Found reasonable single routes, strongly preferring these");

      // Add single routes with small bonus
      final bonusedSingleRoutes =
          reasonableSingleRoutes.map((option) {
            return MultiRouteResult(
              segments: option.segments,
              transferPoints: option.transferPoints,
              totalWalkDistance: option.totalWalkDistance,
              totalRideDistance: option.totalRideDistance,
              totalCost: option.totalCost - 500, // Bonus for single route
              tripCount: option.tripCount,
              routeNumbers: option.routeNumbers,
            );
          }).toList();

      allOptions.addAll(bonusedSingleRoutes);

      // Only consider 2-route transfers if single route requires excessive walking
      final excessiveWalkingSingle =
          reasonableSingleRoutes.where((option) {
            return option.totalWalkDistance > 1000; // More than 1km walking
          }).toList();

      if (excessiveWalkingSingle.isNotEmpty) {
        // print(
        //   "⚠️ Single routes require significant walking, checking 2-route options",
        // );
        final multiOptions = findMultiRouteOptions(
          start,
          destination,
          allRoutes,
          transferSpots,
        );
        allOptions.addAll(multiOptions);
      }
    } else {
      // No reasonable single routes, try multi-route
      // print(
      //   "❌ Single routes require excessive walking, checking multi-route options",
      // );
      allOptions.addAll(singleOptions); // Keep as backup
      final multiOptions = findMultiRouteOptions(
        start,
        destination,
        allRoutes,
        transferSpots,
      );
      allOptions.addAll(multiOptions);
    }
  } else {
    // No single routes found at all
    // print("❌ No single routes found, checking multi-route options");
    final multiOptions = findMultiRouteOptions(
      start,
      destination,
      allRoutes,
      transferSpots,
    );
    allOptions.addAll(multiOptions);
  }

  if (allOptions.isEmpty) {
    // print("❌ No route options found at all");
    return null;
  }

  // Sort with strong preference for fewer trips
  allOptions.sort((a, b) {
    // Heavily prioritize trip count
    if (a.tripCount != b.tripCount) {
      return a.tripCount.compareTo(b.tripCount);
    }

    // Then by total cost
    return a.totalCost.compareTo(b.totalCost);
  });

  final best = allOptions.first;
  // print(
  //   "🏆 Best route selected: ${best.tripCount} trip(s), "
  //   "routes: ${best.routeNumbers}, "
  //   "walk: ${best.totalWalkDistance.toInt()}m, cost: ${best.totalCost.toInt()}",
  // );

  return best;
}

class TransferSpot {
  final String name;
  final double latitude;
  final double longitude;
  final List<int> routes; // Updated to use route numbers
  final String priority;

  TransferSpot({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.routes,
    required this.priority,
  });

  LatLng get location => LatLng(latitude, longitude);

  factory TransferSpot.fromJson(Map<String, dynamic> json) {
    return TransferSpot(
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      routes: List<int>.from(json['routes']), // Now expects list of integers
      priority: json['priority'],
    );
  }
}

// New function to validate if a transfer makes geographical sense
bool isValidTransfer(
  LatLng start,
  LatLng destination,
  LatLng transferPoint,
  MultiRouteResult option,
) {
  final distance = Distance();

  // Calculate direct distance from start to destination
  final directDistance = distance.as(LengthUnit.Meter, start, destination);

  // Calculate total distance via transfer point
  final viaTransferDistance =
      distance.as(LengthUnit.Meter, start, transferPoint) +
      distance.as(LengthUnit.Meter, transferPoint, destination);

  // print("   🔍 Transfer validation:");
  // print("      Direct distance: ${directDistance.toInt()}m");
  // print("      Via transfer: ${viaTransferDistance.toInt()}m");
  // print("      Walking distance: ${option.totalWalkDistance.toInt()}m");
  // print(
  //   "      Detour ratio: ${(viaTransferDistance / directDistance).toStringAsFixed(2)}",
  // );

  // More lenient validation - allow up to 2x detour and 1.5km walking
  final isValidDetour = viaTransferDistance <= directDistance * 2.0;
  final isValidWalking = option.totalWalkDistance <= 1500;

  // print("      Valid detour: $isValidDetour, Valid walking: $isValidWalking");

  return isValidDetour && isValidWalking;
}

// Updated evaluateTransferOption with stricter validation
MultiRouteResult? evaluateTransferOption(
  LatLng start,
  LatLng destination,
  JeepneyRoute route1,
  JeepneyRoute route2,
  TransferSpot transferSpot,
) {
  final distance = Distance();

  // More restrictive parameters for transfer segments
  final segment1 = findTransferRouteSegment(
    start,
    transferSpot.location,
    route1.coordinates,
    maxWalkDistance: 600, // Reduced from 1500
    preferredWalkDistance: 300,
    snapThreshold: 40,
    maxTotalWalk: 1000, // Reduced from 2000
  );

  final segment2 = findTransferRouteSegment(
    transferSpot.location,
    destination,
    route2.coordinates,
    maxWalkDistance: 600, // Reduced from 1500
    preferredWalkDistance: 300,
    snapThreshold: 40,
    maxTotalWalk: 1000, // Reduced from 2000
  );

  if (segment1 == null || segment2 == null) return null;

  // Additional check: ensure we're not backtracking significantly
  final startToTransfer = distance.as(
    LengthUnit.Meter,
    start,
    transferSpot.location,
  );
  final transferToEnd = distance.as(
    LengthUnit.Meter,
    transferSpot.location,
    destination,
  );
  final directDistance = distance.as(LengthUnit.Meter, start, destination);

  // If going via transfer is more than 80% longer than direct, skip this option
  if ((startToTransfer + transferToEnd) > directDistance * 1.8) {
    return null;
  }

  // Calculate totals
  final totalWalk =
      segment1.startWalkDistance +
      segment1.endWalkDistance +
      segment2.startWalkDistance +
      segment2.endWalkDistance;

  final totalRide = segment1.rideDistance + segment2.rideDistance;

  // Heavier transfer penalty based on priority and walking distance
  double transferPenalty = transferSpot.priority == "major" ? 500 : 800;

  // Additional penalty for excessive walking in transfer routes
  if (totalWalk > 800) {
    transferPenalty += (totalWalk - 800) * 2; // 2x penalty for excess walking
  }

  final totalCost = totalWalk + totalRide + transferPenalty;

  // print("      ✅ Transfer evaluation:");
  // print("         Route ${route1.routeNumber} → ${route2.routeNumber}");
  // print("         Walk: ${totalWalk.toInt()}m, Ride: ${totalRide.toInt()}m");
  // print(
  //   "         Penalty: ${transferPenalty.toInt()}, Total cost: ${totalCost.toInt()}",
  // );

  return MultiRouteResult(
    segments: [segment1, segment2],
    transferPoints: [transferSpot.location],
    totalWalkDistance: totalWalk,
    totalRideDistance: totalRide,
    totalCost: totalCost,
    tripCount: 2,
    routeNumbers: [route1.routeNumber, route2.routeNumber],
  );
}

List<MultiRouteResult> findMultiRouteOptions(
  LatLng start,
  LatLng destination,
  List<JeepneyRoute> allRoutes,
  List<TransferSpot> transferSpots,
) {
  // print("🔍 Finding 2-route transfer options only...");
  List<MultiRouteResult> options = [];

  // For each transfer spot, find ONLY direct 2-route combinations
  for (final spot in transferSpots) {
    // print("Checking transfer spot: ${spot.name}");

    final availableRoutes =
        allRoutes
            .where((route) => spot.routes.contains(route.routeNumber))
            .toList();

    if (availableRoutes.length < 2) {
      // print("   ❌ Not enough routes at ${spot.name}");
      continue;
    }

    // Find routes that can take us FROM start TO transfer spot
    List<JeepneyRoute> firstLegRoutes = [];
    for (final route in availableRoutes) {
      final segment = findTransferRouteSegment(
        start,
        spot.location,
        route.coordinates,
        maxWalkDistance: 600,
        maxTotalWalk: 1000,
      );
      if (segment != null && segment.startWalkDistance <= 400) {
        firstLegRoutes.add(route);
        // print(
        //   "   ✅ Route ${route.routeNumber} can reach ${spot.name} from start",
        // );
      }
    }

    // Find routes that can take us FROM transfer spot TO destination
    List<JeepneyRoute> secondLegRoutes = [];
    for (final route in availableRoutes) {
      final segment = findTransferRouteSegment(
        spot.location,
        destination,
        route.coordinates,
        maxWalkDistance: 600,
        maxTotalWalk: 1000,
      );
      if (segment != null && segment.endWalkDistance <= 400) {
        secondLegRoutes.add(route);
        // print(
        //   "   ✅ Route ${route.routeNumber} can reach destination from ${spot.name}",
        // );
      }
    }

    // print(
    //   "   First leg routes: ${firstLegRoutes.map((r) => r.routeNumber).toList()}",
    // );
    // print(
    //   "   Second leg routes: ${secondLegRoutes.map((r) => r.routeNumber).toList()}",
    // );

    // Try combinations - but limit to reasonable options
    for (final route1 in firstLegRoutes) {
      for (final route2 in secondLegRoutes) {
        if (route1.routeNumber == route2.routeNumber) continue;

        // print(
        //   "   🔄 Evaluating: Route ${route1.routeNumber} → Route ${route2.routeNumber}",
        // );

        final option = evaluateTransferOption(
          start,
          destination,
          route1,
          route2,
          spot,
        );

        if (option != null) {
          // print(
          //   "   ✅ Valid 2-route option: ${route1.routeNumber} → ${route2.routeNumber} via ${spot.name}",
          // );
          // print("      Total walk: ${option.totalWalkDistance.toInt()}m");
          // print("      Total cost: ${option.totalCost.toInt()}");
          // options.add(option);
        }
      }
    }
  }

  // Sort by cost and keep only the best 3 options to avoid overcomplicated routes
  options.sort((a, b) => a.totalCost.compareTo(b.totalCost));
  if (options.length > 3) {
    options = options.take(3).toList();
  }

  // print("🎯 Final valid 2-route options: ${options.length}");
  return options;
}

List<MultiRouteResult> findSingleRouteOptions(
  LatLng start,
  LatLng destination,
  List<JeepneyRoute> allRoutes,
) {
  List<MultiRouteResult> options = [];

  for (final route in allRoutes) {
    final segment = findBestRouteSegment(
      start,
      destination,
      route.coordinates,
      maxWalkDistance: 1000, // More lenient - allow up to 1km walking per end
      preferredWalkDistance: 400, // Still prefer shorter walks
      maxTotalWalk: 1800, // Up to 1.8km total walking for single route
    );

    if (segment != null) {
      // Bonus for single routes with reasonable walking
      double adjustedCost = segment.totalCost;
      final totalWalk = segment.startWalkDistance + segment.endWalkDistance;

      if (totalWalk <= 600) {
        adjustedCost -= 300; // Big bonus for short walking distances
      } else if (totalWalk <= 1000) {
        adjustedCost -= 100; // Small bonus for moderate walking
      }

      // print("   Single route option: Route ${route.routeNumber}");
      // print("      Walk: ${totalWalk.toInt()}m, Cost: ${adjustedCost.toInt()}");

      options.add(
        MultiRouteResult(
          segments: [segment],
          transferPoints: [],
          totalWalkDistance: totalWalk,
          totalRideDistance: segment.rideDistance,
          totalCost: adjustedCost,
          tripCount: 1,
          routeNumbers: [route.routeNumber],
        ),
      );
    }
  }

  // print("📍 Found ${options.length} single route options");
  return options;
}
