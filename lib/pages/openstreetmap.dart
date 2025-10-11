import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:map_try/model/route_loader.dart';
import 'package:map_try/services/mapbox_service.dart';
import 'package:map_try/services/ors_service.dart';
import 'package:map_try/utils/route_finder/route_finder.dart';
import 'package:map_try/config/debug_locations.dart'; // Add this import

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
  final EnhancedRouteFinder _enhancedRouteFinder = EnhancedRouteFinder();
  RouteEvaluationMeta? _routeMeta;

  List<Polyline> _startWalkingPolylines = [];
  List<Polyline> _endWalkingPolylines = [];
  bool _walkingPolylinesCalculated = false;

  WalkingSegment? _walkToBoarding;
  WalkingSegment? _walkToDestination;
  
  double walkingDistance = 0.0;
  double endWalkingDistance = 0.0;
  double segmentDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _destinationNotifier = widget.destinationNotifier;
    _orsService = OrsService(ORSApiKey);

    _initializeLocation().then((_) {
      // Check if debug destination is set
      if (DebugLocations.isDebugDestinationActive) {
        _destinationNotifier.value = DebugLocations.debugDestinationLocation;
        print("🎯 DEBUG: Using debug destination: ${DebugLocations.getDestinationLocationName()}");
      }

      _destinationNotifier.addListener(() {
        final newDestination = _destinationNotifier.value;
        if (newDestination != null && _currentLocation != null) {
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
      _routeMeta = null;
      _startWalkingPolylines = [];
      _endWalkingPolylines = [];
      _walkingPolylinesCalculated = false;
      _walkToBoarding = null;
      _walkToDestination = null;
      walkingDistance = 0.0;
      endWalkingDistance = 0.0;
      segmentDistance = 0.0;
    });
  }

  Future<void> _initializeLocation() async {
    // Check if debug start location is set
    if (DebugLocations.isDebugStartActive) {
      setState(() {
        _currentLocation = DebugLocations.debugStartLocation;
        isLoading = false;
      });
      print("🐛 DEBUG MODE: Using debug start location: ${DebugLocations.getStartLocationName()}");
      print("   Location: $_currentLocation");
      loadRouteData();
      return;
    }

    // Otherwise use actual GPS location
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
    print("📍 Using actual GPS location: $_currentLocation");
    loadRouteData();
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

  Future<void> _userCurrentLocation() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fetching location...'))
      );
      await _initializeLocation();
    } else {
      _mapController.move(_currentLocation!, 15.0);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }

  // ENHANCED ROUTE LOADING with turn-by-turn directions
  void loadRouteData() async {
    _clearRouteData();
    print("🚀 Starting enhanced route finding");

    List<JeepneyRoute> jeepneyRoutes = await loadRoutesFromJson();
    print("📊 Loaded ${jeepneyRoutes.length} jeepney routes");

    if (!mounted || _currentLocation == null || _destination == null) {
      print("⚠️ Not mounted or missing location data");
      return;
    }

    print("📍 Current: $_currentLocation ${DebugLocations.isDebugStartActive ? '[DEBUG: ${DebugLocations.getStartLocationName()}]' : '[GPS]'}");
    print("🎯 Destination: $_destination ${DebugLocations.isDebugDestinationActive ? '[DEBUG: ${DebugLocations.getDestinationLocationName()}]' : '[User Selected]'}");

    // Use the enhanced route finder
    final result = await _enhancedRouteFinder.findBestRoute(
      jeepneyRoutes,
      _currentLocation!,
      _destination!,
      maxBoardDistance: 800.0,
      maxAlightDistance: 500.0,
      debug: true,
    );

    if (result.route != null && result.meta != null) {
      print("✅ Found best route: ${result.route!.routeNumber}");

      setState(() {
        _matchedRoute = result.route;
        _routeMeta = result.meta;
        _route = result.meta!.jeepneySegment;
        segmentDistance = result.meta!.jeepneyDistM;
        walkingDistance = result.meta!.boardDistM;
        endWalkingDistance = result.meta!.alightDistM;
        _walkingPolylinesCalculated = false;
      });

      // Fetch walking routes with turn-by-turn directions
      await _updateAllWalkingPolylinesWithDirections();
    } else {
      print("❌ No suitable route found");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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

  // Update walking polylines and extract turn-by-turn directions
  Future<void> _updateAllWalkingPolylinesWithDirections() async {
    if (_currentLocation == null || _destination == null || _routeMeta == null) {
      return;
    }

    setState(() {
      _startWalkingPolylines = [];
      _endWalkingPolylines = [];
    });

    final jeepneyStartPoint = _routeMeta!.boardPoint;
    final jeepneyEndPoint = _routeMeta!.alightPoint;

    final futures = <Future<void>>[];

    // Start walking route
    if (_routeMeta!.boardDistM > 5) {
      futures.add(
        _orsService
            .getRouteWithDirections(_currentLocation!, jeepneyStartPoint, profile: "foot-walking")
            .then((geoJson) async {
              if (geoJson != null && mounted) {
                // Extract turn-by-turn directions
                _walkToBoarding = await _extractWalkingDirections(
                  geoJson,
                  "Walk to Jeepney Boarding Point",
                );

                setState(() {
                  _startWalkingPolylines = createDottedPolyline(
                    _walkToBoarding?.coordinates ?? [],
                    color: Colors.blue,
                    strokeWidth: 3,
                  );
                });
              }
            }),
      );
    }

    // End walking route
    if (_routeMeta!.alightDistM > 5) {
      futures.add(
        _orsService
            .getRouteWithDirections(jeepneyEndPoint, _destination!, profile: "foot-walking")
            .then((geoJson) async {
              if (geoJson != null && mounted) {
                // Extract turn-by-turn directions
                _walkToDestination = await _extractWalkingDirections(
                  geoJson,
                  "Walk to Final Destination",
                );

                setState(() {
                  _endWalkingPolylines = createDottedPolyline(
                    _walkToDestination?.coordinates ?? [],
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

  // Extract walking directions from ORS GeoJSON
  Future<WalkingSegment?> _extractWalkingDirections(
    dynamic orsGeoJson,
    String title,
  ) async {
    if (orsGeoJson == null) return null;

    try {
      print('🔍 Parsing ORS response for: $title');
      
      // Debug: Print the structure
      if (orsGeoJson is Map) {
        print('   Response keys: ${orsGeoJson.keys.toList()}');
      }

      // Handle different possible response structures
      Map<String, dynamic> data;
      
      if (orsGeoJson is String) {
        // If it's a string, try to parse it as JSON
        data = json.decode(orsGeoJson) as Map<String, dynamic>;
      } else if (orsGeoJson is Map<String, dynamic>) {
        data = orsGeoJson;
      } else {
        print('   ❌ Unexpected response type: ${orsGeoJson.runtimeType}');
        return null;
      }

      // Check if response has 'features' array
      if (!data.containsKey('features')) {
        print('   ❌ No "features" key in response');
        print('   Available keys: ${data.keys.toList()}');
        return null;
      }

      final features = data['features'] as List;
      if (features.isEmpty) {
        print('   ❌ Empty features array');
        return null;
      }

      final feature = features[0] as Map<String, dynamic>;
      final properties = feature['properties'] as Map<String, dynamic>;
      final summary = properties['summary'] as Map<String, dynamic>;
      final segments = properties['segments'] as List;
      
      if (segments.isEmpty) {
        print('   ❌ Empty segments array');
        return null;
      }
      
      final segment = segments[0] as Map<String, dynamic>;
      final steps = segment['steps'] as List;

      final totalDistance = (summary['distance'] as num).toDouble();
      final totalDuration = (summary['duration'] as num).toDouble();

      print('   ✅ Parsed: ${totalDistance.toStringAsFixed(0)}m, ${(totalDuration / 60).toStringAsFixed(1)}min, ${steps.length} steps');

      final directionSteps = <DirectionStep>[];
      for (int i = 0; i < steps.length; i++) {
        final step = steps[i] as Map<String, dynamic>;
        directionSteps.add(DirectionStep(
          stepNumber: i + 1,
          instruction: step['instruction'] as String? ?? '',
          distanceM: (step['distance'] as num?)?.toDouble() ?? 0.0,
          durationS: (step['duration'] as num?)?.toDouble() ?? 0.0,
          street: step['name'] as String? ?? '',
          type: step['type'] as int? ?? -1,
        ));
      }

      // Extract coordinates
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final coords = (geometry['coordinates'] as List)
          .map((c) => LatLng(c[1] as double, c[0] as double))
          .toList();

      return WalkingSegment(
        title: title,
        totalDistanceM: totalDistance,
        totalDurationS: totalDuration,
        steps: directionSteps,
        coordinates: coords,
      );
    } catch (e, stackTrace) {
      print('❌ Error extracting walking directions: $e');
      print('   Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      return null;
    }
  }

  // Enhanced route modal with turn-by-turn directions
  void showRouteModal(BuildContext context) {
    if (_isModalOpen) return;
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
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Header
                        const Center(
                          child: Text(
                            '🗺️ Turn-by-Turn Directions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Debug info banner (only shown if debug mode active)
                        if (DebugLocations.isDebugStartActive || 
                            DebugLocations.isDebugDestinationActive)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              border: Border.all(color: Colors.orange),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.bug_report, size: 16, color: Colors.orange),
                                    SizedBox(width: 4),
                                    Text(
                                      'DEBUG MODE ACTIVE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (DebugLocations.isDebugStartActive)
                                  Text(
                                    'Start: ${DebugLocations.getStartLocationName()}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                if (DebugLocations.isDebugDestinationActive)
                                  Text(
                                    'Destination: ${DebugLocations.getDestinationLocationName()}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                          ),

                        // Total Summary
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total: ${_getTotalDistance()} • ${_getTotalTime()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (_matchedRoute != null)
                                Text(
                                  'via Jeepney Route ${_matchedRoute!.routeNumber}',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 32),

                        // PART 1: Walk to boarding
                        if (_walkToBoarding != null) ...[
                          _buildSectionHeader(
                            '🚶 PART 1: Walk to Jeepney Boarding Point',
                            _walkToBoarding!.formattedDistance,
                            _walkToBoarding!.formattedDuration,
                          ),
                          ..._walkToBoarding!.steps.map((step) => _buildDirectionStep(step)),
                        ] else ...[
                          _buildSectionHeader(
                            '🚶 PART 1: Walk to Jeepney Boarding Point',
                            '${walkingDistance.toStringAsFixed(0)} m',
                            '~${(walkingDistance / 1.4 / 60).toStringAsFixed(0)} min',
                          ),
                          ListTile(
                            leading: const CircleAvatar(
                              child: Text('1'),
                            ),
                            title: const Text('Walk to boarding area'),
                            subtitle: Text('${walkingDistance.toStringAsFixed(0)} meters'),
                          ),
                        ],

                        const Divider(height: 32),

                        // PART 2: Jeepney ride
                        _buildSectionHeader(
                          '🚌 PART 2: Take Jeepney Route ${_matchedRoute?.routeNumber ?? ""}',
                          '${(segmentDistance / 1000).toStringAsFixed(1)} km',
                          '~${(segmentDistance / 333.33).toStringAsFixed(0)} min',
                        ),
                        if (_matchedRoute != null) ...[
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.directions_bus, color: Colors.white),
                            ),
                            title: Text('Board Jeepney Route ${_matchedRoute!.routeNumber}'),
                            subtitle: Text(_matchedRoute!.direction),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Image.asset(
                              "Assets/route_pics/${_matchedRoute!.routeNumber}.png",
                              height: 200,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 100,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.broken_image, size: 40),
                                ),
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const CircleAvatar(
                              child: Text('2'),
                            ),
                            title: const Text('Stay on jeepney'),
                            subtitle: Text(
                              'Ride for ${(segmentDistance / 1000).toStringAsFixed(1)} km',
                            ),
                          ),
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.arrow_downward, color: Colors.white),
                            ),
                            title: const Text('Alight at destination area'),
                            subtitle: Text(
                              'Destination is ${endWalkingDistance.toStringAsFixed(0)}m from alighting point',
                            ),
                          ),
                        ],

                        const Divider(height: 32),

                        // PART 3: Walk to destination
                        if (_walkToDestination != null) ...[
                          _buildSectionHeader(
                            '🚶 PART 3: Walk to Final Destination',
                            _walkToDestination!.formattedDistance,
                            _walkToDestination!.formattedDuration,
                          ),
                          ..._walkToDestination!.steps.map((step) => _buildDirectionStep(step)),
                        ] else ...[
                          _buildSectionHeader(
                            '🚶 PART 3: Walk to Final Destination',
                            '${endWalkingDistance.toStringAsFixed(0)} m',
                            '~${(endWalkingDistance / 1.4 / 60).toStringAsFixed(0)} min',
                          ),
                          ListTile(
                            leading: const CircleAvatar(
                              child: Text('1'),
                            ),
                            title: const Text('Walk to destination'),
                            subtitle: Text('${endWalkingDistance.toStringAsFixed(0)} meters'),
                          ),
                        ],

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    ).then((_) {
      _isModalOpen = false;
    });
  }

  Widget _buildSectionHeader(String title, String distance, String duration) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$distance • $duration',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionStep(DirectionStep step) {
    return ListTile(
      leading: CircleAvatar(
        child: Text('${step.stepNumber}'),
      ),
      title: Text(step.instruction),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${step.formattedDistance} • ${step.formattedDuration}'),
          if (step.street.isNotEmpty)
            Text(
              'on ${step.street}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  String _getTotalDistance() {
    final total = walkingDistance + segmentDistance + endWalkingDistance;
    return '${(total / 1000).toStringAsFixed(1)} km';
  }

  String _getTotalTime() {
    final walkTime1 = walkingDistance / 1.4 / 60;
    final walkTime2 = endWalkingDistance / 1.4 / 60;
    final jeepneyTime = segmentDistance / 333.33;
    final total = walkTime1 + walkTime2 + jeepneyTime;
    return '${total.toStringAsFixed(0)} min';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'MAPAkaon',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrangeAccent,
                    ),
                  ),
                  // Debug indicator
                  if (DebugLocations.isDebugStartActive || 
                      DebugLocations.isDebugDestinationActive)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'DEBUG',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              centerTitle: true,
              backgroundColor: const Color.fromRGBO(255, 255, 255, 0.01),
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.map, color: Colors.deepOrangeAccent),
                  onPressed: () {},
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

          // Start walking polyline
          if (_startWalkingPolylines.isNotEmpty)
            PolylineLayer(polylines: _startWalkingPolylines),

          // End walking polyline
          if (_endWalkingPolylines.isNotEmpty)
            PolylineLayer(polylines: _endWalkingPolylines),

          // Jeepney route
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

          // Current location marker
          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation!,
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.person_pin_circle_outlined,
                        size: 40,
                        color: Colors.white,
                      ),
                      // Debug indicator on marker
                      if (DebugLocations.isDebugStartActive)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'D',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.location_pin,
                        size: 40,
                        color: Colors.redAccent,
                      ),
                      // Debug indicator on destination marker
                      if (DebugLocations.isDebugDestinationActive)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'D',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
          if (_matchedRoute != null && _route.isNotEmpty)
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

// Dotted line helper function
List<Polyline> createDottedPolyline(
  List<LatLng> path, {
  double dashLengthMeters = 8,
  double gapLengthMeters = 6,
  double strokeWidth = 3,
  Color color = Colors.blue,
}) {
  final List<Polyline> out = [];
  if (path.length < 2) return out;

  final distance = const Distance();

  LatLng lerp(LatLng a, LatLng b, double t) => LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t,
  );

  for (int i = 0; i < path.length - 1; i++) {
    final a = path[i];
    final b = path[i + 1];
    final double segDist = distance.as(LengthUnit.Meter, a, b);
    if (segDist <= 0) continue;

    double pos = 0.0;
    while (pos < segDist) {
      final double end = (pos + dashLengthMeters).clamp(0.0, segDist);
      final double t1 = pos / segDist;
      final double t2 = end / segDist;

      out.add(
        Polyline(
          points: [lerp(a, b, t1), lerp(a, b, t2)],
          color: color,
          strokeWidth: strokeWidth,
        ),
      );

      pos += dashLengthMeters + gapLengthMeters;
    }
  }
  return out;
}