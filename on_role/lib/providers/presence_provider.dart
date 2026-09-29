import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../data/repositories.dart';
import '../data/venue_catalog.dart';
import '../models/check_in.dart';
import '../models/venue.dart';
import '../services/geo.dart';
import '../services/geofence_engine.dart';
import '../services/location_service.dart';

/// Localização do usuário e check-in automático por geocerca.
class PresenceProvider extends ChangeNotifier {
  PresenceProvider({required PresenceRepository repository}) : _repository = repository;

  /// O modo de simulação só existe em builds de depuração: na build do teste
  /// de campo (release), check-in só acontece com GPS real.
  static const bool simulationAvailable = kDebugMode;

  /// De quanto em quanto tempo a presença é renovada no servidor (tem que ser
  /// bem menor que [presenceTimeout]).
  static const _keepAliveInterval = Duration(minutes: 5);

  final PresenceRepository _repository;
  final GpsLocationService _gps = GpsLocationService();
  final SimulatedLocationService _simulated = SimulatedLocationService();
  late GeofenceEngine _engine = _createEngine();
  StreamSubscription<LocationFix>? _subscription;
  Timer? _ticker;
  int _listenGeneration = 0;
  bool _disposed = false;

  String? _userId;
  bool _simulating = false;
  LocationAvailability? _availability;
  LocationFix? _lastFix;
  CheckIn? _activeCheckIn;
  DateTime? _lastKeepAlive;
  Future<void>? _pendingCheckOut;
  final List<GeofenceEvent> _events = [];

  bool get isSimulating => _simulating;

  /// Nulo enquanto a permissão ainda não foi verificada.
  LocationAvailability? get availability => _availability;
  LatLng? get position => _lastFix?.position;
  double? get accuracyMeters => _lastFix?.accuracyMeters;
  CheckIn? get activeCheckIn => _activeCheckIn;

  Venue? get checkedInVenue {
    final checkIn = _activeCheckIn;
    return checkIn == null ? null : findVenue(checkIn.venueId);
  }

  /// Transições da sessão, para medir a taxa de acerto das geocercas no
  /// experimento de campo.
  List<GeofenceEvent> get events => List.unmodifiable(_events);

  /// Local onde o usuário entrou mas ainda não completou o tempo mínimo de
  /// permanência, com o progresso da confirmação (0 a 1).
  ({Venue venue, double progress})? get pendingCheckIn {
    ({Venue venue, double progress})? nearest;
    var nearestDistance = double.infinity;
    for (final venue in venueCatalog) {
      if (venue.id == _activeCheckIn?.venueId || _engine.statusOf(venue.id) != FenceStatus.inside) continue;
      final distance = _engine.lastDistanceTo(venue.id) ?? double.infinity;
      if (distance >= nearestDistance) continue;

      final elapsed = DateTime.now().difference(_engine.enteredAt(venue.id)!);
      final progress = elapsed.inMilliseconds / _engine.config.dwellTime.inMilliseconds;
      nearest = (venue: venue, progress: progress.clamp(0.0, 1.0));
      nearestDistance = distance;
    }
    return nearest;
  }

  double? distanceTo(Venue venue) {
    final current = position;
    return current == null ? null : haversineDistance(current, venue.location);
  }

