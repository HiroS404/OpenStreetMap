import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

Future<List<LatLng>> loadRouteFromJson() async {
  final String data = await rootBundle.loadString('Assets/route#3.json');
  final jsonResult = json.decode(data);

  final List<dynamic> coords = jsonResult['coordinates'];
  return coords.map((coord) => LatLng(coord['lat'], coord['lng'])).toList();
}
