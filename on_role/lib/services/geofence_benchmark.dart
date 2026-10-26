import '../models/venue.dart';
import 'check_in_tracker.dart';
import 'geofence_engine.dart';
import 'synthetic_trajectories.dart';

/// Um check-in do começo ao fim.
class CheckInSession {
  const CheckInSession({required this.venueId, required this.start, required this.end});

  final String venueId;
  final DateTime start;
  final DateTime end;
}

/// Monta as sessões a partir das mudanças de check-in, em ordem.
List<CheckInSession> sessionsFrom(Iterable<CheckInChange> changes, {required DateTime closeAt}) {
  final sessions = <CheckInSession>[];
  CheckInChange? open;
  for (final change in changes) {
    if (change.checkedIn) {
      open = change;
    } else if (open != null) {
      sessions.add(CheckInSession(venueId: open.venueId, start: open.at, end: change.at));
      open = null;
    }
  }
  if (open != null) sessions.add(CheckInSession(venueId: open.venueId, start: open.at, end: closeAt));
  return sessions;
}

/// Comparação dos check-ins do app com o gabarito de trajetos sintéticos.
///
/// - Uma visita é **detectada** se houve check-in no mesmo local entre 5 min
///   antes da chegada e a saída. O primeiro check-in que serve é o dela.
/// - O check-out está **no tempo** se aconteceu entre 1 min antes e 10 min
///   depois da saída real.
/// - Outro check-in no mesmo local durante a visita é uma **fragmentação**
///   (o app fez check-out e check-in de novo sem a pessoa sair).
/// - Os demais check-ins são **falsos**: em local **vizinho** se a pessoa
///   estava visitando outro local naquela hora, ou de **passagem** se não.
///
/// "Transições corretas" é a meta do projeto (> 95%): entradas e saídas
/// certas sobre as esperadas (duas por visita) mais as erradas (duas por
/// check-in falso ou fragmentado).
class GeofenceScore {
  int nights = 0;
  int visits = 0;
  int passBys = 0;
  int shortStops = 0;
  int detected = 0;
  int checkOutsOnTime = 0;
  int fragments = 0;
  int falseNeighbor = 0;
  int falsePassing = 0;
  int sessions = 0;

  /// Atrasos em segundos (o check-in inclui a permanência mínima).
  final List<double> checkInDelays = [];
  final List<double> checkOutDelays = [];

  int get missed => visits - detected;
  int get falseCheckIns => falseNeighbor + falsePassing;

  double get recall => visits == 0 ? 0 : detected / visits;
  double get precision => sessions == 0 ? 0 : detected / sessions;

  double get transitionAccuracy {
    final total = 2 * visits + 2 * (falseCheckIns + fragments);
    return total == 0 ? 0 : (detected + checkOutsOnTime) / total;
  }

  void addNight(SyntheticNight night, List<CheckInSession> found) {
    nights++;
    visits += night.visits.length;
    passBys += night.passBys;
    shortStops += night.shortStops;
    sessions += found.length;

    final used = <CheckInSession>{};
    for (final visit in night.visits) {
      bool sameVenue(CheckInSession s) => s.venueId == visit.venueId && !used.contains(s);
      final candidates = found
          .where(sameVenue)
          .where((s) =>
              !s.start.isBefore(visit.arrivedAt.subtract(const Duration(minutes: 5))) &&
              !s.start.isAfter(visit.leftAt))
          .toList();
      if (candidates.isEmpty) continue;

      final match = candidates.first;
      used.add(match);
      detected++;
      checkInDelays.add(match.start.difference(visit.arrivedAt).inMilliseconds / 1000);
      final outDelay = match.end.difference(visit.leftAt);
      if (outDelay >= const Duration(minutes: -1) && outDelay <= const Duration(minutes: 10)) {
        checkOutsOnTime++;
        checkOutDelays.add(outDelay.inMilliseconds / 1000);
      }
      for (final extra in candidates.skip(1)) {
        used.add(extra);
        fragments++;
      }
    }

    for (final session in found) {
      if (used.contains(session)) continue;
      final duringVisit = night.visits.any(
        (visit) => session.start.isAfter(visit.arrivedAt) && session.start.isBefore(visit.leftAt),
      );
      duringVisit ? falseNeighbor++ : falsePassing++;
    }
  }
}

