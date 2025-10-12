// utils/route_finder/enhanced_route_finder.dart
import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:map_try/model/route_loader.dart';

// Direction step for turn-by-turn navigation
class DirectionStep {
  final int stepNumber;
  final String instruction;
  final double distanceM;
  final double durationS;
  final String street;
  final int type;

  DirectionStep({
    required this.stepNumber,
    required this.instruction,
    required this.distanceM,
    required this.durationS,
    required this.street,
    required this.type,
  });

  String get formattedDistance {
    if (distanceM < 1000) {
      return '${distanceM.toStringAsFixed(0)} m';
    } else {
      return '${(distanceM / 1000).toStringAsFixed(1)} km';
    }
  }

  String get formattedDuration {
    if (durationS < 60) {
      return '${durationS.toStringAsFixed(0)} sec';
    }
    final minutes = durationS / 60;
    if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)} min';
    }
    final hours = minutes / 60;
    final remainingMin = minutes % 60;
    return '${hours.toStringAsFixed(0)} hr ${remainingMin.toStringAsFixed(0)} min';
  }
}

// Walking segment with directions
class WalkingSegment {
  final String title;
  final double totalDistanceM;
  final double totalDurationS;
  final List<DirectionStep> steps;
  final List<LatLng> coordinates;

  WalkingSegment({
    required this.title,
    required this.totalDistanceM,
    required this.totalDurationS,
    required this.steps,
    required this.coordinates,
  });

  String get formattedDistance {
    if (totalDistanceM < 1000) {
      return '${totalDistanceM.toStringAsFixed(0)} m';
    }
    return '${(totalDistanceM / 1000).toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final minutes = totalDurationS / 60;
    return '${minutes.toStringAsFixed(0)} min';
  }
}

// Jeepney segment info
class JeepneySegmentInfo {
  final String routeNumber;
  final String direction;
  final double distanceM;
  final double durationS;
  final String boardInstruction;
  final String alightInstruction;
  final List<LatLng> coordinates;
  final int boardIdx;
  final int alightIdx;

  JeepneySegmentInfo({
    required this.routeNumber,
    required this.direction,
    required this.distanceM,
    required this.durationS,
    required this.boardInstruction,
    required this.alightInstruction,
    required this.coordinates,
    required this.boardIdx,
    required this.alightIdx,
  });

  String get formattedDistance {
    return '${(distanceM / 1000).toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final minutes = durationS / 60;
    return '~${minutes.toStringAsFixed(0)} min';
  }
}

// Complete route result with turn-by-turn directions
class EnhancedRouteResult {
  final bool success;
  final String message;
  final double totalDistanceM;
  final double totalDurationS;
  
  final WalkingSegment? walkToBoarding;
  final JeepneySegmentInfo jeepneyRide;
  final WalkingSegment? walkToDestination;
  
  final List<List<LatLng>>? boardingZonePolygon;
  final List<List<LatLng>>? alightingZonePolygon;
  final LatLng startMarker;
  final LatLng destMarker;

  EnhancedRouteResult({
    required this.success,
    required this.message,
    required this.totalDistanceM,
    required this.totalDurationS,
    this.walkToBoarding,
    required this.jeepneyRide,
    this.walkToDestination,
    this.boardingZonePolygon,
    this.alightingZonePolygon,
    required this.startMarker,
    required this.destMarker,
  });

  String get formattedTotalDistance {
    return '${(totalDistanceM / 1000).toStringAsFixed(1)} km';
  }

  String get formattedTotalDuration {
    final minutes = totalDurationS / 60;
    return '${minutes.toStringAsFixed(0)} min';
  }
}

// Candidate for destination alighting
class DestinationCandidate {
  final LatLng point;
  final int index;
  final double distance;
  final String type; // 'node' or 'segment'

  DestinationCandidate({
    required this.point,
    required this.index,
    required this.distance,
    required this.type,
  });
}

// Boarding point candidate
class BoardingCandidate {
  final LatLng point;
  final int index;
  final double actualDistance;
  final double effectiveDistance;
  final String type;

  BoardingCandidate({
    required this.point,
    required this.index,
    required this.actualDistance,
    required this.effectiveDistance,
    required this.type,
  });
}

// Route evaluation metadata
class RouteEvaluationMeta {
  final LatLng boardPoint;
  final int boardIdx;
  final double boardDistM;
  
  final LatLng alightPoint;
  final int alightIdx;
  final double alightDistM;
  
  final List<LatLng> jeepneySegment;
  final double jeepneyDistM;
  final double score;
  
  final int refBoardIdx;
  final bool optimized;
  final bool directionAdjusted;
  final int destCandidatesEvaluated;

