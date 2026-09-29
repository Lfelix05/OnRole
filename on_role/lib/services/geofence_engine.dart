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
  const GeofenceConfig({
    this.dwellTime = const Duration(minutes: 2),
    this.exitDelay = const Duration(seconds: 60),
    this.exitHysteresisMeters = 25,
    this.maxAccuracyMeters = 60,
  });

  /// Tempos curtos para demonstração com o modo de simulação.
  static const demo = GeofenceConfig(
    dwellTime: Duration(seconds: 10),
    exitDelay: Duration(seconds: 5),
    exitHysteresisMeters: 15,
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

  FenceStatus statusOf(String fenceId) => _states[fenceId]?.status ?? FenceStatus.outside;

  DateTime? enteredAt(String fenceId) => _states[fenceId]?.enteredAt;

  double? lastDistanceTo(String fenceId) => _states[fenceId]?.lastDistance;

  /// Processa uma leitura de posição e devolve as transições disparadas.
  List<GeofenceEvent> process(LocationFix fix) {
    if (fix.accuracyMeters > config.maxAccuracyMeters) return const [];

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

    if (state.status == FenceStatus.inside && now.difference(state.enteredAt!) >= config.dwellTime) {
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