/// Mediana e percentil 90 (null se a lista está vazia).
({double median, double p90})? percentiles(List<double> values) {
  if (values.isEmpty) return null;
  final sorted = List.of(values)..sort();
  double at(double q) => sorted[((sorted.length * q).ceil() - 1).clamp(0, sorted.length - 1)];
  return (median: at(0.5), p90: at(0.9));
}

/// Passa uma noite sintética pelo mesmo [CheckInTracker] do app, no tempo
/// simulado: as leituras na hora delas e um tick a cada 3 s, como o
/// PresenceProvider faz. Roda centenas de noites em segundos.
List<CheckInSession> replayNight(SyntheticNight night, {required List<Venue> venues, required GeofenceConfig config}) {
  final tracker = CheckInTracker(
    GeofenceEngine(
      fences: [
        for (final venue in venues) Geofence(id: venue.id, center: venue.location, radiusMeters: venue.radiusMeters),
      ],
      config: config,
    ),
  );
  final changes = <CheckInChange>[];
  var next = 0;
  for (var time = night.start; !time.isAfter(night.end); time = time.add(const Duration(seconds: 3))) {
    while (next < night.fixes.length && !night.fixes[next].timestamp.isAfter(time)) {
      changes.addAll(tracker.process(night.fixes[next++]).changes);
    }
    changes.addAll(tracker.tick(time).changes);
  }
  return sessionsFrom(changes, closeAt: night.end);
}

/// Resultado da bancada de precisão (H2).
class GeofenceReport {
  const GeofenceReport({required this.seed, required this.config, required this.noise, required this.score});

  final int seed;
  final GeofenceConfig config;
  final GpsNoiseModel noise;
  final GeofenceScore score;

  static GeofenceReport run({
    required List<Venue> venues,
    int nights = 200,
    int seed = 1,
    GeofenceConfig config = const GeofenceConfig(),
    GpsNoiseModel noise = const GpsNoiseModel(),
  }) {
    final generator = TrajectoryGenerator(venues: venues, seed: seed, noise: noise);
    final score = GeofenceScore();
    for (var i = 0; i < nights; i++) {
      final night = generator.night();
      score.addNight(night, replayNight(night, venues: venues, config: config));
    }
    return GeofenceReport(seed: seed, config: config, noise: noise, score: score);
  }

  /// Tabela pronta para o capítulo de resultados.
  String toMarkdown() {
    final s = score;
    String pct(double value) => '${(value * 100).toStringAsFixed(1)}%';
    String secs(({double median, double p90})? p) =>
        p == null ? '-' : '${p.median.round()} s (p90 ${p.p90.round()} s)';
    return [
      '### Precisão das geocercas com trajetos sintéticos (H2)',
      '',
      '${s.nights} noites sintéticas (semente $seed), ${s.visits} visitas, '
          '${s.passBys} passagens sem parar e ${s.shortStops} paradas curtas na porta.',
      'Geocerca: permanência ${config.dwellTime.inSeconds} s, saída ${config.exitDelay.inSeconds} s, '
          'histerese ${config.exitHysteresisMeters.round()} m, precisão máxima ${config.maxAccuracyMeters.round()} m.',
      'GPS: precisão mediana ${noise.outdoorAccuracyMeters.round()} m na rua e '
          '${noise.indoorAccuracyMeters.round()} m dentro dos locais, ${pct(noise.outlierChance)} de leituras fora.',
      '',
      '| Métrica | Valor |',
      '| --- | --- |',
      '| Transições corretas (meta > 95%) | ${pct(s.transitionAccuracy)} |',
      '| Visitas detectadas (sensibilidade) | ${s.detected} de ${s.visits} (${pct(s.recall)}) |',
      '| Check-ins certos (precisão) | ${s.detected} de ${s.sessions} (${pct(s.precision)}) |',
      '| Check-outs no tempo | ${s.checkOutsOnTime} de ${s.detected} |',
      '| Check-ins falsos em local vizinho | ${s.falseNeighbor} |',
      '| Check-ins falsos de passagem | ${s.falsePassing} |',
      '| Fragmentações (saiu e voltou sem sair) | ${s.fragments} |',
      '| Atraso do check-in (mediana) | ${secs(percentiles(s.checkInDelays))} |',
      '| Atraso do check-out (mediana) | ${secs(percentiles(s.checkOutDelays))} |',
    ].join('\n');
  }
}
