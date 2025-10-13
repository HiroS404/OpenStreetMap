import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web/web.dart' as web;

class FirestoreRoutesSyncWeb extends StatefulWidget {
  const FirestoreRoutesSyncWeb({super.key});

  @override
  State<FirestoreRoutesSyncWeb> createState() => _FirestoreRoutesSyncWebState();
}

class _FirestoreRoutesSyncWebState extends State<FirestoreRoutesSyncWeb> {
  bool _isSyncing = false;
  String _status = "Preparing sync...";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncRoutes();
    });
  }

  /// 🔧 Recursively convert Firestore Timestamps → Strings
  dynamic _convertTimestamps(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k, _convertTimestamps(v)));
    } else if (value is List) {
      return value.map(_convertTimestamps).toList();
    } else {
      return value;
    }
  }

  Future<void> _syncRoutes() async {
    setState(() {
      _isSyncing = true;
      _status = "📂 Reading local JSON...";
    });

    try {
      // Step 1: Load local JSON
      final jsonString = await rootBundle.loadString('assets/jeepney_routes.json');
      final Map<String, dynamic> localJson =
      Map<String, dynamic>.from(json.decode(jsonString));
      final List<Map<String, dynamic>> localRoutes =
      List<Map<String, dynamic>>.from(localJson["routes"]);

      setState(() => _status = "☁️ Fetching Firestore data...");

      // Step 2: Fetch Firestore routes
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('routes').get();
      final List<Map<String, dynamic>> firestoreRoutes = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(_convertTimestamps(doc.data()));
        data["id"] = doc.id;
        return data;
      }).toList();

      // Step 3: Detect missing routes
      final firestoreNames = firestoreRoutes.map((r) => r["name"]).whereType<String>().toSet();
      final missingRoutes = localRoutes.where((r) {
        final name = r["name"];
        return name != null && !firestoreNames.contains(name);
      }).toList();

      print("🔥 Found ${missingRoutes.length} missing routes.");

      if (missingRoutes.isNotEmpty) {
        setState(() => _status = "⬆️ Uploading ${missingRoutes.length} missing routes...");

        for (final route in missingRoutes) {
          try {
            // Ensure clean Map<String, dynamic>
            final cleanRoute = jsonDecode(jsonEncode(route)) as Map<String, dynamic>;
            await firestore.collection('routes').add(cleanRoute);
            print("✅ Uploaded route: ${route['name']}");
            await Future.delayed(const Duration(milliseconds: 100));
          } catch (e) {
            print("⚠️ Failed to upload route ${route['name']}: $e");
          }
        }
      } else {
        print("✅ No missing routes to upload.");
      }

      // Step 4: Merge + download JSON
      final mergedJson = jsonEncode({
        "local_routes": localRoutes,
        "firestore_routes": firestoreRoutes,
        "uploaded_count": missingRoutes.length,
      });

      final bytes = utf8.encode(mergedJson);
      final blob = web.Blob(
        [Uint8List.fromList(bytes)] as JSArray<web.BlobPart>,
        web.BlobPropertyBag(type: 'application/json'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = "routes_backup.json";
      anchor.click();
      web.URL.revokeObjectURL(url);

      setState(() {
        _isSyncing = false;
        _status = "✅ Sync complete! Uploaded ${missingRoutes.length} new routes.";
      });
    } catch (e, stack) {
      print("❌ Error during sync: $e\n$stack");
      setState(() {
        _isSyncing = false;
        _status = "❌ Error: $e";
      });
    }
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text("Sync Firestore Routes to JSON")),
      body: Center(
        child: _isSyncing
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _syncRoutes,
              icon: const Icon(Icons.sync),
              label: const Text("Sync Again"),
            ),
          ],
        ),
      ),
    );
  }
}
