import 'dart:math' show Point;
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
  int? _selectedIndex;
  bool _isMoveMode = false;
  Offset? _toolbarPosition;

  // History for undo
  final List<List<LatLng>> _history = [];

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

  void _saveHistory() {
    _history.add(List.from(_tempPoints));
  }

  void _undoPoint() {
    if (_history.isNotEmpty) {
      setState(() {
        _tempPoints = _history.removeLast();
        _selectedIndex = null;
        _toolbarPosition = null;
      });
    }
  }

  void _onTapMap(LatLng point) {
    if (!widget.isDrawing) return;
    _saveHistory();
    setState(() {
      _tempPoints.add(point);
      _selectedIndex = null;
      _toolbarPosition = null;
    });
  }

  void _onLongPressMap(LatLng point) {
    if (_tempPoints.length < 2) return;

    double minDistance = double.infinity;
    int? insertIndex;

    final distance = Distance();

    for (int i = 0; i < _tempPoints.length - 1; i++) {
      final start = _tempPoints[i];
      final end = _tempPoints[i + 1];
      final mid = LatLng(
        (start.latitude + end.latitude) / 2,
        (start.longitude + end.longitude) / 2,
      );
      final dist = distance(point, mid);
      if (dist < minDistance) {
        minDistance = dist;
        insertIndex = i + 1;
      }
    }

    if (insertIndex != null) {
      _saveHistory();
      setState(() {
        _tempPoints.insert(insertIndex!, point);
      });
    }
  }

  void _clearPoints() {
    _saveHistory();
    setState(() {
      _tempPoints.clear();
      _selectedIndex = null;
      _toolbarPosition = null;
    });
  }

  void _finishDrawing() {
    final points = _tempPoints
        .map((p) => RoutePoint(lat: p.latitude, lng: p.longitude))
        .toList();
    widget.onSave(points);
  }

  void _deleteSelectedPoint() {
    if (_selectedIndex != null && _selectedIndex! < _tempPoints.length) {
      _saveHistory();
      setState(() {
        _tempPoints.removeAt(_selectedIndex!);
        _selectedIndex = null;
        _toolbarPosition = null;
      });
    }
  }

  void _showToolbarAboveMarker(LatLng point) {
    final center = _mapController.camera.latLngToScreenPoint(point);
    setState(() {
      _toolbarPosition = Offset(center.x.toDouble(), center.y.toDouble() - 50);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _tempPoints.isNotEmpty
                ? _tempPoints.last
                : LatLng(10.69645, 122.56902),
            initialZoom: 14,
            onTap: (tapPos, latlng) {
              _onTapMap(latlng);
              setState(() {
                _selectedIndex = null;
                _toolbarPosition = null;
                _isMoveMode = false;
              });
            },
            onLongPress: (tapPos, latlng) {
              _onLongPressMap(latlng);
            },
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
                markers: _tempPoints.asMap().entries.map((entry) {
                  final index = entry.key;
                  final point = entry.value;
                  final isSelected = _selectedIndex == index;

                  return Marker(
                    point: point,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                          _isMoveMode = false;
                        });
                        _showToolbarAboveMarker(point);
                      },
                      onPanUpdate: _isMoveMode
                          ? (details) {
                        final renderBox =
                        context.findRenderObject() as RenderBox?;
                        if (renderBox == null) return;
                        final localPosition = renderBox
                            .globalToLocal(details.globalPosition);
                        final mapPoint =
                        Point(localPosition.dx, localPosition.dy);
                        final latlng =
                        _mapController.camera.pointToLatLng(mapPoint);
                        setState(() {
                          _tempPoints[index] = latlng;
                        });
                      }
                          : null,
                      child: Icon(
                        Icons.circle_rounded,
                        color: isSelected
                            ? Colors.green
                            : Colors.deepOrangeAccent,
                        size: isSelected ? 40 : 20,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),

        // ✅ Floating toolbar above selected marker
        if (_selectedIndex != null && _toolbarPosition != null)
          Positioned(
            left: _toolbarPosition!.dx - 90,
            top: _toolbarPosition!.dy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.open_with, color: Colors.blue),
                    tooltip: "Move",
                    onPressed: () {
                      setState(() => _isMoveMode = !_isMoveMode);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: "Delete",
                    onPressed: _deleteSelectedPoint,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    tooltip: "Cancel",
                    onPressed: () {
                      setState(() {
                        _selectedIndex = null;
                        _toolbarPosition = null;
                        _isMoveMode = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

        // Drawing buttons (bottom)
        if (widget.isDrawing)
          Positioned(
            bottom: 20,
            left: 20,
            child: Row(
              children: [
                ElevatedButton(onPressed: _undoPoint, child: const Text("Undo")),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: _clearPoints, child: const Text("Clear")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _finishDrawing,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green),
                  child: const Text("Add This Route"),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
