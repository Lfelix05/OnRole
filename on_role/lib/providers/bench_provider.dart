import 'dart:async';
import 'dart:isolate';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../data/venue_catalog.dart';
import '../services/check_in_tracker.dart';
import '../services/frame_stats.dart';
import '../services/geofence_benchmark.dart';
import '../services/geofence_engine.dart';
import '../services/synthetic_trajectories.dart';
import 'presence_provider.dart';

typedef BatteryReading = ({DateTime at, int level, String state});

/// Resultado de uma rodada de desempenho no aparelho (H4).
class PerformanceReport {
  const PerformanceReport({
    required this.device,
    required this.duration,
    required this.seed,
    required this.frames,
    required this.battery,
    required this.score,
  });

  final String device;
  final Duration duration;
  final int seed;
  final FrameStats? frames;
  final List<BatteryReading> battery;

  /// Check-ins do app no aparelho x gabarito do trajeto repetido.
  final GeofenceScore score;

  /// Consumo em pontos percentuais por hora, só se o aparelho ficou fora da
  /// tomada a rodada inteira.
  double? get batteryPerHour {
    if (battery.length < 2 || battery.any((reading) => reading.state == 'charging' || reading.state == 'full')) {
      return null;
    }
    final hours = battery.last.at.difference(battery.first.at).inSeconds / 3600;
    return hours <= 0 ? null : (battery.first.level - battery.last.level) / hours;
  }

  String toMarkdown() {
    final f = frames;
    final drain = batteryPerHour;
    String pct(double value) => '${(value * 100).toStringAsFixed(1)}%';
    return [
      '### Desempenho no aparelho com trajeto sintético (H4)',
      '',
      'Aparelho: $device. Duração: ${duration.inMinutes} min. Trajeto: semente $seed.',
      '',
      '| Métrica | Valor |',
      '| --- | --- |',
      if (f == null)
        '| Quadros do mapa | sem medição (o mapa não ficou aberto) |'
      else ...[
        '| Quadros do mapa medidos | ${f.frames} |',
        '| Construção (UI) média | ${f.avgBuildMs.toStringAsFixed(2)} ms |',
        '| Rasterização (GPU) média | ${f.avgRasterMs.toStringAsFixed(2)} ms |',
        '| Quadro no percentil 90 | ${f.p90FrameMs.toStringAsFixed(2)} ms |',
        '| Quadros dentro de 16,7 ms (60 FPS) | ${pct(1 - f.jankRatio)} |',
      ],
      if (drain == null)
        '| Bateria | sem medição válida (precisa de 2+ leituras fora da tomada) |'
      else
        '| Bateria | ${drain.toStringAsFixed(1)} pontos por hora '
            '(${battery.first.level}% → ${battery.last.level}%) |',
      '| Visitas do trajeto detectadas | ${score.detected} de ${score.visits} |',
      '| Check-ins certos | ${score.detected} de ${score.sessions} |',
    ].join('\n');
  }
}

/// Bancada de testes do pesquisador (só no `MODE=bancada`). Não envolve
/// participantes: tudo roda com trajetos sintéticos e fica no aparelho.
///
/// - Precisão (H2): passa centenas de noites sintéticas pelo mesmo
///   [CheckInTracker] do app, no tempo simulado (ver [GeofenceReport]).
/// - Desempenho (H4): repete um trajeto sintético em tempo real pelo
///   PresenceProvider, com os tempos reais das geocercas, enquanto mede os
///   quadros do mapa e a bateria.
class BenchProvider extends ChangeNotifier {
  BenchProvider({
    required PresenceProvider presence,
    Future<({int level, String state})?> Function()? readBattery,
    Future<String> Function()? readDevice,
    this.batteryInterval = const Duration(minutes: 5),
  })  : _presence = presence,
        _readBattery = readBattery ?? _defaultReadBattery,
        _readDevice = readDevice ?? _defaultReadDevice;

  final PresenceProvider _presence;
  final Future<({int level, String state})?> Function() _readBattery;
  final Future<String> Function() _readDevice;
  final Duration batteryInterval;

  bool _precisionRunning = false;
  GeofenceReport? _precision;

  bool get precisionRunning => _precisionRunning;
  GeofenceReport? get precision => _precision;

  /// Roda num isolate separado para a tela não travar.
  Future<void> runPrecision({int nights = 200, int seed = 1}) async {
    if (_precisionRunning) return;
    _precisionRunning = true;
    notifyListeners();
    try {
      _precision = await Isolate.run(() => GeofenceReport.run(venues: venueCatalog, nights: nights, seed: seed));
    } finally {
      _precisionRunning = false;
      notifyListeners();
    }
  }

  // Rodada de desempenho em andamento.
  DateTime? _startedAt;
  Duration _duration = Duration.zero;
  int _seed = 1;
  Timer? _replayTimer;
  Timer? _batteryTimer;
  List<({Duration offset, LocationFix fix})> _queue = const [];
  int _next = 0;
  List<TruthVisit> _truth = const [];
  final List<CheckInChange> _changes = [];
  String? _lastVenueId;
  final List<BatteryReading> _battery = [];
  final List<FrameSample> _frames = [];
  bool _mapVisible = false;
  bool _sampling = false;
  PerformanceReport? _performance;

  bool get isRunning => _startedAt != null;
  PerformanceReport? get performance => _performance;

  Duration get elapsed {
    final start = _startedAt;
    return start == null ? Duration.zero : DateTime.now().difference(start);
  }

  Duration get duration => _duration;