  RouteEvaluationMeta({
    required this.boardPoint,
    required this.boardIdx,
    required this.boardDistM,
    required this.alightPoint,
    required this.alightIdx,
    required this.alightDistM,
    required this.jeepneySegment,
    required this.jeepneyDistM,
    required this.score,
    required this.refBoardIdx,
    required this.optimized,
    required this.directionAdjusted,
    required this.destCandidatesEvaluated,
  });
}

class EnhancedRouteFinder {
  final Distance _distance = const Distance();

  // Find all destination candidates within range
  List<DestinationCandidate> _findAllNearbyDestinationCandidates(
    List<LatLng> routeCoords,
    LatLng dest,
    double maxAlightDistance,
  ) {
    List<DestinationCandidate> candidates = [];

    // Check all nodes
    for (int i = 0; i < routeCoords.length; i++) {
      final dist = _distance.as(LengthUnit.Meter, routeCoords[i], dest);
      if (dist <= maxAlightDistance) {
        candidates.add(DestinationCandidate(
          point: routeCoords[i],
          index: i,
          distance: dist,
          type: 'node',
        ));
      }
    }

    // Check all segments for interpolated points
    for (int i = 0; i < routeCoords.length - 1; i++) {
      final segStart = routeCoords[i];
      final segEnd = routeCoords[i + 1];
      final result = _pointToSegmentDistance(dest, segStart, segEnd);
      
      if (result.distance <= maxAlightDistance) {
        candidates.add(DestinationCandidate(
          point: result.closestPoint,
          index: i,
          distance: result.distance,
          type: 'segment',
        ));
      }
    }

    // Sort by distance
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    return candidates;
  }

  // Calculate direction penalty score
  double _calculateDirectionScore(
    List<LatLng> routeCoords,
    int boardIdx,
    int destIdx,
    LatLng destPoint,
  ) {
    if (boardIdx >= routeCoords.length - 1) return 0.0;
    
    final segmentsToCheck = min(10, destIdx - boardIdx);
    if (segmentsToCheck < 2) return 0.0;

    final initialDist = _distance.as(
      LengthUnit.Meter,
      routeCoords[boardIdx],
      destPoint,
    );

    final checkIdx = min(boardIdx + segmentsToCheck, routeCoords.length - 1);
    final laterDist = _distance.as(
      LengthUnit.Meter,
      routeCoords[checkIdx],
      destPoint,
    );

    if (laterDist > initialDist) {
      return (laterDist - initialDist) * 2.0;
    }

    return 0.0;
  }

  // Find best boarding point before destination
  BoardingCandidate? _findBestBoardingPointBeforeDestination(
    List<LatLng> routeCoords,
    LatLng start,
    int destIdx,
    LatLng destPoint,
    double maxBoardDistance,
    bool considerDirection,
  ) {
    List<BoardingCandidate> candidates = [];

    // Check all nodes before destination
    for (int i = 0; i < destIdx; i++) {
      final coord = routeCoords[i];
      final dist = _distance.as(LengthUnit.Meter, start, coord);
      
      if (dist <= maxBoardDistance) {
        double directionPenalty = 0.0;
        if (considerDirection) {
          directionPenalty = _calculateDirectionScore(
            routeCoords,
            i,
            destIdx,
            destPoint,
          );
        }
        
        final effectiveDist = dist + directionPenalty;
        candidates.add(BoardingCandidate(
          point: coord,
          index: i,
          actualDistance: dist,
          effectiveDistance: effectiveDist,
          type: 'node',
        ));
      }
    }

    // Check all segments before destination
    for (int i = 0; i < destIdx; i++) {
      final segStart = routeCoords[i];
      final segEnd = i + 1 < routeCoords.length ? routeCoords[i + 1] : null;
      if (segEnd == null) continue;

      final result = _pointToSegmentDistance(start, segStart, segEnd);
      
      if (result.distance <= maxBoardDistance) {
        double directionPenalty = 0.0;
        if (considerDirection) {
          directionPenalty = _calculateDirectionScore(
            routeCoords,
            i,
            destIdx,
            destPoint,
          );
        }
        
        final effectiveDist = result.distance + directionPenalty;
        candidates.add(BoardingCandidate(
          point: result.closestPoint,
          index: i,
          actualDistance: result.distance,
          effectiveDistance: effectiveDist,
          type: 'segment',
        ));
      }
    }

    if (candidates.isEmpty) return null;

    // Sort by effective distance
    candidates.sort((a, b) => a.effectiveDistance.compareTo(b.effectiveDistance));
    return candidates.first;
  }

  // Point to segment distance calculation
  ({double distance, LatLng closestPoint}) _pointToSegmentDistance(
    LatLng point,
    LatLng segStart,
    LatLng segEnd,
  ) {
    final px = point.longitude;
    final py = point.latitude;
    final x1 = segStart.longitude;
    final y1 = segStart.latitude;
    final x2 = segEnd.longitude;
    final y2 = segEnd.latitude;

    final dx = x2 - x1;
    final dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      return (
        distance: _distance.as(LengthUnit.Meter, point, segStart),
        closestPoint: segStart,
      );
    }

