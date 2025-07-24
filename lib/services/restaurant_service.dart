// lib/services/restaurant_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:map_try/model/restaurant_model.dart';

class RestaurantService {
  static Future<List<Restaurant>> fetchRestaurants() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('restaurants')
        .get(const GetOptions(source: Source.cache)); // Prefer cached first

    if (snapshot.docs.isEmpty) {
      // If cache is empty, fallback to server
      final serverSnapshot = await FirebaseFirestore.instance
          .collection('restaurants')
          .get(const GetOptions(source: Source.serverAndCache));
      return serverSnapshot.docs
          .map((doc) => Restaurant.fromJson(doc.data()))
          .toList();
    }

    return snapshot.docs.map((doc) => Restaurant.fromJson(doc.data())).toList();
  }
}
