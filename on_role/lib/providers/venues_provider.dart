import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/repositories.dart';
import '../data/venue_catalog.dart';
import '../models/venue.dart';
import '../services/kernel_density.dart';
import 'auth_provider.dart';

/// Locais do mapa e quantas pessoas há em cada um agora.
class VenuesProvider extends ChangeNotifier {
  VenuesProvider({required PresenceRepository repository, required AuthProvider auth})
      : _repository = repository,
        _auth = auth {
    _clusters = {for (final venue in venues) venue.id: _buildCluster(venue)};
    auth.addListener(_syncSession);
    _syncSession();
  }

  final PresenceRepository _repository;
  final AuthProvider _auth;
  late final Map<String, List<(LatLng, double)>> _clusters;
  StreamSubscription<Map<String, int>>? _subscription;
  Map<String, int> _crowd = const {};

  List<Venue> get venues => venueCatalog;

  Venue? venueById(String? id) => findVenue(id);

  /// Pessoas com check-in ativo no local agora.
  int crowdAt(String venueId) => _crowd[venueId] ?? 0;

  Venue? get hottestVenue {
    Venue? hottest;
    for (final venue in venues) {
      if (hottest == null || crowdAt(venue.id) > crowdAt(hottest.id)) hottest = venue;
    }
    return hottest;
  }

  /// Pontos do mapa de calor, no formato que o back-end vai entregar: a
  /// lotação de cada local distribuída em algumas células ao redor dele, sem a
  /// posição individual de ninguém.
  List<HeatPoint> get heatPoints => [
        for (final venue in venues)
          for (final (position, share) in _clusters[venue.id]!) HeatPoint(position, crowdAt(venue.id) * share),
      ];

  /// Densidade que satura a escala de cores. Acompanha o local mais cheio da
  /// cidade (e não só o que está na tela, para um bar vazio não parecer lotado
  /// quando o usuário dá zoom nele), com um piso para poucos usuários não
  /// parecerem uma multidão.
  double get heatSaturation {
    final hottest = hottestVenue;
    return math.max(10, hottest == null ? 0 : crowdAt(hottest.id) * 0.75);
  }

  /// Busca por nome ou categoria, ignorando acentos ("praca" acha "Praça").
  List<Venue> search(String query) {
    final normalized = _normalize(query.trim());
    if (normalized.isEmpty) return const [];
    return venues
        .where((venue) =>
            _normalize(venue.name).contains(normalized) || _normalize(venue.category.label).contains(normalized))
        .toList();
  }

  static String _normalize(String text) {
    const accented = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const plain = 'aaaaaeeeeiiiiooooouuuuc';
    final buffer = StringBuffer();
    for (final char in text.toLowerCase().split('')) {
      final index = accented.indexOf(char);
      buffer.write(index == -1 ? char : plain[index]);
    }
    return buffer.toString();
  }

  /// Distribui a lotação de um local em 4 células fixas ao redor do centro.
  /// A semente vem do id para a mancha não "pular" a cada atualização.
  static List<(LatLng, double)> _buildCluster(Venue venue) {
    final random = math.Random(venue.id.hashCode);
    const distance = Distance();
    const shares = [0.4, 0.25, 0.2, 0.15];
    return [
      for (final (index, share) in shares.indexed)
        (
          index == 0
              ? venue.location
              : distance.offset(
                  venue.location,
                  venue.radiusMeters * (0.15 + random.nextDouble() * 0.3),
                  random.nextDouble() * 360,
                ),
          share,
        ),
    ];
  }

  void _syncSession() {
    final loggedIn = _auth.isLoggedIn;
    if (loggedIn == (_subscription != null)) return;
    _subscription?.cancel();
    _subscription = null;
    _crowd = const {};
    // A lotação só pode ser lida por quem está logado.
    if (loggedIn) {
      _subscription = _repository.watchCrowd().listen((crowd) {
        _crowd = crowd;
        notifyListeners();
      }, onError: (Object error) => debugPrint('VenuesProvider: $error'));
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_syncSession);
    _subscription?.cancel();
    super.dispose();
  }
}