    double t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy);
    t = t.clamp(0.0, 1.0);

    final closest = LatLng(y1 + t * dy, x1 + t * dx);
    final dist = _distance.as(LengthUnit.Meter, point, closest);

    return (distance: dist, closestPoint: closest);
  }

  // Calculate path distance
  double _calculatePathDistance(List<LatLng> coords) {
    if (coords.length < 2) return 0.0;
    
    double total = 0.0;
    for (int i = 0; i < coords.length - 1; i++) {
      total += _distance.as(LengthUnit.Meter, coords[i], coords[i + 1]);
    }
    return total;
  }

  // Nearest point on route
  ({LatLng point, int index, double distance}) _nearestPointOnRoute(
    List<LatLng> routeCoords,
    LatLng point,
  ) {
    double minDist = double.infinity;
    int minIdx = 0;
    LatLng minPt = routeCoords[0];

    for (int i = 0; i < routeCoords.length; i++) {
      final dist = _distance.as(LengthUnit.Meter, routeCoords[i], point);
      if (dist < minDist) {
        minDist = dist;
        minIdx = i;
        minPt = routeCoords[i];
      }
    }

    return (point: minPt, index: minIdx, distance: minDist);
  }

  // Main route evaluation with loop support
  RouteEvaluationMeta? evaluateRoute(
    List<LatLng> routeCoords,
    LatLng start,
    LatLng dest, {
    double walkBoardWeight = 1.5,
    double walkAlightWeight = 3.0,
    double jeepneyDistanceWeight = 0.5,
    double alightPriorityFactor = 5.0,
    double maxBoardDistance = 800.0,
    double maxAlightDistance = 500.0,
  }) {
    // Find all destination candidates
    final destCandidates = _findAllNearbyDestinationCandidates(
      routeCoords,
      dest,
      maxAlightDistance,
    );

    if (destCandidates.isEmpty) return null;

    RouteEvaluationMeta? bestSolution;
    double bestScore = double.infinity;

    final refBoard = _nearestPointOnRoute(routeCoords, start);

    for (final destCandidate in destCandidates) {
      final boardCandidate = _findBestBoardingPointBeforeDestination(
        routeCoords,
        start,
        destCandidate.index,
        destCandidate.point,
        maxBoardDistance,
        true,
      );

      if (boardCandidate == null) continue;

      // Calculate jeepney segment
      List<LatLng> jeepneySegment = [
        boardCandidate.point,
        ...routeCoords.sublist(
          boardCandidate.index + 1,
          destCandidate.index + 1,
        ),
        destCandidate.point,
      ];

      final jeepneyDist = _calculatePathDistance(jeepneySegment);

      // Calculate score
      final score = (boardCandidate.actualDistance * walkBoardWeight) +
          (destCandidate.distance * walkAlightWeight) +
          (jeepneyDist * jeepneyDistanceWeight) +
          (destCandidate.distance * alightPriorityFactor);

      if (score < bestScore) {
        bestScore = score;

        final closestBoard = _nearestPointOnRoute(
          routeCoords.sublist(0, destCandidate.index),
          start,
        );

        final directionAdjusted = (boardCandidate.index != closestBoard.index &&
            boardCandidate.actualDistance > closestBoard.distance + 10);

        bestSolution = RouteEvaluationMeta(
          boardPoint: boardCandidate.point,
          boardIdx: boardCandidate.index,
          boardDistM: boardCandidate.actualDistance,
          alightPoint: destCandidate.point,
          alightIdx: destCandidate.index,
          alightDistM: destCandidate.distance,
          jeepneySegment: jeepneySegment,
          jeepneyDistM: jeepneyDist,
          score: score,
          refBoardIdx: refBoard.index,
          optimized: boardCandidate.index != refBoard.index ||
              boardCandidate.point != refBoard.point,
          directionAdjusted: directionAdjusted,
          destCandidatesEvaluated: destCandidates.length,
        );
      }
    }

    return bestSolution;
  }

  // Find best route across all jeepney routes
  Future<({JeepneyRoute? route, RouteEvaluationMeta? meta})> findBestRoute(
    List<JeepneyRoute> routes,
    LatLng start,
    LatLng dest, {
    double maxBoardDistance = 800.0,
    double maxAlightDistance = 500.0,
    bool debug = false,
  }) async {
    JeepneyRoute? bestRoute;
    RouteEvaluationMeta? bestMeta;
    double bestScore = double.infinity;

    if (debug) {
      print('\n🔍 Evaluating ${routes.length} jeepney routes with loop support...\n');
    }

    for (final route in routes) {
      if (debug) {
        print('\n🔹 Route ${route.routeNumber} (${route.direction})');
        print('     Route has ${route.coordinates.length} nodes');
      }

      final meta = evaluateRoute(
        route.coordinates,
        start,
        dest,
        maxBoardDistance: maxBoardDistance,
        maxAlightDistance: maxAlightDistance,
      );

      if (meta == null) {
        if (debug) {
          final destCandidates = _findAllNearbyDestinationCandidates(
            route.coordinates,
            dest,
            maxAlightDistance,
          );
          if (destCandidates.isEmpty) {
            print('  ❌ Route ${route.routeNumber}: No destinations within ${maxAlightDistance}m');
          } else {
            print('  ❌ Route ${route.routeNumber}: Found ${destCandidates.length} dest candidates but no valid boarding points');
          }
        }
        continue;
      }

      if (debug) {
        final optMarker = meta.optimized ? '🎯 OPTIMIZED' : '○ Direct';
        final candidatesMsg = ' [${meta.destCandidatesEvaluated} dest candidates checked]';
        final directionMsg = meta.directionAdjusted ? ' 🧭 Direction-corrected' : '';
        print('  ✅ Route ${route.routeNumber} | Score=${meta.score.toStringAsFixed(1)} | $optMarker$candidatesMsg$directionMsg');
        
        if (meta.optimized) {
          print('     Reference board idx=${meta.refBoardIdx} → Optimized to idx=${meta.boardIdx}');
        }
        print('     Board idx=${meta.boardIdx} dist=${meta.boardDistM.toStringAsFixed(1)}m');
        print('     Alight idx=${meta.alightIdx} dist=${meta.alightDistM.toStringAsFixed(1)}m');
        print('     Jeepney ride distance=${meta.jeepneyDistM.toStringAsFixed(1)}m');
      }

      if (meta.score < bestScore) {
        bestScore = meta.score;
        bestRoute = route;
        bestMeta = meta;
        if (debug) {
          print('     ⭐ New best route!');
        }
      }
    }

    if (bestRoute == null) {
      if (debug) print('\n❌ No suitable route found.');
      return (route: null, meta: null);
    }

    if (debug) {
      print('\n🎯 BEST ROUTE: ${bestRoute.routeNumber} (${bestRoute.direction})');
      print('   Boarding optimization: ${bestMeta!.optimized ? "USED" : "Not needed"}');
      if (bestMeta.optimized) {
        print('   → Improved from ref idx ${bestMeta.refBoardIdx} to idx ${bestMeta.boardIdx}');
      }
      print('   Destination candidates evaluated: ${bestMeta.destCandidatesEvaluated}');
      print('   Board idx: ${bestMeta.boardIdx} | Alight idx: ${bestMeta.alightIdx}');
      print('   Board dist: ${bestMeta.boardDistM.toStringAsFixed(1)}m | Alight dist: ${bestMeta.alightDistM.toStringAsFixed(1)}m');
      print('   Jeepney dist: ${bestMeta.jeepneyDistM.toStringAsFixed(1)}m | Score: ${bestMeta.score.toStringAsFixed(1)}');
    }

    return (route: bestRoute, meta: bestMeta);
  }

  // Create boarding zone polygon
  List<LatLng>? createBoardingZonePolygon(
    List<LatLng> routeCoords,
    int centerIdx, {
    int nodesBefore = 2,
    int nodesAfter = 2,
    double bufferWidth = 30.0,
  }) {
    final startIdx = max(0, centerIdx - nodesBefore);
    final endIdx = min(routeCoords.length - 1, centerIdx + nodesAfter);
    final segment = routeCoords.sublist(startIdx, endIdx + 1);

    if (segment.length < 2) return null;

    List<LatLng> leftSide = [];
    List<LatLng> rightSide = [];

    final metersToDeg = bufferWidth / 111000; // Approx

    for (int i = 0; i < segment.length; i++) {
      final lon = segment[i].longitude;
      final lat = segment[i].latitude;

      double angle;
      if (i == 0) {
        final next = segment[i + 1];
        angle = atan2(next.latitude - lat, next.longitude - lon);
      } else if (i == segment.length - 1) {
        final prev = segment[i - 1];
        angle = atan2(lat - prev.latitude, lon - prev.longitude);
      } else {
        final prev = segment[i - 1];
        final next = segment[i + 1];
        angle = atan2(next.latitude - prev.latitude, next.longitude - prev.longitude);
      }

      final perpAngle = angle + pi / 2;
      final offsetLon = metersToDeg * cos(perpAngle) / cos(lat * pi / 180);
      final offsetLat = metersToDeg * sin(perpAngle);

      leftSide.add(LatLng(lat + offsetLat, lon + offsetLon));
      rightSide.add(LatLng(lat - offsetLat, lon - offsetLon));
    }

    return [...leftSide, ...rightSide.reversed];
  }
}
