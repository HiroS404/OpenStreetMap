import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_try/admin/models/jeepney_route.dart';

class RouteEditor extends StatefulWidget {
  final bool isDrawing;
  final List<RoutePoint> initialPoints;
  final Function(List<RoutePoint>) onSave;

  const RouteEditor({
    super.key,
    required this.isDrawing,
    required this.initialPoints,
    required this.onSave,
  });

  @override
  State<RouteEditor> createState() => _RouteEditorState();
}

class _RouteEditorState extends State<RouteEditor> {
  final MapController _mapController = MapController();
  List<LatLng> _tempPoints = [];

  @override
  void initState() {
    super.initState();
    _tempPoints =
        widget.initialPoints.map((p) => LatLng(p.lat, p.lng)).toList();
  }

  @override
  void didUpdateWidget(RouteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPoints != oldWidget.initialPoints) {
      _tempPoints =
          widget.initialPoints.map((p) => LatLng(p.lat, p.lng)).toList();
      setState(() {});
    }
  }

  void _onTapMap(LatLng point) {
    if (!widget.isDrawing) return;
    setState(() {
      _tempPoints.add(point);
    });
  }

  void _undoPoint() {
    if (_tempPoints.isNotEmpty) {
      setState(() {
        _tempPoints.removeLast();
      });
    }
  }

  void _clearPoints() {
    setState(() {
      _tempPoints.clear();
    });
  }

  void _finishDrawing() {
    final points =
        _tempPoints
            .map((p) => RoutePoint(lat: p.latitude, lng: p.longitude))
            .toList();
    widget.onSave(points);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter:
                _tempPoints.isNotEmpty
                    ? _tempPoints.last
                    : LatLng(10.69645, 122.56902),
            initialZoom: 14,
            onTap: (tapPos, latlng) => _onTapMap(latlng),
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            ),

            if (_tempPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _tempPoints,
                    strokeWidth: 4,
                    color: Colors.blue,
                  ),
                ],
              ),
            if (_tempPoints.isNotEmpty)
              MarkerLayer(
                markers:
                    _tempPoints
                        .map(
                          (p) => Marker(
                            point: p,
                            width: 24,
                            height: 24,
                            child: const Icon(
                              Icons.circle,
                              color: Colors.deepOrangeAccent,
                              size: 20,
                            ),
                          ),
                        )
                        .toList(),
              ),
          ],
        ),

        if (widget.isDrawing)
          Positioned(
            bottom: 20,
            left: 20,
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _undoPoint,
                  child: const Text("Undo"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _clearPoints,
                  child: const Text("Clear"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _finishDrawing,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                  ),
                  child: const Text("Add This Route"),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
