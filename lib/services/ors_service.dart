import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OrsService {
  final String apiKey;

  OrsService(this.apiKey);

  /// Requests a route from OpenRouteService
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
      print("ORS error: ${response.body}");
      return null;
    }
  }
}
