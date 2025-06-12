import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

class JeepneyRoute {
  final String routeNumber;
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
      routeNumber: json['route_number'].toString(),
      direction: json['direction'],
      coordinates: coordinatesList,
    );
  }
  double minDistanceToPoint(LatLng point) {
    final Distance distance = Distance();
    double minDist = double.infinity;
    for (final coord in coordinates) {
      double dist = distance.as(LengthUnit.Meter, point, coord);
      if (dist < minDist) {
        minDist = dist;
      }
    }
    return minDist;
  }
}

Future<List<JeepneyRoute>> loadRoutesFromJson() async {
  final String data = await rootBundle.loadString('Assets/jeepney_routes.json');
  final jsonResult = json.decode(data);

  List<JeepneyRoute> routes =
      (jsonResult['routes'] as List)
          .map((routeJson) => JeepneyRoute.fromJson(routeJson))
          .toList();

  return routes;
}

extension JeepneyRouteExtension on JeepneyRoute {
  bool isPointNearRoute(LatLng point, double thresholdInMeters) {
    final Distance distance = Distance();
    for (LatLng coord in coordinates) {
      if (distance.as(LengthUnit.Meter, point, coord) <= thresholdInMeters) {
        return true;
      }
    }
    return false;
  }
}
