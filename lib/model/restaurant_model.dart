import 'package:cloud_firestore/cloud_firestore.dart';

class Restaurant {
  final String id; //resto id
  final String name;
  final String headerImageUrl;
  final String optionalImageUrl;
  final String? address;
  final String? description;
  final List<String>? menu;

  Restaurant({
    required this.id, //
    required this.name,
    required this.headerImageUrl,
    required this.optionalImageUrl,
    this.address,
    this.description,
    this.menu,
  });

  // Build from a Firestore document
  factory Restaurant.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Restaurant(
      id: doc.id, // ← take the Firestore document ID here
      name: data['name'] ?? '',
      headerImageUrl: data['headerImageUrl'] ?? '',
      address: data['address'],
      description: data['description'],
      menu: (data['menu'] as List?)?.cast<String>(),
      optionalImageUrl: data['optionalImageUrl'] ?? '',
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
    };
  }
}
