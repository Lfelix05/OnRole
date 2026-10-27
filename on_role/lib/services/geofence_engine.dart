import 'package:latlong2/latlong.dart';

import 'geo.dart';

/// Cerca virtual circular em torno de um local.
class Geofence {
  const Geofence({required this.id, required this.center, required this.radiusMeters});

  final String id;
  final LatLng center;
  final double radiusMeters;
}

/// Uma leitura de posição, vinda do GPS ou do modo de simulação.
class LocationFix {
  const LocationFix({
    required this.position,
    required this.accuracyMeters,
    required this.timestamp,
    this.isMocked = false,
  });

  final LatLng position;

  /// Raio de incerteza informado pelo sistema operacional.
  final double accuracyMeters;
  final DateTime timestamp;

  /// Verdadeiro quando a posição veio de um app de "GPS falso" (Android) ou
  /// do modo de simulação.
  final bool isMocked;
}

/// Transições no mesmo modelo das APIs nativas (Android GeofencingClient):
/// [enter] ao cruzar o raio, [dwell] ao permanecer o tempo mínimo (é o que
/// confirma o check-in) e [exit] ao sair de vez.
enum GeofenceTransition { enter, dwell, exit }

class GeofenceEvent {
  const GeofenceEvent({
    required this.fenceId,
    required this.transition,
    required this.timestamp,
    required this.distanceMeters,
  });

  final String fenceId;
  final GeofenceTransition transition;

  /// Momento em que a transição foi detectada.
  final DateTime timestamp;

  /// Distância até o centro da cerca na última leitura válida.
  final double distanceMeters;

  @override
  String toString() => 'GeofenceEvent(${transition.name} $fenceId, ${distanceMeters.round()} m)';
}

class GeofenceConfig {
  /// Valores escolhidos na bancada de trajetos sintéticos (5 sementes × 500
  /// noites): 3 min de permanência com detecção de parada de 30 m levaram as
  /// transições corretas de 57% (2 min, sem parada) para 93%.
  const GeofenceConfig({
    this.dwellTime = const Duration(minutes: 3),
    this.exitDelay = const Duration(seconds: 60),
    this.exitHysteresisMeters = 25,
    this.maxAccuracyMeters = 60,
    this.stillRadiusMeters = 30,
  });

  /// Tempos curtos para demonstração com o modo de simulação. Sem detecção de
  /// parada: cada toque no mapa é uma única leitura, sem caminhada.
  static const demo = GeofenceConfig(
    dwellTime: Duration(seconds: 10),
    exitDelay: Duration(seconds: 5),
    exitHysteresisMeters: 15,
    stillRadiusMeters: null,
  );

  /// Tempo mínimo dentro da cerca para confirmar o check-in. Evita que quem
  /// só passa na calçada faça check-in.
  final Duration dwellTime;

  /// Tempo que o usuário precisa ficar fora da cerca para o check-out ser
  /// confirmado, absorvendo leituras ruins em ambientes fechados.
  final Duration exitDelay;

  /// Margem além do raio antes de considerar o usuário fora. Sem ela, o ruído
  /// do GPS na borda da cerca geraria entradas e saídas em sequência.
  final double exitHysteresisMeters;

  /// Leituras com incerteza maior que isso são descartadas.
  final double maxAccuracyMeters;

  /// Com valor, a permanência só conta enquanto a pessoa está parada: as
  /// leituras ficam a até esta distância da média das anteriores. Quem
  /// atravessa uma cerca grande andando fica tempo dentro dela, mas nunca
  /// parado, e não faz check-in. Null desliga a regra.
  final double? stillRadiusMeters;
}

enum FenceStatus { outside, inside, dwelling }

class _FenceState {
  FenceStatus status = FenceStatus.outside;
  DateTime? enteredAt;
  DateTime? outsideSince;
  double? lastDistance;
}

/// Máquina de estados das geocercas, em Dart puro para poder ser testada sem
/// aparelho:
///
///   fora ──(distância ≤ raio)──▶ dentro ──(permanência ≥ dwellTime)──▶ permanência
///     ▲                            │                                      │
///     └───(fora de raio + histerese por exitDelay)────────────────────────┘
///
/// Transições que dependem só do tempo precisam de [tick], porque o GPS para
/// de mandar leituras quando o usuário fica parado.
class GeofenceEngine {
  GeofenceEngine({required List<Geofence> fences, this.config = const GeofenceConfig()})
      : _fences = List.unmodifiable(fences),
        _states = {for (final fence in fences) fence.id: _FenceState()};

  final GeofenceConfig config;
  final List<Geofence> _fences;
  final Map<String, _FenceState> _states;

  // Detecção de parada (ver GeofenceConfig.stillRadiusMeters): média das
  // leituras desde que a pessoa parou.
  DateTime? _stillSince;
  double _stillLat = 0;
  double _stillLng = 0;
  int _stillCount = 0;
  int _awayCount = 0;

  /// Ids das cercas, na ordem em que foram passadas.
  Iterable<String> get fenceIds => _fences.map((fence) => fence.id);

  FenceStatus statusOf(String fenceId) => _states[fenceId]?.status ?? FenceStatus.outside;

  DateTime? enteredAt(String fenceId) => _states[fenceId]?.enteredAt;

  /// Em permanência e, com a detecção de parada ligada, parado há pelo menos
  /// [GeofenceConfig.dwellTime]. Uma cerca continua em permanência enquanto a
  /// pessoa não sai dela, mesmo andando; só uma cerca "assentada" pode receber
  /// um check-in novo.
  bool isSettled(String fenceId, DateTime now) {
    if (statusOf(fenceId) != FenceStatus.dwelling) return false;
    final start = dwellStartedAt(fenceId);
    return start != null && now.difference(start) >= config.dwellTime;
  }

