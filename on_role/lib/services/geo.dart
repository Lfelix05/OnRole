import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Raio médio da Terra em metros (IUGG).
const double earthRadiusMeters = 6371008.8;

/// Distância em metros entre dois pontos pela fórmula de Haversine:
///
///   d = 2r · arcsin(√(sin²(Δφ/2) + cos φ1 · cos φ2 · sin²(Δλ/2)))
///
/// onde φ é a latitude e λ a longitude, em radianos.
double haversineDistance(LatLng a, LatLng b) {
  final phi1 = a.latitudeInRad;
  final phi2 = b.latitudeInRad;
  final sinHalfDeltaPhi = math.sin((phi2 - phi1) / 2);
  final sinHalfDeltaLambda = math.sin((b.longitudeInRad - a.longitudeInRad) / 2);

  final h = sinHalfDeltaPhi * sinHalfDeltaPhi +
      math.cos(phi1) * math.cos(phi2) * sinHalfDeltaLambda * sinHalfDeltaLambda;

  // min() protege contra h > 1 por erro de arredondamento em pontos antípodas.
  return 2 * earthRadiusMeters * math.asin(math.min(1.0, math.sqrt(h)));
}

/// "350 m", "1,2 km".
String formatDistance(double meters) {
  if (meters < 1000) return '${(meters / 10).round() * 10} m';
  return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}
