import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:map_try/admin/models/jeepney_route.dart';

class RouteService {
  final CollectionReference _routesRef = FirebaseFirestore.instance.collection(
    'routes',
  );

  /// Get all routes as a stream
  Stream<List<JeepneyRoute>> getRoutes() {
    return _routesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return JeepneyRoute.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  /// Add a new route
  Future<void> addRoute(JeepneyRoute route) async {
    await _routesRef.add(route.toMap());
  }

  /// Update an existing route
  Future<void> updateRoute(JeepneyRoute route) async {
    await _routesRef.doc(route.id).update(route.toMap());
  }

  /// Delete a route
  Future<void> deleteRoute(String id) async {
    await _routesRef.doc(id).delete();
  }

  /// Get a single route by ID
  Future<JeepneyRoute?> getRouteById(String id) async {
    final doc = await _routesRef.doc(id).get();
    if (!doc.exists) return null;
    return JeepneyRoute.fromFirestore(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }
}
