import 'package:flutter/material.dart';
import 'package:map_try/home_page.dart';
import 'package:map_try/openstreetmap.dart';
import 'package:map_try/search_modal.dart';
import 'package:map_try/settings_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: BottomNavBar());
  }
}

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  BottomNavBarState createState() => BottomNavBarState();
}

class BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 1; // Default to map page

  final List<Widget> _pages = [
    HomePage(),
    OpenstreetmapScreen(),
    Placeholder(), // Search is a modal, not a page
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      showModalBottomSheet(
        context: context,
        builder: (context) => SearchModal(),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MAPAkaon',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white, // Slightly darker blue
        elevation: 4, // Adds a shadow effect
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16), // Smooth curved bottom
          ),
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white, // White background
        elevation: 5, // Slight shadow
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange, // Selected item color
        unselectedItemColor:
            Colors.black54, // Shaded black for unselected items
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions),
            label: "Directions",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}
