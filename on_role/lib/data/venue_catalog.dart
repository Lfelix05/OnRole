import 'package:latlong2/latlong.dart';

import '../models/venue.dart';

/// Locais monitorados pelo app em Colatina - ES: estabelecimentos de acesso
/// público, sem parceria nem patrocínio (o app mostra só nome, tipo e
/// localização). Coordenadas da entrada, tiradas do Google Maps.
///
/// Raio da geocerca pelo tamanho do local: pequeno 50 m, médio 75 m e grande
/// 120 m. Espetinho do Denis e DJ PUB ficam a 44 m um do outro, e o Bharem
/// fica dentro da cerca da Área Verde: nesses casos o check-in vai para o
/// local mais próximo (ver PresenceProvider e CheckInSwitcher).
const venueCatalog = <Venue>[
  Venue(
    id: 'espetinho-do-denis',
    name: 'Espetinho do Denis',
    category: VenueCategory.bar,
    location: LatLng(-19.529800, -40.661999),
    radiusMeters: 50,
  ),
  Venue(
    id: 'dj-pub',
    name: 'DJ PUB',
    category: VenueCategory.balada,
    location: LatLng(-19.530143, -40.661782),
    radiusMeters: 50,
  ),
  Venue(
    id: 'bunker-music-house',
    name: 'Bunker Music House',
    category: VenueCategory.balada,
    location: LatLng(-19.531335, -40.662015),
    radiusMeters: 75,
  ),
  Venue(
    id: 'cerimonial-zoca',
    name: 'Cerimonial Zoca',
    category: VenueCategory.evento,
    location: LatLng(-19.527753, -40.691284),
    radiusMeters: 120,
  ),
  Venue(
    id: 'bar-ladym',
    name: 'Bar Ladym',
    category: VenueCategory.bar,
    location: LatLng(-19.517611, -40.657589),
    radiusMeters: 50,
  ),
  Venue(
    id: 'caza-up',
    name: 'Caza Up!',
    category: VenueCategory.balada,
    location: LatLng(-19.518661, -40.627667),
    radiusMeters: 75,
  ),
  Venue(
    id: 'bakhanas',
    name: "BAKHANA'S",
    category: VenueCategory.bar,
    location: LatLng(-19.532566, -40.625069),
    radiusMeters: 50,
  ),
  Venue(
    id: 'bharem',
    name: 'Bharem',
    category: VenueCategory.bar,
    location: LatLng(-19.526918, -40.618781),
    radiusMeters: 50,
  ),
  Venue(
    id: 'caraiva-beach-bar',
    name: 'Caraiva Beach Bar',
    category: VenueCategory.bar,
    location: LatLng(-19.526148, -40.617526),
    radiusMeters: 50,
  ),
  Venue(
    id: 'cervejaria-divina-beer',
    name: 'Cervejaria Divina Beer',
    category: VenueCategory.bar,
    location: LatLng(-19.523238, -40.614432),
    radiusMeters: 75,
  ),
  Venue(
    id: 'area-verde',
    name: 'Área Verde',
    category: VenueCategory.praca,
    location: LatLng(-19.527569, -40.619457),
    radiusMeters: 120,
  ),
];

/// Lotação média de cada local no modo mock (simulação de movimento). Os
/// números são inventados, só para demonstração.
const demoCrowdBaseline = <String, int>{
  'espetinho-do-denis': 18,
  'dj-pub': 30,
  'bunker-music-house': 55,
  'cerimonial-zoca': 70,
  'bar-ladym': 15,
  'caza-up': 48,
  'bakhanas': 22,
  'bharem': 26,
  'caraiva-beach-bar': 20,
  'cervejaria-divina-beer': 35,
  'area-verde': 40,
};

Venue? findVenue(String? id) {
  for (final venue in venueCatalog) {
    if (venue.id == id) return venue;
  }
  return null;
}
