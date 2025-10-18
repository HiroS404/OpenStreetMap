import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map_try/admin/admin_services/resto_services.dart';

class RegisteredRestaurantPage extends StatefulWidget {
  const RegisteredRestaurantPage({super.key});

  @override
  State<RegisteredRestaurantPage> createState() =>
      _RegisteredRestaurantPageState();
}

class _RegisteredRestaurantPageState extends State<RegisteredRestaurantPage> {
  final RestaurantService _restaurantService = RestaurantService();
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy hh:mm a');

  Future<void> _deleteRestaurant(
    String restaurantId,
    String restaurantName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Restaurant'),
            content: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  const TextSpan(text: 'Are you sure you want to delete '),
                  TextSpan(
                    text: restaurantName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '?\n\nThis action cannot be undone.'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _restaurantService.deleteRestaurant(restaurantId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$restaurantName deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting restaurant: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registered Restaurants'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: StreamBuilder<List<RestaurantListModel>>(
            stream: _restaurantService.getRestaurants(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No registered restaurants yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final restaurants = snapshot.data!;

              return Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant, color: Colors.deepOrange),
                        const SizedBox(width: 8),
                        Text(
                          'Total Restaurants: ${restaurants.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Restaurant Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            'Address',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Registered Date',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            'Actions',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Table Body
                  Expanded(
                    child: ListView.builder(
                      itemCount: restaurants.length,
                      itemBuilder: (context, index) {
                        final restaurant = restaurants[index];
                        final isEven = index % 2 == 0;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isEven ? Colors.white : Colors.grey.shade50,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  restaurant.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  restaurant.address ?? 'No address',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _dateFormat.format(restaurant.registeredDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed:
                                      () => _deleteRestaurant(
                                        restaurant.id,
                                        restaurant.name,
                                      ),
                                  tooltip: 'Delete Restaurant',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
