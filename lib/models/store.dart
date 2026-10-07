import 'package:cloud_firestore/cloud_firestore.dart';

class Store {
  final String id;
  final String name;
  final String category;
  final double lat;
  final double lng;

  const Store({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
  });

  /// Builds a Store from a Firestore document.
  /// Expected fields: name (String), category (String), location (GeoPoint).
  factory Store.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final GeoPoint point = data['location'] as GeoPoint;
    return Store(
      id: doc.id,
      name: (data['name'] ?? 'Unnamed store') as String,
      category: (data['category'] ?? 'General') as String,
      lat: point.latitude,
      lng: point.longitude,
    );
  }
}
