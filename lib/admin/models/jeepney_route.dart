import 'package:cloud_firestore/cloud_firestore.dart';

class RoutePoint {
  final double lat;
  final double lng;

  RoutePoint({required this.lat, required this.lng});

  Map<String, dynamic> toMap() {
    return {'lat': lat, 'lng': lng};
  }

  factory RoutePoint.fromMap(Map<String, dynamic> map) {
    return RoutePoint(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
    );
  }
}

class JeepneyRoute {
  final String id; // Firestore doc id
  final int routeNumber;
  final String direction;
  final List<RoutePoint> coordinates;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  JeepneyRoute({
    required this.id,
    required this.routeNumber,
    required this.direction,
    required this.coordinates,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'route_number': routeNumber,
      'direction': direction,
      'coordinates': coordinates.map((c) => c.toMap()).toList(),
      'created_at': createdAt ?? DateTime.now(),
      'updated_at': DateTime.now(),
    };
  }

  factory JeepneyRoute.fromFirestore(Map<String, dynamic> data, String docId) {
    return JeepneyRoute(
      id: docId,
      routeNumber: data['route_number'] ?? 0,
      direction: data['direction'] ?? '',
      coordinates:
          (data['coordinates'] as List<dynamic>)
              .map((e) => RoutePoint.fromMap(e as Map<String, dynamic>))
              .toList(),
      createdAt:
          (data['created_at'] as dynamic) != null
              ? (data['created_at'] as Timestamp).toDate()
              : null,
      updatedAt:
          (data['updated_at'] as dynamic) != null
              ? (data['updated_at'] as Timestamp).toDate()
              : null,
    );
  }
}
