import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// ----------------- JeepneyRoute -----------------
class JeepneyRoute {
  final int routeNumber;
  final String direction;
  final List<LatLng> coordinates;

  JeepneyRoute({
    required this.routeNumber,
    required this.direction,
    required this.coordinates,
  });

  factory JeepneyRoute.fromJson(Map<String, dynamic> json) {
    var coords = json['coordinates'] as List;
    List<LatLng> coordinatesList =
        coords.map((coord) => LatLng(coord['lat'], coord['lng'])).toList();

    return JeepneyRoute(
      routeNumber: json['route_number'],
      direction: json['direction'],
      coordinates: coordinatesList,
    );
  }

  Map<String, dynamic> toJson() => {
    'route_number': routeNumber,
    'direction': direction,
    'coordinates':
        coordinates
            .map((coord) => {'lat': coord.latitude, 'lng': coord.longitude})
            .toList(),
  };
}

// ----------------- LOCAL CACHE -----------------
Future<void> saveRoutesLocally(List<JeepneyRoute> routes) async {
  var box = await Hive.openBox('routesBox');
  List<Map<String, dynamic>> jsonList = routes.map((e) => e.toJson()).toList();
  await box.put('routes', jsonList);
  await box.put('lastFetched', DateTime.now().millisecondsSinceEpoch);
}

Future<List<JeepneyRoute>> getRoutesFromLocal() async {
  var box = await Hive.openBox('routesBox');
  final List<dynamic>? stored = box.get('routes');
  if (stored == null) return [];
  return stored
      .map((e) => JeepneyRoute.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

Future<int?> getLastFetchTime() async {
  var box = await Hive.openBox('routesBox');
  return box.get('lastFetched');
}

// ----------------- FETCH ONLY NEW -----------------
Future<List<JeepneyRoute>> fetchUpdatedRoutesFromFirebase() async {
  int? lastFetch = await getLastFetchTime();
  Timestamp? lastFetchTimestamp =
      lastFetch != null
          ? Timestamp.fromMillisecondsSinceEpoch(lastFetch)
          : null;

  Query query = FirebaseFirestore.instance.collection('routes');
  if (lastFetchTimestamp != null) {
    query = query.where('lastUpdated', isGreaterThan: lastFetchTimestamp);
  }

  final snapshot = await query.get();

  if (snapshot.docs.isEmpty) return []; // nothing new

  List<JeepneyRoute> newRoutes =
      snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return JeepneyRoute.fromJson(data);
      }).toList();

  // Merge with existing local data
  List<JeepneyRoute> localData = await getRoutesFromLocal();

  // Remove outdated versions of updated routes
  Map<int, JeepneyRoute> routeMap = {
    for (var route in localData) route.routeNumber: route,
  };
  for (var route in newRoutes) {
    routeMap[route.routeNumber] = route;
  }

  List<JeepneyRoute> mergedRoutes = routeMap.values.toList();

  // Save merged data locally
  await saveRoutesLocally(mergedRoutes);

  return mergedRoutes;
}

// ----------------- CACHE STRATEGY -----------------
Future<List<JeepneyRoute>> getRoutes() async {
  List<JeepneyRoute> localData = await getRoutesFromLocal();
  print("Local data count: ${localData.length}");

  try {
    List<JeepneyRoute> updatedData = await fetchUpdatedRoutesFromFirebase();
    if (updatedData.isNotEmpty) {
      print("Fetched ${updatedData.length} new/updated routes from Firebase");
    } else {
      print("No new routes fetched from Firebase");
    }
    return await getRoutesFromLocal();
  } catch (e) {
    print("Firebase fetch failed: $e");
    return localData.isNotEmpty ? localData : await loadRoutesFromJson();
  }
}

// ----------------- BUNDLED JSON (fallback if ever crashed ang cloudd) -----------------
Future<List<JeepneyRoute>> loadRoutesFromJson() async {
  final String data = await rootBundle.loadString('assets/jeepney_routes.json');
  final jsonResult = json.decode(data);

  return (jsonResult['routes'] as List)
      .map((routeJson) => JeepneyRoute.fromJson(routeJson))
      .toList();
}
