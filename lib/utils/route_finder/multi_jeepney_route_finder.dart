// utils/route_finder/multi_jeepney_route_finder.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_try/model/route_loader.dart';
import 'package:map_try/utils/route_finder/route_finder.dart';

// Transfer spot model
class TransferSpot {
  final String name;
  final LatLng location;
  final List<String> routes;
  final String priority;

  TransferSpot({
    required this.name,
    required this.location,
    required this.routes,
    required this.priority,
  });

  factory TransferSpot.fromJson(Map<String, dynamic> json) {
    return TransferSpot(
      name: json['name'] as String,
      location: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      // CRITICAL FIX: Ensure routes are always strings for consistent comparison
      routes: (json['routes'] as List).map((e) => e.toString()).toList(),
      priority: json['priority'] as String,
    );
  }
}

// Multi-route segment
class MultiRouteSegment {
  final JeepneyRoute route;
  final RouteEvaluationMeta meta;
  final int segmentOrder;

  MultiRouteSegment({
    required this.route,
    required this.meta,
    required this.segmentOrder,
  });
}

// Transfer connection between routes
class TransferConnection {
  final TransferSpot transferSpot;
  final MultiRouteSegment fromSegment;
  final LatLng fromAlightPoint;
  final LatLng toBoardPoint;
  final double walkDistance;

  TransferConnection({
    required this.transferSpot,
    required this.fromSegment,
    required this.fromAlightPoint,
    required this.toBoardPoint,
    required this.walkDistance,
  });
}

// Complete multi-jeepney route result
class MultiJeepneyRouteResult {
  final List<MultiRouteSegment> segments;
  final List<TransferConnection> transfers;
  final double totalScore;
  final double totalDistance;
  final double totalDuration;

  MultiJeepneyRouteResult({
    required this.segments,
    required this.transfers,
    required this.totalScore,
    required this.totalDistance,
    required this.totalDuration,
  });

  int get numberOfTransfers => transfers.length;
  
  String get routeSummary {
    return segments.map((s) => s.route.routeNumber).join(' → ');
  }
}

// Partial route path during recursive search
class _PartialPath {
  final List<MultiRouteSegment> segments;
  final List<TransferConnection> transfers;
  final LatLng currentLocation;
  final double accumulatedScore;
  final double accumulatedDistance;
  final Set<String> usedRoutes; // Prevent route repetition

  _PartialPath({
    required this.segments,
    required this.transfers,
    required this.currentLocation,
    required this.accumulatedScore,
    required this.accumulatedDistance,
    required this.usedRoutes,
  });

  _PartialPath.initial(LatLng start)
      : segments = [],
        transfers = [],
        currentLocation = start,
        accumulatedScore = 0.0,
        accumulatedDistance = 0.0,
        usedRoutes = <String>{};
}

class MultiJeepneyRouteFinder {
  final Distance _distance = const Distance();
  final EnhancedRouteFinder _singleRouteFinder = EnhancedRouteFinder();
  
  List<TransferSpot> _transferSpots = [];
  
  // Tunable parameters
  static const int MAX_TRANSFERS = 2;
  static const double MAX_TOTAL_DURATION_MINUTES = 120.0; // 2 hours max
  static const double MAX_TOTAL_WALK_DISTANCE = 1000.0; // 1km max walking
  static const double PRUNING_THRESHOLD_MULTIPLIER = 1.5; // Prune paths 50% worse than current best

  // Load transfer spots from JSON
  Future<void> loadTransferSpots() async {
    try {
      final jsonString = await rootBundle.loadString('assets/transfer_spots.json');
      final List<dynamic> jsonData = json.decode(jsonString) as List;
      _transferSpots = jsonData.map((e) => TransferSpot.fromJson(e as Map<String, dynamic>)).toList();
      print('✅ Loaded ${_transferSpots.length} transfer spots');
    } catch (e) {
      print('❌ Error loading transfer spots: $e');
      _transferSpots = [];
    }
  }

