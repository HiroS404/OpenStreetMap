// lib/services/restaurant_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:map_try/model/restaurant_model.dart';

class RestaurantService {
  static Future<List<Restaurant>> fetchRestaurants() async {
    final snap =
        await FirebaseFirestore.instance.collection('restaurants').get();
    return snap.docs.map((doc) => Restaurant.fromDoc(doc)).toList();
  }
}
