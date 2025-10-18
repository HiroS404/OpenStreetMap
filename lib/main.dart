// import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_try/admin/pages/admin_routeeditor_page.dart';
import 'package:map_try/admin/pages/admin_login_page.dart';
import 'package:map_try/firebase_options.dart';
import 'package:map_try/pages/OneTImeUpload/onetimeuploadtofirebase.dart';
import 'package:map_try/pages/OneTImeUpload/reverse.dart';
import 'package:map_try/pages/home_page.dart';
import 'package:map_try/pages/openstreetmap.dart';
import 'package:map_try/pages/vendo_profile.dart';

import 'package:map_try/widgets/search_modal.dart';
import 'package:map_try/pages/settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Global controllers
final ValueNotifier<int> bottomNavIndexNotifier = ValueNotifier<int>(0);
final ValueNotifier<LatLng?> destinationNotifier = ValueNotifier<LatLng?>(null);

// Responsive breakpoints
class ResponsiveBreakpoints {
  static const double mobile = 768;
  static const double tablet = 1024;
  static const double desktop = 1200;
}

enum DeviceType { mobile, tablet, desktop }

DeviceType getDeviceType(double width) {
  if (width < ResponsiveBreakpoints.mobile) return DeviceType.mobile;
  if (width < ResponsiveBreakpoints.desktop) return DeviceType.tablet;
  return DeviceType.desktop;
}

void main() async {
  // -------------FOR ONE TIME UPLOAD
  // WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // runApp(
  //   const MaterialApp(
  //     debugShowCheckedModeBanner: false,
  //     home: OneTimeUploadPage(),
  //     home: FirestoreRoutesSyncWeb(),
  //   ),
  // );
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
  // Catch any errors outside Flutter
  runApp(const MyApp());
  // runZonedGuarded(
  //   () {
  //     runApp(const MyApp());
  //   },
  //   (error, stack) {
  //     debugPrint('⚠️ Caught by runZonedGuarded: $error');
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
        '/admin-login': (context) => const AdminLoginPage(),
        '/admin': (context) => const AdminEditor(),
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
  late final SearchModal _searchModal;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _searchModal = SearchModal(destinationNotifier: destinationNotifier);

    _pages = [
      HomePage(destinationNotifier: destinationNotifier),
      OpenstreetmapScreen(destinationNotifier: destinationNotifier),
      Container(), // search modal
      SettingsPage(),
    ];
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      showModalBottomSheet(
        context: context,
        builder: (context) => _searchModal,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    } else {
      bottomNavIndexNotifier.value = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: bottomNavIndexNotifier,
      builder: (context, selectedIndex, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final deviceType = getDeviceType(constraints.maxWidth);
            final isDesktop = deviceType == DeviceType.desktop;

            return Scaffold(
              body: IndexedStack(index: selectedIndex, children: _pages),
              // Conditionally hide bottom navigation bar on desktop
              bottomNavigationBar:
                  isDesktop
                      ? null
                      : BottomNavigationBar(
                        currentIndex: selectedIndex,
                        selectedItemColor: Colors.deepOrangeAccent,
                        unselectedItemColor: Colors.black54,
                        onTap: _onItemTapped,
                        items: const [
                          BottomNavigationBarItem(
                            icon: Icon(Icons.home),
                            label: "Home",
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.directions),
                            label: "Directions",
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.search),
                            label: "Search",
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.settings),
                            label: "Settings",
                          ),
                        ],
                      ),
            );
          },
        );
      },
    );
  }
}