  Future<void> startPerformance({Duration duration = const Duration(minutes: 30), int seed = 1}) async {
    if (isRunning) return;
    await _presence.setSimulating(true, realTiming: true);

    // Noites seguidas até cobrir a duração pedida.
    final generator = TrajectoryGenerator(venues: venueCatalog, seed: seed);
    final queue = <({Duration offset, LocationFix fix})>[];
    final truth = <TruthVisit>[];
    final now = DateTime.now();
    var offset = Duration.zero;
    while (offset < duration) {
      final night = generator.night();
      Duration shift(DateTime time) => offset + time.difference(night.start);
      for (final fix in night.fixes) {
        queue.add((offset: shift(fix.timestamp), fix: fix));
      }
      for (final visit in night.visits) {
        truth.add(TruthVisit(
          venueId: visit.venueId,
          arrivedAt: now.add(shift(visit.arrivedAt)),
          leftAt: now.add(shift(visit.leftAt)),
        ));
      }
      offset += night.end.difference(night.start);
    }

    _startedAt = now;
    _duration = duration;
    _seed = seed;
    _queue = queue;
    _next = 0;
    _truth = truth;
    _changes.clear();
    _lastVenueId = _presence.activeCheckIn?.venueId;
    _battery.clear();
    _frames.clear();
    _performance = null;
    _presence.addListener(_onPresence);
    _replayTimer = Timer.periodic(const Duration(seconds: 1), (_) => _replay());
    _batteryTimer = Timer.periodic(batteryInterval, (_) => _sampleBattery());
    _attachFrames();
    await _sampleBattery();
    notifyListeners();
  }

  Future<void> stopPerformance() async {
    final start = _startedAt;
    if (start == null) return;
    await _sampleBattery();
    final end = DateTime.now();
    _replayTimer?.cancel();
    _batteryTimer?.cancel();
    _presence.removeListener(_onPresence);
    _detachFrames();
    _startedAt = null;

    // Só conta o que aconteceu até a parada; a visita em andamento termina ali.
    final visits = [
      for (final visit in _truth)
        if (visit.arrivedAt.isBefore(end))
          TruthVisit(
            venueId: visit.venueId,
            arrivedAt: visit.arrivedAt,
            leftAt: visit.leftAt.isAfter(end) ? end : visit.leftAt,
          ),
    ];
    final score = GeofenceScore()
      ..addNight(
        SyntheticNight(start: start, end: end, fixes: const [], visits: visits, passBys: 0, shortStops: 0),
        sessionsFrom(_changes, closeAt: end),
      );
    _performance = PerformanceReport(
      device: await _readDevice(),
      duration: end.difference(start),
      seed: _seed,
      frames: summarizeFrames(_frames),
      battery: List.of(_battery),
      score: score,
    );
    _frames.clear();
    // De volta aos tempos curtos da demonstração.
    await _presence.setSimulating(true);
    notifyListeners();
  }

  /// O mapa avisa quando está na tela: só esses quadros entram na medição.
  void startFrameSampling() {
    _mapVisible = true;
    _attachFrames();
  }

  void stopFrameSampling() {
    _mapVisible = false;
    _detachFrames();
  }

  /// Relatório completo, para copiar para o TCC.
  String get report => [
        if (_precision != null) _precision!.toMarkdown(),
        if (_performance != null) _performance!.toMarkdown(),
      ].join('\n\n');

  void _replay() {
    final elapsed = this.elapsed;
    while (_next < _queue.length && _queue[_next].offset <= elapsed) {
      final fix = _queue[_next++].fix;
      // O motor compara com o relógio do aparelho (ver GpsLocationService).
      _presence.simulateFix(LocationFix(
        position: fix.position,
        accuracyMeters: fix.accuracyMeters,
        timestamp: DateTime.now(),
        isMocked: true,
      ));
    }
    if (elapsed >= _duration) {
      stopPerformance();
    } else {
      notifyListeners();
    }
  }

  void _onPresence() {
    final venueId = _presence.activeCheckIn?.venueId;
    if (venueId == _lastVenueId) return;
    final now = DateTime.now();
    final previous = _lastVenueId;
    if (previous != null) _changes.add((venueId: previous, checkedIn: false, at: now));
    if (venueId != null) _changes.add((venueId: venueId, checkedIn: true, at: now));
    _lastVenueId = venueId;
  }

  Future<void> _sampleBattery() async {
    final reading = await _readBattery();
    if (reading == null) return;
    _battery.add((at: DateTime.now(), level: reading.level, state: reading.state));
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frames.add((build: timing.buildDuration, raster: timing.rasterDuration));
    }
  }

  void _attachFrames() {
    if (!isRunning || !_mapVisible || _sampling) return;
    _sampling = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _detachFrames() {
    if (!_sampling) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _sampling = false;
  }

  static Future<({int level, String state})?> _defaultReadBattery() async {
    try {
      final battery = Battery();
      return (level: await battery.batteryLevel, state: (await battery.batteryState).name);
    } catch (_) {
      return null;
    }
  }

  static Future<String> _defaultReadDevice() async {
    try {
      final info = await DeviceInfoPlugin().deviceInfo;
      if (info is AndroidDeviceInfo) {
        return '${info.manufacturer} ${info.model}, Android ${info.version.release}';
      }
      if (info is IosDeviceInfo) return '${info.utsname.machine}, iOS ${info.systemVersion}';
    } catch (_) {
      // Sem o plugin (testes, desktop).
    }
    return kIsWeb ? 'web' : defaultTargetPlatform.name;
  }

  @override
  void dispose() {
    _replayTimer?.cancel();
    _batteryTimer?.cancel();
    _presence.removeListener(_onPresence);
    _detachFrames();
    super.dispose();
  }
}
