import 'geofence_engine.dart';

/// Uma mudança no check-in: entrada ([checkedIn] verdadeiro) ou saída do
/// local [venueId] no momento [at].
typedef CheckInChange = ({String venueId, bool checkedIn, DateTime at});

/// O que uma leitura ou um tick produziu: as transições das cercas e as
/// mudanças de check-in que elas causaram.
typedef TrackerStep = ({List<GeofenceEvent> events, List<CheckInChange> changes});

/// Decide onde está o check-in a partir das transições do [GeofenceEngine],
/// em Dart puro. O app (PresenceProvider) e a bancada de testes usam esta
/// mesma classe, então a precisão medida com trajetos sintéticos é a do app.
///
/// Regras:
/// - sem check-in, a permanência confirmada (dwell) num local faz o check-in;
///   com várias cercas em permanência, vai para o local mais próximo em que a
///   pessoa está parada (ver [GeofenceEngine.isSettled]);
/// - a saída confirmada (exit) do local atual faz o check-out;
/// - permanência confirmada num local mais perto que o atual (por mais que a
///   histerese) troca o check-in, e o [CheckInSwitcher] cobre quem anda de um vizinho ao outro
///   sem sair da primeira cerca.
class CheckInTracker {
  CheckInTracker(this.engine)
      : _switcher = CheckInSwitcher(
          marginMeters: engine.config.exitHysteresisMeters,
          holdTime: engine.config.dwellTime,
        );

  final GeofenceEngine engine;
  final CheckInSwitcher _switcher;
  String? _venueId;

  /// Local do check-in atual (null se nenhum).
  String? get venueId => _venueId;

  TrackerStep process(LocationFix fix) {
    final changes = <CheckInChange>[];
    final events = engine.process(fix);
    _apply(events, fix.timestamp, changes);
    return (events: events, changes: changes);
  }

  /// Reavalia o que depende só do tempo (ver [GeofenceEngine.tick]).
  TrackerStep tick(DateTime now) {
    final changes = <CheckInChange>[];
    final events = engine.tick(now);
    _apply(events, now, changes);
    return (events: events, changes: changes);
  }

  /// Encerra o check-in atual, se houver (ex.: logout ou troca de modo).
  CheckInChange? checkOut(DateTime at) {
    final changes = <CheckInChange>[];
    _checkOut(at, changes);
    return changes.isEmpty ? null : changes.single;
  }

  void _apply(List<GeofenceEvent> events, DateTime now, List<CheckInChange> changes) {
    for (final event in events) {
      if (event.transition == GeofenceTransition.exit && event.fenceId == _venueId) {
        _checkOut(event.timestamp, changes);
      }
    }

    final active = _venueId;
    if (active == null) {
      // A cada passo, e não só quando há transição: quem sai do Bharem para a
      // Área Verde nunca sai da cerca dela, e ela só fica assentada minutos
      // depois, sem evento novo.
      final venueId = _nearestSettledVenueId(now);
      if (venueId != null) _checkIn(venueId, now, changes);
      return;
    }

    GeofenceEvent? closer;
    var closestDistance = engine.lastDistanceTo(active) ?? double.infinity;
    for (final event in events) {
      if (event.transition != GeofenceTransition.dwell || event.fenceId == active) continue;
      // A mesma margem do CheckInSwitcher: sem ela, o GPS oscilando entre
      // dois vizinhos trocaria o check-in a cada nova permanência.
      if (event.distanceMeters + engine.config.exitHysteresisMeters < closestDistance) {
        closer = event;
        closestDistance = event.distanceMeters;
      }
    }
    if (closer != null) {
      _checkOut(closer.timestamp, changes);
      _checkIn(closer.fenceId, closer.timestamp, changes);
      return;
    }
    _followCloserVenue(now, changes);
  }

  void _followCloserVenue(DateTime now, List<CheckInChange> changes) {
    final active = _venueId;
    if (active == null) return;
    final target = _switcher.update(
      currentDistance: engine.lastDistanceTo(active) ?? double.infinity,
      others: {
        for (final id in engine.fenceIds)
          if (id != active && engine.isSettled(id, now)) id: engine.lastDistanceTo(id) ?? double.infinity,
      },
      now: now,
    );
    if (target == null) return;
    _checkOut(now, changes);
    _checkIn(target, now, changes);
  }

  /// Ao sair de um local, a cerca vizinha pode continuar em permanência (ex.:
  /// quem estava no Bharem também estava dentro da cerca da Área Verde). Só
  /// conta se a pessoa está parada ali (ver [GeofenceEngine.isSettled]).
  String? _nearestSettledVenueId(DateTime now) {
    String? nearest;
    var nearestDistance = double.infinity;
    for (final id in engine.fenceIds) {
      if (!engine.isSettled(id, now)) continue;
      final distance = engine.lastDistanceTo(id) ?? double.infinity;
      if (nearest == null || distance < nearestDistance) {
        nearest = id;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  void _checkIn(String venueId, DateTime at, List<CheckInChange> changes) {
    _switcher.reset();
    _venueId = venueId;
    changes.add((venueId: venueId, checkedIn: true, at: at));
  }

  void _checkOut(DateTime at, List<CheckInChange> changes) {
    final venueId = _venueId;
    if (venueId == null) return;
    _venueId = null;
    changes.add((venueId: venueId, checkedIn: false, at: at));
  }
}