  /// De quando conta a permanência na cerca: a entrada ou, com a detecção de
  /// parada ligada, o momento em que a pessoa parou, o que vier depois.
  DateTime? dwellStartedAt(String fenceId) {
    final entered = enteredAt(fenceId);
    final still = _stillSince;
    if (entered == null || config.stillRadiusMeters == null || still == null) return entered;
    return still.isAfter(entered) ? still : entered;
  }

  double? lastDistanceTo(String fenceId) => _states[fenceId]?.lastDistance;

  /// Processa uma leitura de posição e devolve as transições disparadas.
  List<GeofenceEvent> process(LocationFix fix) {
    if (fix.accuracyMeters > config.maxAccuracyMeters) return const [];
    _updateStillness(fix);

    final events = <GeofenceEvent>[];
    for (final fence in _fences) {
      final state = _states[fence.id]!;
      final distance = haversineDistance(fix.position, fence.center);
      state.lastDistance = distance;

      if (state.status == FenceStatus.outside) {
        if (distance <= fence.radiusMeters) {
          state.status = FenceStatus.inside;
          state.enteredAt = fix.timestamp;
          events.add(_event(fence, GeofenceTransition.enter, fix.timestamp));
        }
      } else if (distance > fence.radiusMeters + config.exitHysteresisMeters) {
        state.outsideSince ??= fix.timestamp;
      } else {
        // Voltou antes do exitDelay: era só ruído do GPS.
        state.outsideSince = null;
      }

      _checkTimers(fence, state, fix.timestamp, events);
    }
    return events;
  }

  /// Reavalia as transições que dependem só do tempo (permanência e saída
  /// confirmada), mesmo sem leitura nova.
  List<GeofenceEvent> tick(DateTime now) {
    final events = <GeofenceEvent>[];
    for (final fence in _fences) {
      _checkTimers(fence, _states[fence.id]!, now, events);
    }
    return events;
  }

  /// Uma leitura longe da média pode ser ruído; duas seguidas querem dizer
  /// que a pessoa andou, e a parada recomeça dali.
  void _updateStillness(LocationFix fix) {
    final radius = config.stillRadiusMeters;
    if (radius == null) return;
    final moved = _stillCount == 0 || haversineDistance(LatLng(_stillLat, _stillLng), fix.position) > radius;
    if (moved && (_stillCount == 0 || ++_awayCount >= 2)) {
      _stillSince = fix.timestamp;
      _stillLat = fix.position.latitude;
      _stillLng = fix.position.longitude;
      _stillCount = 1;
      _awayCount = 0;
      return;
    }
    if (moved) return;
    _awayCount = 0;
    _stillCount++;
    _stillLat += (fix.position.latitude - _stillLat) / _stillCount;
    _stillLng += (fix.position.longitude - _stillLng) / _stillCount;
  }

  void _checkTimers(Geofence fence, _FenceState state, DateTime now, List<GeofenceEvent> events) {
    if (state.status == FenceStatus.outside) return;

    final outsideSince = state.outsideSince;
    if (outsideSince != null) {
      if (now.difference(outsideSince) >= config.exitDelay) {
        state
          ..status = FenceStatus.outside
          ..enteredAt = null
          ..outsideSince = null;
        events.add(_event(fence, GeofenceTransition.exit, now));
      }
      // Com a saída pendente, a permanência não é confirmada.
      return;
    }

    if (state.status == FenceStatus.inside && now.difference(dwellStartedAt(fence.id)!) >= config.dwellTime) {
      state.status = FenceStatus.dwelling;
      events.add(_event(fence, GeofenceTransition.dwell, now));
    }
  }

  GeofenceEvent _event(Geofence fence, GeofenceTransition transition, DateTime timestamp) {
    return GeofenceEvent(
      fenceId: fence.id,
      transition: transition,
      timestamp: timestamp,
      distanceMeters: _states[fence.id]!.lastDistance ?? double.nan,
    );
  }
}

/// Com cercas sobrepostas (ex.: dois bares a 50 m um do outro), a pessoa pode
/// ir de um local ao outro sem sair da primeira cerca, e a cerca do vizinho já
/// pode estar em permanência desde antes. O check-in troca quando outro local
/// em permanência fica mais perto que o atual, por [marginMeters], durante
/// [holdTime] seguidos. Parar no meio do caminho, ou o GPS oscilando entre os
/// dois, não troca.
class CheckInSwitcher {
  CheckInSwitcher({required this.marginMeters, required this.holdTime});

  final double marginMeters;
  final Duration holdTime;
  String? _candidate;
  DateTime? _candidateSince;

  /// [others]: distância atual de cada outro local em permanência. Devolve o
  /// local para onde o check-in deve ir, ou null para ficar onde está.
  String? update({
    required double currentDistance,
    required Map<String, double> others,
    required DateTime now,
  }) {
    String? best;
    var bestDistance = double.infinity;
    for (final entry in others.entries) {
      if (entry.value + marginMeters < currentDistance && entry.value < bestDistance) {
        best = entry.key;
        bestDistance = entry.value;
      }
    }
    if (best == null) {
      reset();
      return null;
    }
    if (best != _candidate) {
      _candidate = best;
      _candidateSince = now;
      return null;
    }
    if (now.difference(_candidateSince!) < holdTime) return null;
    reset();
    return best;
  }

  void reset() {
    _candidate = null;
    _candidateSince = null;
  }
}
