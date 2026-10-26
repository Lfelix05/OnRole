import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/venue.dart';
import 'geo.dart';
import 'geofence_engine.dart';

/// Visita de verdade num trajeto sintético: o gabarito da bancada de testes.
class TruthVisit {
  const TruthVisit({required this.venueId, required this.arrivedAt, required this.leftAt});

  final String venueId;
  final DateTime arrivedAt;
  final DateTime leftAt;
}

/// Uma noite sintética: as leituras de GPS que o app receberia e o que de
/// fato aconteceu. Ninguém real está por trás destes dados.
class SyntheticNight {
  const SyntheticNight({
    required this.start,
    required this.end,
    required this.fixes,
    required this.visits,
    required this.passBys,
    required this.shortStops,
  });

  final DateTime start;
  final DateTime end;

  /// Leituras em ordem de tempo, já com o filtro de distância do GPS.
  final List<LocationFix> fixes;
  final List<TruthVisit> visits;

  /// Vezes em que a pessoa atravessou a cerca de um local sem parar.
  final int passBys;

  /// Paradas curtas (menos de 1,5 min) na porta de um local, sem entrar.
  final int shortStops;
}

/// Erro do GPS nas leituras sintéticas. A precisão informada segue uma
/// distribuição log-normal em torno da mediana de cada ambiente, e o erro de
/// posição é um processo AR(1): leituras seguidas erram para o mesmo lado,
/// como no GPS de verdade. No Android, a precisão é o raio com 68% de
/// confiança, então o desvio por eixo é precisão / 1,51.
class GpsNoiseModel {
  const GpsNoiseModel({
    this.outdoorAccuracyMeters = 8,
    this.indoorAccuracyMeters = 20,
    this.accuracySpread = 0.5,
    this.correlationTime = const Duration(seconds: 60),
    this.outlierChance = 0.02,
    this.fixInterval = const Duration(seconds: 10),
    this.distanceFilterMeters = 10,
  });

  /// Mediana da precisão informada na rua e dentro de um local.
  final double outdoorAccuracyMeters;
  final double indoorAccuracyMeters;

  /// Desvio-padrão do logaritmo da precisão.
  final double accuracySpread;

  /// Quanto tempo o erro leva para "esquecer" o lado para onde errava.
  final Duration correlationTime;

  /// Chance de uma leitura sair longe (reflexo em prédios), de 40 a 150 m.
  final double outlierChance;

  /// Intervalo pedido ao GPS (o mesmo do GpsLocationService).
  final Duration fixInterval;

  /// Leitura nova só depois de andar isso (o mesmo do GpsLocationService).
  final double distanceFilterMeters;
}

/// Trecho do trajeto: andar de [from] a [to] ou ficar parado (from == to).
class _Leg {
  _Leg(this.from, this.to, this.start, this.end, {required this.indoor});

  final LatLng from;
  final LatLng to;
  final DateTime start;
  final DateTime end;
  final bool indoor;

  LatLng at(DateTime time) {
    final total = end.difference(start).inMilliseconds;
    if (total <= 0) return to;
    final t = (time.difference(start).inMilliseconds / total).clamp(0.0, 1.0);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }
}

/// Gera noites sintéticas pelos locais do catálogo: a pessoa sai de um ponto
/// a 400-900 m do primeiro local, visita de 2 a 4 locais (de 10 a 90 min em
/// cada) e volta. No caminho, às vezes atravessa a cerca de outro local sem
/// parar ou para menos de 1,5 min na porta: são as situações que não podem
/// virar check-in. Em 30% das trocas, o próximo local é o vizinho mais
/// próximo (ex.: Espetinho do Denis e DJ PUB, a 44 m).
///
/// O mesmo [seed] gera sempre os mesmos trajetos, então qualquer resultado
/// da bancada pode ser refeito.
class TrajectoryGenerator {
  TrajectoryGenerator({required List<Venue> venues, int seed = 1, this.noise = const GpsNoiseModel()})
      : _venues = venues,
        _random = math.Random(seed);

  final List<Venue> _venues;
  final GpsNoiseModel noise;
  final math.Random _random;

