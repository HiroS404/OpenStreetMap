import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PickAddressMapScreen extends StatefulWidget {
  const PickAddressMapScreen({super.key});

  @override
  PickAddressMapScreenState createState() => PickAddressMapScreenState();
}

class PickAddressMapScreenState extends State<PickAddressMapScreen> {
  LatLng? selectedLatLng;
  final TextEditingController searchController = TextEditingController();
  final MapController mapController = MapController();

  void _searchPlace(String query) async {
    if (query.isEmpty) return;

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=$query'
      '&format=json'
      '&limit=1'
      '&countrycodes=ph'
      '&viewbox=122.5130,10.7630,122.6145,10.6640'
      '&bounded=1',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': 'MapaKaon/1.0 (rizalbalase@gmail.com)'},
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      if (data.isNotEmpty) {
        final lat = double.parse(data[0]['lat']);
        final lon = double.parse(data[0]['lon']);

        mapController.move(LatLng(lat, lon), 16.0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No results found in Iloilo City.")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search failed: ${response.statusCode}")),
      );
    }
  }

  void _onMapTap(LatLng latlng) {
    setState(() {
      selectedLatLng = latlng;
    });
  }

  Future<void> _confirmSelection() async {
    if (selectedLatLng == null) return;

    // Build Nominatim reverse geocode URL
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=${selectedLatLng!.latitude}'
      '&lon=${selectedLatLng!.longitude}'
      '&format=json',
    );

    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'MapaKaon/1.0 (your@email.com)', // required
      },
    );

    String address = '';
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      address = data['display_name'] ?? '';
    }
    if (!mounted) return;
    Navigator.pop(context, {
      'lat': selectedLatLng!.latitude,
      'lng': selectedLatLng!.longitude,
      'address': address.isNotEmpty ? address : 'No address found',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: searchController,
          decoration: InputDecoration(hintText: "Search place..."),
          onSubmitted: _searchPlace,
        ),
      ),
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: LatLng(10.7202, 122.5621), // Default center
          initialZoom: 15.0,
          onTap: (tapPosition, latlng) => _onMapTap(latlng),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          if (selectedLatLng != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: selectedLatLng!,
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.location_pin,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
              ],
            ),
        ],
      ),

      floatingActionButton:
          selectedLatLng != null
              ? FloatingActionButton(
                onPressed: _confirmSelection,
                child: Icon(Icons.check),
              )
              : null,
    );
  }
}
