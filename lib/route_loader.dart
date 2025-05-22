import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

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
