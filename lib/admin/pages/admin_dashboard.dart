import 'package:flutter/material.dart';
import 'package:map_try/admin/admin_services/route_services.dart';
import 'package:map_try/admin/admin_widgets/route_editor.dart';
import 'package:map_try/admin/models/jeepney_route.dart' as admin_models;
import 'package:map_try/admin/models/jeepney_route.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final RouteService _routeServices = RouteService();
  final TextEditingController _routeNumCtrl = TextEditingController();
  final TextEditingController _directionCtrl = TextEditingController();

  String? _editingRouteId;
  List<RoutePoint> _editingPoints = [];
  bool _isDrawing = false;

  void _startNewRoute() {
    setState(() {
      _editingRouteId = null;
      _editingPoints = [];
      _routeNumCtrl.clear();
      _directionCtrl.clear();
      _isDrawing = true;
    });
  }

  void _loadForEdit(admin_models.JeepneyRoute route) {
    setState(() {
      _editingRouteId = route.id;
      _editingPoints = route.coordinates;
      _routeNumCtrl.text = route.routeNumber.toString();
      _directionCtrl.text = route.direction;
      _isDrawing = true;
    });
  }

  Future<void> _saveRoute(List<RoutePoint> points) async {
    if (points.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Need at least 2 points')));
      return;
    }

    final route = admin_models.JeepneyRoute(
      id: _editingRouteId ?? '',
      routeNumber: int.tryParse(_routeNumCtrl.text.trim()) ?? 0,
      direction: _directionCtrl.text.trim(),
      coordinates: points,
    );

    if (_editingRouteId == null) {
      await _routeServices.addRoute(route);
    } else {
      await _routeServices.updateRoute(route);
    }

    setState(() {
      _isDrawing = false;
      _editingRouteId = null;
      _editingPoints = [];
      _routeNumCtrl.clear();
      _directionCtrl.clear();
    });
  }

  Future<void> _deleteRoute(String routeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Delete Route"),
            content: const Text("Are you sure you want to delete this route?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Delete"),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await _routeServices.deleteRoute(routeId);
    }
  }

  //admin edit map screen
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin (Route Editor)'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _startNewRoute),
        ],
      ),
      body: Row(
        children: [ 
          // Sidebar
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form fields
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _routeNumCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Route Number',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _directionCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Direction',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _startNewRoute,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Route'),
                                ),
                              ),
                              if (_isDrawing) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _isDrawing = false;
                                        _editingPoints = [];
                                        _editingRouteId = null;
                                      });
                                    },
                                    icon: const Icon(Icons.cancel),
                                    label: const Text('Cancel'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Routes List
                  Expanded(
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: StreamBuilder<List<admin_models.JeepneyRoute>>(
                          stream: _routeServices.getRoutes(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Center(
                                child: Text("No routes found"),
                              );
                            }

                            // ✅ Copy and sort routes by routeNumber
                            final routes = List<admin_models.JeepneyRoute>.from(
                              snapshot.data!,
                            )..sort(
                              (a, b) => a.routeNumber.compareTo(b.routeNumber),
                            );

                            return ListView.builder(
                              itemCount: routes.length,
                              itemBuilder: (context, index) {
                                final route = routes[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 4,
                                  ),
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    title: Text(
                                      'Route ${route.routeNumber}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(route.direction),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () => _loadForEdit(route),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed:
                                              () => _deleteRoute(route.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main editor area (map)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.hardEdge,
                child: RouteEditor(
                  isDrawing: _isDrawing,
                  initialPoints: _editingPoints,
                  onSave: _saveRoute,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
