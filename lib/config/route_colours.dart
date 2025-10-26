import 'package:flutter/material.dart';

class RouteColors {
  // Define colors for each route number
  static final Map<dynamic, Color> _routeColorMap = {
    1: const Color(0xFF226C0A),
    2: const Color(0xFFfb0406),
    3: const Color(0xFF08046e),
    4: const Color(0xFF4e0681),
    5: const Color(0xFFa5ad0a),
    6: const Color(0xFF387aed),
    7: const Color(0xFF1642a0),
    8: const Color(0xFF40a552),
    9: const Color(0xFFfd4204),
    10: const Color(0xFFd56844),
    11: const Color(0xFF323230),
    12: const Color(0xFF5bae41),
    13: const Color(0xFF66a5cd),
    14: const Color(0xFF5a3408),
    15: const Color(0xFFfbc12c),
    16: const Color(0xFF040232),
    17: const Color(0xFF062004),
    18: const Color(0xFFa85315),
    19: const Color(0xFFa90f84),
    20: const Color(0xFF72c5c3),
    21: const Color(0xFFc57216),
    22: const Color(0xFF7cbd74),
    23: const Color(0xFF19a5c5),
    24: const Color(0xFFb95e32),
    25: const Color(0xFFf7a51e),
  };

  // Default color if route number not found
  static const Color _defaultColor = Color(0xFFFF8F00); // Orange

  /// Get color for a specific route number
  static Color getColorForRoute(dynamic routeNumber) {
    return _routeColorMap[routeNumber] ?? _defaultColor;
  }

  /// Get a slightly transparent version of the route color
  static Color getColorForRouteWithOpacity(
    dynamic routeNumber,
    double opacity,
  ) {
    final color = getColorForRoute(routeNumber);
    return color.withAlpha((opacity * 255).toInt());
  }

  /// Generate a random color for routes not in the map (optional)
  static Color generateColorForRoute(dynamic routeNumber) {
    if (_routeColorMap.containsKey(routeNumber)) {
      return _routeColorMap[routeNumber]!;
    }

    // Generate deterministic color based on route number hash
    final hash = routeNumber.hashCode;
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.7, 0.5).toColor();
  }

  /// Get all available route colors
  static Map<dynamic, Color> getAllRouteColors() {
    return Map.unmodifiable(_routeColorMap);
  }
}
