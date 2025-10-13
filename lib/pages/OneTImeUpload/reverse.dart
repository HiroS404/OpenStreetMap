import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_firestore/cloud_firestore.dart';

class OneTimeUploadPage extends StatefulWidget {
  const OneTimeUploadPage({super.key});

  @override
  State<OneTimeUploadPage> createState() => _OneTimeUploadPageState();
}

class _OneTimeUploadPageState extends State<OneTimeUploadPage> {
  bool _isUploading = false;
  String _status = "Ready to upload local routes to Firestore...";

  Future<void> _uploadRoutes() async {
    setState(() {
      _isUploading = true;
      _status = "📂 Reading local JSON...";
    });

    try {
      // Step 1: Load local JSON
      final jsonString = await rootBundle.loadString('assets/jeepney_routes.json');
      final Map<String, dynamic> localJson = json.decode(jsonString);
      final List<dynamic> routes = localJson["routes"];

      setState(() => _status = "☁️ Uploading ${routes.length} routes to Firestore...");

      final firestore = FirebaseFirestore.instance;

      int uploadedCount = 0;

      // Step 2: Loop and upload
      for (var route in routes) {
        // Ensure clean map for Firestore
        final cleanRoute = Map<String, dynamic>.from(route);

        // Optional: add timestamps
        cleanRoute["created_at"] = FieldValue.serverTimestamp();
        cleanRoute["updated_at"] = FieldValue.serverTimestamp();

        await firestore.collection("routes").add(cleanRoute);
        uploadedCount++;

        print("✅ Uploaded route ${cleanRoute['route_number'] ?? uploadedCount}");
        await Future.delayed(const Duration(milliseconds: 100)); // prevent write throttle
      }

      setState(() {
        _isUploading = false;
        _status = "✅ Upload complete! Uploaded $uploadedCount routes.";
      });
    } catch (e, stack) {
      print("❌ Upload error: $e\n$stack");
      setState(() {
        _isUploading = false;
        _status = "❌ Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("One-Time Upload")),
      body: Center(
        child: _isUploading
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_status, textAlign: TextAlign.center),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _uploadRoutes,
              icon: const Icon(Icons.cloud_upload),
              label: const Text("Upload to Firestore"),
            ),
          ],
        ),
      ),
    );
  }
}
