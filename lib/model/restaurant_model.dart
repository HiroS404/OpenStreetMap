class Restaurant {
  final String name;
  final String description;
  final String photoUrl;
  final double latitude;
  final double longitude;
  final String? address;

  Restaurant({
    required this.name,
    required this.description,
    required this.photoUrl,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      photoUrl: json['photoUrl'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      address: json['address'] ?? '',
    );
  }
}