  SyntheticNight night({DateTime? start}) {
    final t0 = start ?? DateTime(2026, 11, 6, 20);
    final legs = <_Leg>[];
    final visits = <TruthVisit>[];
    var passBys = 0;
    var shortStops = 0;
    var now = t0;
    var venue = _pick();
    var here = _around(venue.location, 400, 900);

    void stay(Duration duration, {required bool indoor}) {
      final end = now.add(duration);
      legs.add(_Leg(here, here, now, end, indoor: indoor));
      now = end;
    }

    void walkTo(LatLng target) {
      final speed = 1.0 + _random.nextDouble() * 0.5;
      final seconds = haversineDistance(here, target) / speed;
      final end = now.add(Duration(milliseconds: (seconds * 1000).round()));
      legs.add(_Leg(here, target, now, end, indoor: false));
      now = end;
      here = target;
    }

    // O GPS acabou de ligar em casa.
    stay(const Duration(minutes: 2), indoor: true);

    final stops = 2 + _random.nextInt(3);
    for (var i = 0; i < stops; i++) {
      if (_random.nextDouble() < 0.35) {
        final via = _pick(except: venue);
        walkTo(via.location);
        passBys++;
      }
      if (_random.nextDouble() < 0.2) {
        final door = _pick(except: venue);
        walkTo(door.location);
        stay(Duration(seconds: 20 + _random.nextInt(70)), indoor: false);
        shortStops++;
      }

      // Dentro do local, a até 15 m da entrada (que é a coordenada do
      // catálogo): bares são pequenos e as cercas vizinhas ficam perto.
      walkTo(_around(venue.location, 0, math.min(venue.radiusMeters * 0.3, 15)));
      final arrivedAt = now;
      stay(Duration(minutes: 10 + _random.nextInt(81)), indoor: venue.category != VenueCategory.praca);
      visits.add(TruthVisit(venueId: venue.id, arrivedAt: arrivedAt, leftAt: now));

      venue = _random.nextDouble() < 0.3 ? _nearest(venue) : _pick(except: venue);
    }

    walkTo(_around(here, 400, 900));
    stay(const Duration(minutes: 5), indoor: true);

    return SyntheticNight(
      start: t0,
      end: now,
      fixes: _sample(legs),
      visits: visits,
      passBys: passBys,
      shortStops: shortStops,
    );
  }

  List<LocationFix> _sample(List<_Leg> legs) {
    final fixes = <LocationFix>[];
    final end = legs.last.end;
    final intervalMs = noise.fixInterval.inMilliseconds;
    var time = legs.first.start;
    var legIndex = 0;
    var errorEast = 0.0;
    var errorNorth = 0.0;
    DateTime? previous;
    LatLng? lastEmitted;

    while (time.isBefore(end)) {
      while (legs[legIndex].end.isBefore(time)) {
        legIndex++;
      }
      final leg = legs[legIndex];
      final median = leg.indoor ? noise.indoorAccuracyMeters : noise.outdoorAccuracyMeters;
      var accuracy = median * math.exp(noise.accuracySpread * _gaussian());
      final sigma = accuracy / 1.51;

      final dt = previous == null ? double.infinity : time.difference(previous).inMilliseconds / 1000;
      final rho = math.exp(-dt / noise.correlationTime.inSeconds);
      final keep = math.sqrt(1 - rho * rho);
      errorEast = rho * errorEast + keep * sigma * _gaussian();
      errorNorth = rho * errorNorth + keep * sigma * _gaussian();
      previous = time;

      var east = errorEast;
      var north = errorNorth;
      if (_random.nextDouble() < noise.outlierChance) {
        final jump = 40 + _random.nextDouble() * 110;
        final bearing = _random.nextDouble() * 2 * math.pi;
        east += jump * math.sin(bearing);
        north += jump * math.cos(bearing);
        accuracy = 30 + _random.nextDouble() * 90;
      }

      final reported = _offset(leg.at(time), east: east, north: north);
      if (lastEmitted == null || haversineDistance(reported, lastEmitted) >= noise.distanceFilterMeters) {
        fixes.add(LocationFix(position: reported, accuracyMeters: accuracy, timestamp: time, isMocked: true));
        lastEmitted = reported;
      }
      // O Android não entrega as leituras em intervalos exatos.
      time = time.add(Duration(milliseconds: intervalMs - 2000 + _random.nextInt(4001)));
    }
    return fixes;
  }

  Venue _pick({Venue? except}) {
    while (true) {
      final venue = _venues[_random.nextInt(_venues.length)];
      if (venue != except) return venue;
    }
  }

  Venue _nearest(Venue from) {
    Venue? nearest;
    var nearestDistance = double.infinity;
    for (final venue in _venues) {
      if (venue == from) continue;
      final distance = haversineDistance(venue.location, from.location);
      if (distance < nearestDistance) {
        nearest = venue;
        nearestDistance = distance;
      }
    }
    return nearest!;
  }

  LatLng _around(LatLng center, double minMeters, double maxMeters) {
    final distance = minMeters + _random.nextDouble() * (maxMeters - minMeters);
    final bearing = _random.nextDouble() * 2 * math.pi;
    return _offset(center, east: distance * math.sin(bearing), north: distance * math.cos(bearing));
  }

  /// Normal padrão (Box-Muller).
  double _gaussian() {
    final u = 1 - _random.nextDouble();
    final v = _random.nextDouble();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }

  static LatLng _offset(LatLng from, {required double east, required double north}) {
    const metersPerDegree = 111320.0;
    return LatLng(
      from.latitude + north / metersPerDegree,
      from.longitude + east / (metersPerDegree * math.cos(from.latitude * math.pi / 180)),
    );
  }
}