  Future<void> start({required String userId}) async {
    if (_userId != null) return;
    _userId = userId;
    // Uma sessão anterior pode ter terminado com o app fechado à força e o
    // check-in ainda aberto.
    _repository.clearPresence(userId).catchError(_logWriteError);
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) => _onTick());
    await _listen();
  }

  Future<void> stop() async {
    if (_userId == null) return;
    _ticker?.cancel();
    _ticker = null;
    _listenGeneration++;
    final subscription = _subscription;
    _subscription = null;
    if (_activeCheckIn != null) _checkOut(DateTime.now());
    final pendingCheckOut = _pendingCheckOut;
    _pendingCheckOut = null;
    _userId = null;
    _availability = null;
    _lastFix = null;
    _events.clear();
    _engine = _createEngine();
    notifyListeners();
    await subscription?.cancel();
    // O check-out precisa chegar ao servidor antes do logout, senão a pessoa
    // continua contando na lotação até a presença expirar.
    await pendingCheckOut?.timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  /// Pede a permissão de novo (ex.: depois que o usuário negou uma vez).
  Future<void> retry() => _listen();

  Future<void> openSettings() async {
    final availability = _availability;
    if (availability == null || availability == LocationAvailability.ready) return;
    await _gps.openSettings(availability);
  }

  Future<void> setSimulating(bool value) async {
    if (!simulationAvailable || value == _simulating) return;
    _simulating = value;
    // Cada modo tem seus tempos (a simulação usa tempos curtos), então as
    // cercas recomeçam do zero.
    if (_activeCheckIn != null) _checkOut(DateTime.now());
    _engine = _createEngine();
    _lastFix = null;
    notifyListeners();
    if (_userId != null) await _listen();
  }

  void simulateMoveTo(LatLng position) {
    if (_simulating) _simulated.moveTo(position);
  }

  Future<void> _listen() async {
    final generation = ++_listenGeneration;
    await _subscription?.cancel();
    _subscription = null;

    final LocationService service = _simulating ? _simulated : _gps;
    final availability = await service.prepare();
    // Enquanto esperava a permissão, o usuário pode ter trocado de modo ou
    // saído da conta.
    if (_disposed || generation != _listenGeneration) return;

    _availability = availability;
    notifyListeners();
    if (availability != LocationAvailability.ready) return;

    _subscription = service.watch().listen(
      _onFix,
      onError: (Object error) => debugPrint('Erro no stream de localização: $error'),
    );
  }

  void _onFix(LocationFix fix) {
    // Posição de app de GPS falso não vale check-in fora da depuração.
    if (fix.isMocked && !kDebugMode) return;
    _lastFix = fix;
    _apply(_engine.process(fix));
    notifyListeners();
  }

  void _onTick() {
    final now = DateTime.now();
    final active = _activeCheckIn;
    final lastKeepAlive = _lastKeepAlive;
    if (active != null && (lastKeepAlive == null || now.difference(lastKeepAlive) >= _keepAliveInterval)) {
      _lastKeepAlive = now;
      _repository.keepAlive(active).catchError(_logWriteError);
    }

    final events = _engine.tick(now);
    if (events.isNotEmpty) {
      _apply(events);
      notifyListeners();
    } else if (pendingCheckIn != null) {
      // Só para atualizar o progresso da confirmação na tela.
      notifyListeners();
    }
  }

  void _apply(List<GeofenceEvent> events) {
    if (events.isEmpty) return;
    _events.addAll(events);

    for (final event in events) {
      if (event.transition == GeofenceTransition.exit && event.fenceId == _activeCheckIn?.venueId) {
        _checkOut(event.timestamp);
      }
    }

    final active = _activeCheckIn;
    if (active == null) {
      // Com cercas sobrepostas pode haver mais de um local em permanência:
      // o check-in vai para o mais próximo.
      final venueId = _nearestDwellingVenueId();
      if (venueId != null) _checkIn(venueId, events.last.timestamp);
      return;
    }

    // Permanência confirmada num local mais perto que o atual (ex.: dois
    // bares vizinhos) troca o check-in.
    GeofenceEvent? closer;
    var closestDistance = _engine.lastDistanceTo(active.venueId) ?? double.infinity;
    for (final event in events) {
      if (event.transition != GeofenceTransition.dwell || event.fenceId == active.venueId) continue;
      if (event.distanceMeters < closestDistance) {
        closer = event;
        closestDistance = event.distanceMeters;
      }
    }
    if (closer != null) {
      _checkOut(closer.timestamp);
      _checkIn(closer.fenceId, closer.timestamp);
    }
  }

  String? _nearestDwellingVenueId() {
    String? nearest;
    var nearestDistance = double.infinity;
    for (final venue in venueCatalog) {
      if (_engine.statusOf(venue.id) != FenceStatus.dwelling) continue;
      final distance = _engine.lastDistanceTo(venue.id) ?? double.infinity;
      if (nearest == null || distance < nearestDistance) {
        nearest = venue.id;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  void _checkIn(String venueId, DateTime at) {
    final userId = _userId;
    if (userId == null) return;
    final checkIn = CheckIn(
      id: '$userId-${at.millisecondsSinceEpoch}',
      userId: userId,
      venueId: venueId,
      checkedInAt: at,
    );
    // A tela reage na hora; a gravação no servidor segue em segundo plano.
    _activeCheckIn = checkIn;
    _lastKeepAlive = at;
    _repository.checkIn(checkIn).catchError(_logWriteError);
  }

  void _checkOut(DateTime at) {
    final checkIn = _activeCheckIn;
    if (checkIn == null) return;
    checkIn.checkedOutAt = at;
    _activeCheckIn = null;
    _pendingCheckOut = _repository.checkOut(checkIn).catchError(_logWriteError);
  }

  void _logWriteError(Object error) => debugPrint('PresenceProvider: $error');

  GeofenceEngine _createEngine() {
    return GeofenceEngine(
      fences: [
        for (final venue in venueCatalog)
          Geofence(id: venue.id, center: venue.location, radiusMeters: venue.radiusMeters),
      ],
      config: _simulating ? GeofenceConfig.demo : const GeofenceConfig(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _subscription?.cancel();
    _simulated.dispose();
    super.dispose();
  }
}
