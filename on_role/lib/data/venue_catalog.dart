import 'package:latlong2/latlong.dart';

import '../models/venue.dart';

/// Locais monitorados pelo app, no centro de Colatina - ES. As praças e a Área
/// de Eventos são espaços públicos com coordenadas do OpenStreetMap; os bares
/// são fictícios. Troque-os pelos 5 estabelecimentos parceiros do experimento,
/// medindo as coordenadas no próprio local.
const venueCatalog = <Venue>[
  Venue(
    id: 'praca-municipal',
    name: 'Praça Municipal',
    category: VenueCategory.praca,
    location: LatLng(-19.53477, -40.62870),
    radiusMeters: 80,
  ),
  Venue(
    id: 'praca-sol-poente',
    name: 'Praça do Sol Poente',
    category: VenueCategory.praca,
    location: LatLng(-19.53693, -40.63380),
    radiusMeters: 70,
  ),
  Venue(
    id: 'parque-beira-rio',
    name: 'Parque Beira-Rio',
    category: VenueCategory.praca,
    location: LatLng(-19.52543, -40.61934),
    radiusMeters: 100,
  ),
  Venue(
    id: 'area-eventos',
    name: 'Área de Eventos',
    category: VenueCategory.evento,
    location: LatLng(-19.53612, -40.63612),
    radiusMeters: 150,
  ),
  Venue(
    id: 'boteco-central',
    name: 'Boteco Central',
    category: VenueCategory.bar,
    location: LatLng(-19.53368, -40.62655),
    radiusMeters: 50,
  ),
  Venue(
    id: 'lounge-beira-rio',
    name: 'Lounge Beira-Rio',
    category: VenueCategory.balada,
    location: LatLng(-19.52626, -40.61800),
    radiusMeters: 60,
  ),
  Venue(
    id: 'esquina-do-chopp',
    name: 'Esquina do Chopp',
    category: VenueCategory.bar,
    location: LatLng(-19.53870, -40.63433),
    radiusMeters: 50,
  ),
];

/// Lotação média de cada local no modo mock (simulação de movimento).
const demoCrowdBaseline = <String, int>{
  'praca-municipal': 35,
  'praca-sol-poente': 18,
  'parque-beira-rio': 25,
  'area-eventos': 60,
  'boteco-central': 42,
  'lounge-beira-rio': 55,
  'esquina-do-chopp': 22,
};

Venue? findVenue(String? id) {
  for (final venue in venueCatalog) {
    if (venue.id == id) return venue;
  }
  return null;
}