  // Find routes that pass near a location
  List<JeepneyRoute> _findRoutesNearLocation(
    List<JeepneyRoute> allRoutes,
    LatLng location,
    double maxDistance,
  ) {
    List<JeepneyRoute> nearbyRoutes = [];
    
    for (final route in allRoutes) {
      for (final coord in route.coordinates) {
        final dist = _distance.as(LengthUnit.Meter, coord, location);
        if (dist <= maxDistance) {
          nearbyRoutes.add(route);
          break;
        }
      }
    }
    
    return nearbyRoutes;
  }

  // Find transfer spots accessible from a route
  List<TransferSpot> _findTransferSpotsForRoute(
    JeepneyRoute route,
    double maxDistanceFromRoute,
  ) {
    List<TransferSpot> accessibleSpots = [];
    
    for (final spot in _transferSpots) {
      // FIXED: Convert route number to string for comparison
      if (!spot.routes.contains(route.routeNumber.toString())) continue;
      
      for (final coord in route.coordinates) {
        final dist = _distance.as(LengthUnit.Meter, coord, spot.location);
        if (dist <= maxDistanceFromRoute) {
          accessibleSpots.add(spot);
          break;
        }
      }
    }
    
    return accessibleSpots;
  }

  // Calculate straight-line distance to destination (for pruning)
  double _distanceToDestination(LatLng current, LatLng dest) {
    return _distance.as(LengthUnit.Meter, current, dest);
  }

