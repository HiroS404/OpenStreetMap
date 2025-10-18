import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantListModel {
  final String id;
  final String name;
  final String? address;
  final DateTime registeredDate;

  RestaurantListModel({
    required this.id,
    required this.name,
    this.address,
    required this.registeredDate,
  });

  factory RestaurantListModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Try to get registered date, fallback to document creation time or current time
    DateTime regDate;
    if (data['registeredDate'] != null) {
      regDate = (data['registeredDate'] as Timestamp).toDate();
    } else if (data['createdAt'] != null) {
      regDate = (data['createdAt'] as Timestamp).toDate();
    } else {
      // If no date field exists, use a placeholder
      regDate = DateTime.now();
    }

    return RestaurantListModel(
      id: doc.id,
      name: data['name'] ?? 'N/A',
      address: data['address'],
      registeredDate: regDate,
    );
  }
}

class RestaurantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all registered restaurants as a stream
  Stream<List<RestaurantListModel>> getRestaurants() {
    return _firestore
        .collection('restaurants') // Your collection name
        .snapshots()
        .map((snapshot) {
          final restaurants =
              snapshot.docs
                  .map((doc) => RestaurantListModel.fromFirestore(doc))
                  .toList();

          // Sort by registered date (newest first)
          restaurants.sort(
            (a, b) => b.registeredDate.compareTo(a.registeredDate),
          );

          return restaurants;
        });
  }

  // Get restaurants as a one-time fetch
  Future<List<RestaurantListModel>> getRestaurantsOnce() async {
    final snapshot = await _firestore.collection('restaurants').get();

    final restaurants =
        snapshot.docs
            .map((doc) => RestaurantListModel.fromFirestore(doc))
            .toList();

    // Sort by registered date (newest first)
    restaurants.sort((a, b) => b.registeredDate.compareTo(a.registeredDate));

    return restaurants;
  }

  // Delete a restaurant (if needed later)
  Future<void> deleteRestaurant(String restaurantId) async {
    await _firestore.collection('restaurants').doc(restaurantId).delete();
  }

  // Get restaurant count
  Future<int> getRestaurantCount() async {
    final snapshot = await _firestore.collection('restaurants').get();
    return snapshot.docs.length;
  }
}
