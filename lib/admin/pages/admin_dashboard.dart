import 'package:flutter/material.dart';
import 'package:map_try/admin/pages/admin_routeeditor_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;

  // List of page widgets
  final List<Widget> _pages = [
    const AdminEditor(), // Your existing Route Editor page
    // const RegisteredRestaurantPage(), // Placeholder for now
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Side Panel
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24.0),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 8),

                // Menu Items
                _buildMenuItem(
                  icon: Icons.route,
                  title: 'Route Editor',
                  index: 0,
                ),
                _buildMenuItem(
                  icon: Icons.restaurant,
                  title: 'Registered Restaurant',
                  index: 1,
                ),
              ],
            ),
          ),

          // Main Content Area
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isSelected ? Colors.white.withAlpha(30) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    isSelected
                        ? Colors.white.withAlpha(30)
                        : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
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

// // Placeholder page for Registered Restaurant
// class RegisteredRestaurantPage extends StatelessWidget {
//   const RegisteredRestaurantPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Registered Restaurant')),
//       body: const Center(
//         child: Text(
//           'Restaurant management coming soon...',
//           style: TextStyle(fontSize: 18, color: Colors.grey),
//         ),
//       ),
//     );
//   }
// }
