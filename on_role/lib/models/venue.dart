import 'package:latlong2/latlong.dart';

/// Um "pico": estabelecimento ou área pública monitorada pelo app. Cada local
/// tem uma geocerca circular (centro + raio) usada no check-in automático.
class Venue {
  final String id;
  final String name;
  final VenueCategory category;
  final LatLng location;

  /// Raio da geocerca em metros (o projeto prevê entre 50 e 150 m).
  final double radiusMeters;
  final String? address;

  const Venue({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.radiusMeters,
    this.address,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'],
      name: json['name'],
      category: VenueCategory.values.byName(json['category']),
      location: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      radiusMeters: (json['radiusMeters'] as num).toDouble(),
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'lat': location.latitude,
      'lng': location.longitude,
      'radiusMeters': radiusMeters,
      'address': address,
    };
  }
}

enum VenueCategory {
  bar('Bar'),
  balada('Balada'),
  evento('Eventos'),
  praca('Praça / Parque');

  const VenueCategory(this.label);

  final String label;
}