  // Recursive function to find routes with up to maxTransfers
  Future<List<MultiJeepneyRouteResult>> _findRoutesRecursive({
    required List<JeepneyRoute> allRoutes,
    required _PartialPath currentPath,
    required LatLng destination,
    required int transfersRemaining,
    required double currentBestScore,
    required double maxBoardDistance,
    required double maxAlightDistance,
    required double maxTransferWalkDistance,
    required double transferPenalty,
    required double transferWalkWeight,
    required bool debug,
  }) async {
    List<MultiJeepneyRouteResult> results = [];

    // PRUNING 1: If current score already exceeds best by threshold, abort
    if (currentPath.accumulatedScore > currentBestScore * PRUNING_THRESHOLD_MULTIPLIER) {
      return results;
    }

    // PRUNING 2: If total walking exceeds limit, abort
    double totalWalking = currentPath.transfers.fold(0.0, (sum, t) => sum + t.walkDistance);
    if (totalWalking > MAX_TOTAL_WALK_DISTANCE) {
      return results;
    }

    // PRUNING 3: Check if we're making geographical progress
    final currentDistToDest = _distanceToDestination(currentPath.currentLocation, destination);

    // Base case: Try direct route to destination
    final directRouteCandidates = _findRoutesNearLocation(
      allRoutes,
      destination,
      maxAlightDistance,
    );

    // Only log at depth 0 (first level of recursion)
    final isTopLevel = currentPath.segments.isEmpty;

    for (final route in directRouteCandidates) {
      // Skip if already used
      if (currentPath.usedRoutes.contains(route.routeNumber.toString())) continue;

      // Evaluate route from current location to destination
      final meta = _singleRouteFinder.evaluateRoute(
        route.coordinates,
        currentPath.currentLocation,
        destination,
        maxBoardDistance: currentPath.segments.isEmpty ? maxBoardDistance : maxTransferWalkDistance,
        maxAlightDistance: maxAlightDistance,
      );

      if (meta == null) continue;

      // Calculate final score and distance
      final finalScore = currentPath.accumulatedScore + meta.score;
      final finalDistance = currentPath.accumulatedDistance + 
          meta.boardDistM + meta.jeepneyDistM + meta.alightDistM;

      // Estimate total duration
      final finalDuration = _estimateTotalDuration(
        currentPath,
        meta,
        0, // No additional transfer walk
      );

      // PRUNING 4: Check max duration
      if (finalDuration > MAX_TOTAL_DURATION_MINUTES * 60) continue;

      // Create complete result
      final segments = [
        ...currentPath.segments,
        MultiRouteSegment(
          route: route,
          meta: meta,
          segmentOrder: currentPath.segments.length + 1,
        ),
      ];

      results.add(MultiJeepneyRouteResult(
        segments: segments,
        transfers: currentPath.transfers,
        totalScore: finalScore,
        totalDistance: finalDistance,
        totalDuration: finalDuration,
      ));

      if (debug && isTopLevel) {
        print('   ✅ Found path: ${segments.map((s) => s.route.routeNumber).join(" → ")} (${(finalDuration / 60).toStringAsFixed(0)}min)');
      }
    }

    // Recursive case: Try adding another transfer (if allowed)
    if (transfersRemaining > 0) {
      for (final transferSpot in _transferSpots) {
        // Find routes that serve this transfer spot
        final candidateRoutes = allRoutes.where((route) {
          final routeNumStr = route.routeNumber.toString();
          if (currentPath.usedRoutes.contains(routeNumStr)) return false;
          return transferSpot.routes.contains(routeNumStr);
        }).toList();

        if (candidateRoutes.isEmpty) continue;

        for (final route in candidateRoutes) {
          // Evaluate route from current location to transfer spot
          final meta = _singleRouteFinder.evaluateRoute(
            route.coordinates,
            currentPath.currentLocation,
            transferSpot.location,
            maxBoardDistance: currentPath.segments.isEmpty ? maxBoardDistance : maxTransferWalkDistance,
            maxAlightDistance: maxTransferWalkDistance,
          );

          if (meta == null) continue;

          // Calculate transfer walk distance
          final transferWalkDist = _distance.as(
            LengthUnit.Meter,
            meta.alightPoint,
            transferSpot.location,
          );

          if (transferWalkDist > maxTransferWalkDistance) continue;

          // Calculate new accumulated values
          final newScore = currentPath.accumulatedScore + 
              meta.score + 
              (transferWalkDist * transferWalkWeight) + 
              transferPenalty;
          
          final newDistance = currentPath.accumulatedDistance + 
              meta.boardDistM + 
              meta.jeepneyDistM + 
              meta.alightDistM + 
              transferWalkDist;

          // PRUNING 5: Check if new location is closer to destination (relaxed)
          final newDistToDest = _distanceToDestination(transferSpot.location, destination);
          if (newDistToDest >= currentDistToDest * 1.3) continue;

          // Create new partial path
          final newSegment = MultiRouteSegment(
            route: route,
            meta: meta,
            segmentOrder: currentPath.segments.length + 1,
          );

          final newTransfer = TransferConnection(
            transferSpot: transferSpot,
            fromSegment: newSegment,
            fromAlightPoint: meta.alightPoint,
            toBoardPoint: transferSpot.location,
            walkDistance: transferWalkDist,
          );

          final newPath = _PartialPath(
            segments: [...currentPath.segments, newSegment],
            transfers: [...currentPath.transfers, newTransfer],
            currentLocation: transferSpot.location,
            accumulatedScore: newScore,
            accumulatedDistance: newDistance,
            usedRoutes: Set<String>.from([...currentPath.usedRoutes, route.routeNumber.toString()]),
          );

          if (debug && isTopLevel) {
            print('   🔄 Trying: ${route.routeNumber} → ${transferSpot.name}');
          }

          // Recurse with one less transfer remaining
          final subResults = await _findRoutesRecursive(
            allRoutes: allRoutes,
            currentPath: newPath,
            destination: destination,
            transfersRemaining: transfersRemaining - 1,
            currentBestScore: currentBestScore,
            maxBoardDistance: maxBoardDistance,
            maxAlightDistance: maxAlightDistance,
            maxTransferWalkDistance: maxTransferWalkDistance,
            transferPenalty: transferPenalty,
            transferWalkWeight: transferWalkWeight,
            debug: debug,
          );

          results.addAll(subResults);
        }
      }
    }

    return results;
  }

