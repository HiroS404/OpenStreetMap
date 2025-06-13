import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_try/firebase_options.dart';
import 'package:map_try/pages/home_page.dart';
import 'package:map_try/pages/openstreetmap.dart';
import 'package:map_try/pages/vendo_profile.dart';

import 'package:map_try/widgets/search_modal.dart';
import 'package:map_try/pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: BottomNavBar(),

      routes: {
        '/map':
            (context) => OpenstreetmapScreen(
              destinationNotifier: ValueNotifier<LatLng?>(null),
            ),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/vendor-profile') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder:
                (context) => VendorProfileScreen(
                  name: args['name'],
                  description: args['description'],
                  photoUrl: args['photoUrl'],
                  latitude: args['latitude'],
                  longtitude: args['longitude'],
                ),
          );
        }
        return null;
      },
    );
  }
}

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  BottomNavBarState createState() => BottomNavBarState();
}

class BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 1;

  final ValueNotifier<LatLng?> destinationNotifier = ValueNotifier(null);

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(),
      OpenstreetmapScreen(destinationNotifier: destinationNotifier),
      Container(), // Search will not be visible in IndexedStack
      SettingsPage(),
    ];
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      showModalBottomSheet(
        context: context,
        builder:
            (context) => SearchModal(destinationNotifier: destinationNotifier),
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
      body: Stack(
        children: [IndexedStack(index: _selectedIndex, children: _pages)],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepOrangeAccent,
        unselectedItemColor: Colors.black54,
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
