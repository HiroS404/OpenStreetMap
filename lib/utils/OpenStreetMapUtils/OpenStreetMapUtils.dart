// All the configuration related to OpenStreetMap.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'package:flutter_map/flutter_map.dart';
import 'package:map_try/model/route_loader.dart';

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
  print("🎯 Finding best route...");
  List<MultiRouteResult> allOptions = [];

  // ALWAYS try single route options first with more lenient parameters
  final singleOptions = findSingleRouteOptions(start, destination, allRoutes);
  print("Found ${singleOptions.length} single route options");

  if (singleOptions.isNotEmpty) {
    // Check if any single route has reasonable walking distance
    final reasonableSingleRoutes =
        singleOptions.where((option) {
          return option.totalWalkDistance <=
              1500; // Allow up to 1.5km walking for single route
        }).toList();

    if (reasonableSingleRoutes.isNotEmpty) {
      print("✅ Found reasonable single routes, strongly preferring these");

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
        print(
          "⚠️ Single routes require significant walking, checking 2-route options",
        );
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
      print(
        "❌ Single routes require excessive walking, checking multi-route options",
      );
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
    print("❌ No single routes found, checking multi-route options");
    final multiOptions = findMultiRouteOptions(
      start,
      destination,
      allRoutes,
      transferSpots,
    );
    allOptions.addAll(multiOptions);
  }

  if (allOptions.isEmpty) {
    print("❌ No route options found at all");
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
  print(
    "🏆 Best route selected: ${best.tripCount} trip(s), "
    "routes: ${best.routeNumbers}, "
    "walk: ${best.totalWalkDistance.toInt()}m, cost: ${best.totalCost.toInt()}",
  );

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

  print("   🔍 Transfer validation:");
  print("      Direct distance: ${directDistance.toInt()}m");
  print("      Via transfer: ${viaTransferDistance.toInt()}m");
  print("      Walking distance: ${option.totalWalkDistance.toInt()}m");
  print(
    "      Detour ratio: ${(viaTransferDistance / directDistance).toStringAsFixed(2)}",
  );

  // More lenient validation - allow up to 2x detour and 1.5km walking
  final isValidDetour = viaTransferDistance <= directDistance * 2.0;
  final isValidWalking = option.totalWalkDistance <= 1500;

  print("      Valid detour: $isValidDetour, Valid walking: $isValidWalking");

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

  print("      ✅ Transfer evaluation:");
  print("         Route ${route1.routeNumber} → ${route2.routeNumber}");
  print("         Walk: ${totalWalk.toInt()}m, Ride: ${totalRide.toInt()}m");
  print(
    "         Penalty: ${transferPenalty.toInt()}, Total cost: ${totalCost.toInt()}",
  );

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
  print("🔍 Finding 2-route transfer options only...");
  List<MultiRouteResult> options = [];

  // For each transfer spot, find ONLY direct 2-route combinations
  for (final spot in transferSpots) {
    print("Checking transfer spot: ${spot.name}");

    final availableRoutes =
        allRoutes
            .where((route) => spot.routes.contains(route.routeNumber))
            .toList();

    if (availableRoutes.length < 2) {
      print("   ❌ Not enough routes at ${spot.name}");
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
        print(
          "   ✅ Route ${route.routeNumber} can reach ${spot.name} from start",
        );
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
        print(
          "   ✅ Route ${route.routeNumber} can reach destination from ${spot.name}",
        );
      }
    }

    print(
      "   First leg routes: ${firstLegRoutes.map((r) => r.routeNumber).toList()}",
    );
    print(
      "   Second leg routes: ${secondLegRoutes.map((r) => r.routeNumber).toList()}",
    );

    // Try combinations - but limit to reasonable options
    for (final route1 in firstLegRoutes) {
      for (final route2 in secondLegRoutes) {
        if (route1.routeNumber == route2.routeNumber) continue;

        print(
          "   🔄 Evaluating: Route ${route1.routeNumber} → Route ${route2.routeNumber}",
        );

        final option = evaluateTransferOption(
          start,
          destination,
          route1,
          route2,
          spot,
        );

        if (option != null) {
          print(
            "   ✅ Valid 2-route option: ${route1.routeNumber} → ${route2.routeNumber} via ${spot.name}",
          );
          print("      Total walk: ${option.totalWalkDistance.toInt()}m");
          print("      Total cost: ${option.totalCost.toInt()}");
          options.add(option);
        }
      }
    }
  }

  // Sort by cost and keep only the best 3 options to avoid overcomplicated routes
  options.sort((a, b) => a.totalCost.compareTo(b.totalCost));
  if (options.length > 3) {
    options = options.take(3).toList();
  }

  print("🎯 Final valid 2-route options: ${options.length}");
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

      print("   Single route option: Route ${route.routeNumber}");
      print("      Walk: ${totalWalk.toInt()}m, Cost: ${adjustedCost.toInt()}");

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

  print("📍 Found ${options.length} single route options");
  return options;
}
