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
    final points =
        _tempPoints
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pointCount = _tempPoints.length;

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
                    color: const Color(0xFF6366F1),
                  ),
                ],
              ),
            if (_tempPoints.isNotEmpty)
              MarkerLayer(
                markers:
                    _tempPoints.asMap().entries.map((entry) {
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
                          onPanUpdate:
                              _isMoveMode
                                  ? (details) {
                                    final renderBox =
                                        context.findRenderObject()
                                            as RenderBox?;
                                    if (renderBox == null) return;
                                    final localPosition = renderBox
                                        .globalToLocal(details.globalPosition);
                                    final mapPoint = Point(
                                      localPosition.dx,
                                      localPosition.dy,
                                    );
                                    final latlng = _mapController.camera
                                        .pointToLatLng(mapPoint);
                                    setState(() {
                                      _tempPoints[index] = latlng;
                                    });
                                  }
                                  : null,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(30),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.circle_rounded,
                              color:
                                  isSelected
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF6366F1),
                              size: isSelected ? 40 : 28,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
          ],
        ),

        // Top status bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.grey[900]?.withAlpha(240)
                      : Colors.white.withAlpha(240),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Route Editor',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pointCount == 0
                          ? 'Tap to add points'
                          : '$pointCount ${pointCount == 1 ? 'point' : 'points'} added',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (_isMoveMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF3B82F6),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Move Mode',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Floating toolbar above selected marker
        if (_selectedIndex != null && _toolbarPosition != null)
          Positioned(
            left: (_toolbarPosition!.dx - 80).clamp(16.0, double.infinity),
            top: (_toolbarPosition!.dy - 50).clamp(80.0, double.infinity),
            child: Material(
              borderRadius: BorderRadius.circular(10),
              elevation: 8,
              shadowColor: Colors.black.withAlpha(40),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _toolbarIconButton(
                      icon: Icons.pan_tool_rounded,
                      label: 'Move',
                      isActive: _isMoveMode,
                      onPressed: () {
                        setState(() => _isMoveMode = !_isMoveMode);
                      },
                    ),
                    const SizedBox(width: 4),
                    _toolbarIconButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: const Color(0xFFEF4444),
                      onPressed: _deleteSelectedPoint,
                    ),
                    const SizedBox(width: 4),
                    _toolbarIconButton(
                      icon: Icons.close_rounded,
                      label: 'Close',
                      color: Colors.grey[600]!,
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
          ),

        // Bottom action bar
        if (widget.isDrawing)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.grey[900]?.withAlpha(240)
                        : Colors.white.withAlpha(240),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _actionButton(
                    icon: Icons.undo_rounded,
                    label: 'Undo',
                    onPressed: _undoPoint,
                    enabled: _history.isNotEmpty,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _actionButton(
                    icon: Icons.refresh_rounded,
                    label: 'Clear',
                    onPressed: _clearPoints,
                    enabled: pointCount > 0,
                    isDark: isDark,
                  ),
                  const Spacer(),
                  _actionButton(
                    icon: Icons.check_rounded,
                    label: 'Save Route',
                    onPressed: _finishDrawing,
                    enabled: pointCount >= 2,
                    isPrimary: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _toolbarIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    bool isActive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finalColor =
        color ?? (isActive ? const Color(0xFF10B981) : const Color(0xFF6366F1));

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: finalColor, size: 20),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool enabled = true,
    bool isPrimary = false,
    required bool isDark,
  }) {
    return Expanded(
      child: Material(
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color:
                  enabled
                      ? (isPrimary
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.grey[800] : Colors.grey[100]))
                      : (isDark ? Colors.grey[900] : Colors.grey[50]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    enabled
                        ? (isPrimary
                            ? const Color(0xFF10B981)
                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!))
                        : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color:
                      enabled
                          ? (isPrimary
                              ? Colors.white
                              : (isDark ? Colors.grey[300] : Colors.grey[700]))
                          : (isDark ? Colors.grey[700] : Colors.grey[400]),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        enabled
                            ? (isPrimary
                                ? Colors.white
                                : (isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[700]))
                            : (isDark ? Colors.grey[700] : Colors.grey[400]),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
