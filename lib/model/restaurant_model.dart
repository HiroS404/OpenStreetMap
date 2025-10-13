import 'package:cloud_firestore/cloud_firestore.dart';

class Restaurant {
  final String id; //resto id
  final String name;
  final String headerImageUrl;
  final String optionalImageUrl;
  final String? address;
  final String? description;
  final List<Map<String, dynamic>> menu;
  final List<String> categories;
  final GeoPoint? location;

  Restaurant({
    required this.id, //
    required this.name,
    required this.headerImageUrl,
    required this.optionalImageUrl,
    this.address,
    this.description,
    required this.menu,
    required this.categories,
    this.location,
  });

  double? get latitude => location?.latitude;
  double? get longitude => location?.longitude;

  // Build from a Firestore document
  factory Restaurant.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Restaurant(
      id: doc.id, // ← take the Firestore document ID here
      name: data['name'] ?? '',
      headerImageUrl: data['headerImageUrl'] ?? '',
      address: data['address'],
      description: data['description'],
      menu:
          ((data['menu'] as List<dynamic>?)?.map((item) {
                    if (item is String) {
                      return {
                            "category": "Uncategorized",
                            "name": item,
                            "price": 0,
                          }
                          as Map<String, dynamic>;
                    } else if (item is Map<String, dynamic>) {
                      return Map<String, dynamic>.from(item);
                    }
                    return {} as Map<String, dynamic>;
                  }).toList() ??
                  [])
              .cast<Map<String, dynamic>>(),

      optionalImageUrl: data['optionalImageUrl'] ?? '',
      categories: (data['category'] as List?)?.cast<String>() ?? [],
      location: data['location'] as GeoPoint?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // Intentionally NOT storing 'id' in the doc body
      'name': name,
      'headerImageUrl': headerImageUrl,
      'address': address,
      'description': description,
      'menu': menu,
      'optionalImageUrl': optionalImageUrl,
      'location': location,
    };
  }
}
