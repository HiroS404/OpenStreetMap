// import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_try/firebase_options.dart';
import 'package:map_try/pages/home_page.dart';
import 'package:map_try/pages/openstreetmap.dart';
import 'package:map_try/pages/vendo_profile.dart';

import 'package:map_try/widgets/search_modal.dart';
import 'package:map_try/pages/settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled:
        true, // This enables local caching (to avoid over use of freeplan firebase huhuhu)
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED, // Optional: unlimited cache
  );
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details); // prints the full stack trace
  };
  // Catch any errors outside Flutter (e.g. async, platform channels)
  runApp(const MyApp());
  // runZonedGuarded(
  //   () {
  //     runApp(const MyApp());
  //   },
  //   (error, stack) {
  //     debugPrint('❌ Caught by runZonedGuarded: $error');
  //     debugPrintStack(stackTrace: stack);
  //   },
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
                  longitude: args['longitude'],
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
  int _selectedIndex = 0;

  late final ValueNotifier<LatLng?> destinationNotifier;
  late final SearchModal _searchModal;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    destinationNotifier = ValueNotifier<LatLng?>(null);
    _searchModal = SearchModal(destinationNotifier: destinationNotifier);
    _pages = [
      HomePage(destinationNotifier: destinationNotifier),
      OpenstreetmapScreen(destinationNotifier: destinationNotifier),
      Container(), // Search bottBar
      SettingsPage(),
    ];
  }

  @override
  void dispose() {
    destinationNotifier.dispose();

    super.dispose();
  }

  // void _onItemTapped(int index) {
  //   if (index == 2) {
  //     setState(() {
  //       _isSearchOpen = true;
  //     });
  //   } else {
  //     setState(() {
  //       _isSearchOpen = false;
  //       _selectedIndex = index;
  //     });
  //   }
  // }
  void _onItemTapped(int index) {
    if (index == 2) {
      showModalBottomSheet(
        context: context,
        builder: (context) => _searchModal,
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
        children: [
          IndexedStack(index: _selectedIndex, children: _pages),
          // if (_isSearchOpen)
          //   Positioned.fill(
          //     child: Material(
          //       color: Colors.black54, // dim background
          //       child: SafeArea(
          //         child: Align(
          //           alignment: Alignment.bottomCenter,
          //           child: FractionallySizedBox(
          //             heightFactor: 0.85,
          //             child: _searchModal, // reuses same stateful widget
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
        ],
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
