import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const String ORSApiKey =
    "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImE5MGM0OTU0Nzg1ODRmNzdiZGJhZWFiYWVkYTY1ODE1IiwiaCI6Im11cm11cjY0In0=";

class OrsService {
  final String apiKey;

  OrsService(this.apiKey);

  /// Requests a route from OpenRouteService (returns only coordinates)
  Future<List<LatLng>?> getRoute(
    LatLng start,
    LatLng end, {
    String profile = "foot-walking", // "driving-car", "cycling-regular", etc
  }) async {
    final url = Uri.parse(
      "https://api.openrouteservice.org/v2/directions/$profile/geojson",
    );

    final body = jsonEncode({
      "coordinates": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude],
      ],
    });

    final response = await http.post(
      url,
      headers: {"Authorization": apiKey, "Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coords = data["features"][0]["geometry"]["coordinates"] as List;
      return coords.map((c) => LatLng(c[1], c[0])).toList();
    } else {
      print("ORS error (getRoute): ${response.statusCode} - ${response.body}");
      return null;
    }
  }

  /// Requests a route with full GeoJSON response including turn-by-turn directions
  Future<Map<String, dynamic>?> getRouteWithDirections(
    LatLng start,
    LatLng end, {
    String profile = "foot-walking",
  }) async {
    final url = Uri.parse(
      "https://api.openrouteservice.org/v2/directions/$profile/geojson",
    );

    final body = jsonEncode({
      "coordinates": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude],
      ],
      "instructions": true, // Request turn-by-turn instructions
    });

    try {
      final response = await http.post(
        url,
        headers: {
          "Authorization": apiKey,
          "Content-Type": "application/json",
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } else {
        print("ORS error (getRouteWithDirections): ${response.statusCode}");
        print("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      print("ORS exception (getRouteWithDirections): $e");
      return null;
    }
  }
}