import 'package:flutter/material.dart';

class RouteModalController {
  final ValueNotifier<List<String>> routesNotifier = ValueNotifier([]);

  void updateRoutes(List<String> routes) {
    routesNotifier.value = routes;
  }

  void clearRoutes() {
    routesNotifier.value = [];
  }
}