  // Helper: Estimate total duration
  double _estimateTotalDuration(_PartialPath path, RouteEvaluationMeta finalMeta, double finalTransferWalk) {
    const walkSpeed = 1.4; // m/s
    const jeepneySpeed = 5.56; // m/s (20 km/h)

    double duration = 0.0;

    // Add all previous segments
    for (final segment in path.segments) {
      duration += segment.meta.boardDistM / walkSpeed;
      duration += segment.meta.jeepneyDistM / jeepneySpeed;
      duration += segment.meta.alightDistM / walkSpeed;
    }

    // Add all transfer walks
    for (final transfer in path.transfers) {
      duration += transfer.walkDistance / walkSpeed;
    }

    // Add final segment
    duration += finalMeta.boardDistM / walkSpeed;
    duration += finalMeta.jeepneyDistM / jeepneySpeed;
    duration += finalMeta.alightDistM / walkSpeed;
    duration += finalTransferWalk / walkSpeed;

    return duration;
  }

  // Find the best multi-jeepney route (up to MAX_TRANSFERS)
  Future<MultiJeepneyRouteResult?> findBestMultiRoute(
    List<JeepneyRoute> allRoutes,
    LatLng start,
    LatLng dest, {
    double maxBoardDistance = 800.0,
    double maxAlightDistance = 500.0,
    double maxTransferWalkDistance = 300.0,
    double transferPenalty = 500.0,
    double transferWalkWeight = 4.0,
    bool debug = false,
  }) async {
    if (_transferSpots.isEmpty) {
      await loadTransferSpots();
    }

    if (debug) {
      print('🔄 Searching for multi-jeepney routes...');
    }

    // Start with empty path
    final initialPath = _PartialPath.initial(start);

    // Find all possible routes recursively
    final allResults = await _findRoutesRecursive(
      allRoutes: allRoutes,
      currentPath: initialPath,
      destination: dest,
      transfersRemaining: MAX_TRANSFERS,
      currentBestScore: double.infinity,
      maxBoardDistance: maxBoardDistance,
      maxAlightDistance: maxAlightDistance,
      maxTransferWalkDistance: maxTransferWalkDistance,
      transferPenalty: transferPenalty,
      transferWalkWeight: transferWalkWeight,
      debug: debug,
    );

    if (allResults.isEmpty) {
      if (debug) print('❌ No multi-route found\n');
      return null;
    }

    // Find best result by score
    allResults.sort((a, b) => a.totalScore.compareTo(b.totalScore));
    final bestResult = allResults.first;

    if (debug) {
      print('\n✅ BEST ROUTE: ${bestResult.routeSummary}');
      print('   Transfers: ${bestResult.numberOfTransfers}');
      print('   Distance: ${(bestResult.totalDistance / 1000).toStringAsFixed(2)}km');
      print('   Duration: ${(bestResult.totalDuration / 60).toStringAsFixed(0)}min');
      if (allResults.length > 1) {
        print('   (Found ${allResults.length} alternatives)\n');
      }
    }

    return bestResult;
  }

  // Main entry point: Try single route first, fall back to multi-route
  Future<dynamic> findBestRouteWithTransfer(
    List<JeepneyRoute> allRoutes,
    LatLng start,
    LatLng dest, {
    double maxBoardDistance = 800.0,
    double maxAlightDistance = 500.0,
    bool debug = false,
  }) async {
    // Try single route first
    final singleRouteResult = await _singleRouteFinder.findBestRoute(
      allRoutes,
      start,
      dest,
      maxBoardDistance: maxBoardDistance,
      maxAlightDistance: maxAlightDistance,
      debug: debug,
    );

    if (singleRouteResult.route != null) {
      if (debug) print('✅ Direct route found\n');
      return singleRouteResult;
    }

    // No single route found, try multi-route with transfer
    if (debug) print('\n🔄 No direct route. Searching with transfers...\n');

    final multiRouteResult = await findBestMultiRoute(
      allRoutes,
      start,
      dest,
      maxBoardDistance: maxBoardDistance,
      maxAlightDistance: maxAlightDistance,
      debug: debug,
    );

    if (multiRouteResult != null) {
      return multiRouteResult;
    }

    if (debug) print('❌ No route found\n');
    return null;
  }
}