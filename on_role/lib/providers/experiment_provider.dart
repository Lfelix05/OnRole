import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../data/repositories.dart';
import '../services/frame_stats.dart';
import 'auth_provider.dart';

/// O que os outros providers precisam para registrar dados do experimento.
abstract class TelemetryLog {
  void log(String type, [Map<String, Object?> data = const {}]);

  /// Leitura de GPS: só a precisão, nunca a posição.
  void recordFix({required double accuracyMeters, required bool accepted});
}

typedef BatteryReading = ({int level, String state});

/// Coleta dos dados do experimento de campo (seção 5C do projeto), só de
/// quem aceitou participar. Os eventos ficam num buffer e sobem em lotes: uma
/// gravação a cada 5 minutos (e ao sair do app ou marcar o diário). Com o app
/// vivo o dia todo, 10 participantes somam ~2.900 gravações por dia, bem
/// abaixo das 20 mil da cota gratuita do Firestore.
class ExperimentProvider extends ChangeNotifier
    with WidgetsBindingObserver
    implements TelemetryLog {
  ExperimentProvider({
    required ExperimentRepository repository,
    required AuthProvider auth,
    Future<BatteryReading?> Function()? readBattery,
    Future<Map<String, Object?>> Function()? readDevice,
    this.flushInterval = const Duration(minutes: 5),
    this.batteryInterval = const Duration(minutes: 5),
    this.frameWindow = const Duration(seconds: 30),
  }) : _repository = repository,
       _auth = auth,
       _readBattery = readBattery ?? _defaultReadBattery,
       _readDevice = readDevice ?? _defaultReadDevice {
    auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final ExperimentRepository _repository;
  final AuthProvider _auth;
  final Future<BatteryReading?> Function() _readBattery;
  final Future<Map<String, Object?>> Function() _readDevice;
  final Duration flushInterval;
  final Duration batteryInterval;

  /// Os quadros são resumidos em janelas deste tamanho.
  final Duration frameWindow;

  String? _userId;
  bool _enrolled = false;
  bool _loading = false;
  bool _running = false;
  final List<Map<String, Object?>> _buffer = [];
  Timer? _flushTimer;
  Timer? _batteryTimer;
  AppLifecycleState _appState = AppLifecycleState.resumed;

  // GPS agregado entre um envio e outro.
  int _fixes = 0;
  int _rejectedFixes = 0;
  double _accuracySum = 0;

  // Quadros da tela que está sendo medida. A tela fica guardada mesmo sem
  // consentimento, e a medição começa quando a participação é ativada.
  String? _frameScreen;
  bool _sampling = false;
  final List<FrameSample> _frames = [];
  DateTime? _frameWindowStart;

  bool get isEnrolled => _enrolled;
  bool get isLoading => _loading;

  /// Eventos ainda não enviados.
  int get pendingEvents => _buffer.length;

  /// Retorna a mensagem de erro, ou null se deu certo.
  Future<String?> setEnrolled(bool enrolled) async {
    // Quem aceita logo depois do cadastro não pode ter a escolha sobrescrita
    // pela leitura do consentimento que ainda está a caminho.
    await _sync;
    final userId = _userId;
    if (userId == null) return 'Sua sessão expirou. Entre de novo.';
    try {
      await _repository.setEnrolled(userId, enrolled);
    } catch (error) {
      debugPrint('ExperimentProvider: $error');
      return 'Não foi possível salvar. Confira a conexão.';
    }
    _enrolled = enrolled;
    if (enrolled) {
      await _begin();
    } else {
      // Quem sai não deixa nada pendente para trás.
      _buffer.clear();
      _end();
    }
    notifyListeners();
    return null;
  }

  /// Diário de campo: o participante marca a hora real em que chegou ou saiu
  /// de um local. É o gabarito para medir acerto e latência das geocercas.
  void markGroundTruth({required String venueId, required bool arrived}) {
    log('ground_truth', {
      'action': arrived ? 'arrived' : 'left',
      'venueId': venueId,
    });
    flush();
  }

  /// Retorna a mensagem de erro, ou null se apagou.
  Future<String?> deleteMyData() async {
    final userId = _userId;
    if (userId == null) return 'Sua sessão expirou. Entre de novo.';
    try {
      _buffer.clear();
      await _repository.deleteAll(userId);
      notifyListeners();
      return null;
    } catch (error) {
      debugPrint('ExperimentProvider: $error');
      return 'Não foi possível apagar. Confira a conexão.';
    }
  }

  @override
  void log(String type, [Map<String, Object?> data = const {}]) {
    if (!_running) return;
    _buffer.add({
      't': DateTime.now().millisecondsSinceEpoch,
      'type': type,
      ...data,
    });
    if (_buffer.length >= 400) flush();
  }

  @override
  void recordFix({required double accuracyMeters, required bool accepted}) {
    if (!_running) return;
    _fixes++;
    if (!accepted) _rejectedFixes++;
    _accuracySum += accuracyMeters;
  }

  /// Mede o desempenho de renderização enquanto [screen] está aberta (H4).
  void startFrameSampling(String screen) {
    _detachFrames();
    _frameScreen = screen;
    _attachFrames();
  }

  void stopFrameSampling() {
    _detachFrames();
    _frameScreen = null;
  }

  /// Tela cujos quadros estão sendo medidos agora (null se nenhuma).
  @visibleForTesting
  String? get sampledScreen => _sampling ? _frameScreen : null;

  /// Envia o que estiver no buffer.
  Future<void> flush() async {
    final userId = _userId;
    if (userId == null || !_running) return;
    if (_fixes > 0) {
      _buffer.add({
        't': DateTime.now().millisecondsSinceEpoch,
        'type': 'gps',
        'fixes': _fixes,
        'rejected': _rejectedFixes,
        'avgAccuracy': (_accuracySum / _fixes * 10).round() / 10,
      });
      _fixes = 0;
      _rejectedFixes = 0;
      _accuracySum = 0;
    }
    if (_buffer.isEmpty) return;
    final events = List.of(_buffer);
    _buffer.clear();
    try {
      await _repository.upload(userId, events);
    } catch (error) {
      debugPrint('ExperimentProvider: $error');
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appState = state;
    log('lifecycle', {'state': state.name});
    _sampleBattery();
    // Pode ser a última chance antes de o sistema fechar o app.
    if (state != AppLifecycleState.resumed) flush();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frames.add((build: timing.buildDuration, raster: timing.rasterDuration));
    }
    final start = _frameWindowStart;
    if (start != null && DateTime.now().difference(start) >= frameWindow) {
      _emitFrameStats();
    }
  }

  void _attachFrames() {
    if (!_running || _sampling || _frameScreen == null) return;
    _sampling = true;
    _frames.clear();
    _frameWindowStart = DateTime.now();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _detachFrames() {
    if (!_sampling) return;
    _emitFrameStats();
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _sampling = false;
  }

  void _emitFrameStats() {
    final stats = summarizeFrames(_frames);
    if (stats != null) {
      log('frames', {'screen': _frameScreen, ...stats.toJson()});
    }
    _frames.clear();
    _frameWindowStart = DateTime.now();
  }

  Future<void> _sampleBattery() async {
    final reading = await _readBattery();
    if (reading == null) return;
    log('battery', {
      'level': reading.level,
      'state': reading.state,
      'appState': _appState.name,
    });
  }

  Future<void> _begin() async {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _flushTimer = Timer.periodic(flushInterval, (_) => flush());
    _batteryTimer = Timer.periodic(batteryInterval, (_) => _sampleBattery());
    _attachFrames();
    log('session', await _readDevice());
    await _sampleBattery();
  }

  void _end() {
    if (!_running) return;
    _detachFrames();
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
    _batteryTimer?.cancel();
    _flushTimer = null;
    _batteryTimer = null;
  }

  /// Trocas de conta em fila: cada uma termina antes da próxima começar.
  Future<void> _sync = Future.value();

  void _onAuthChanged() => _sync = _sync.then((_) => _syncSession());

  Future<void> _syncSession() async {
    final userId = _auth.currentUser?.id;
    if (userId == _userId) return;
    if (_running) {
      await flush();
      _end();
    }
    _userId = userId;
    _enrolled = false;
    _buffer.clear();
    if (userId == null) return;

    _loading = true;
    try {
      _enrolled = await _repository.isEnrolled(userId);
    } catch (error) {
      debugPrint('ExperimentProvider: $error');
    }
    _loading = false;
    // A pessoa pode ter trocado de conta enquanto esperava a resposta.
    if (_userId != userId) return;
    if (_enrolled) await _begin();
    notifyListeners();
  }

  static Future<BatteryReading?> _defaultReadBattery() async {
    try {
      final battery = Battery();
      return (
        level: await battery.batteryLevel,
        state: (await battery.batteryState).name,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, Object?>> _defaultReadDevice() async {
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    try {
      final info = await DeviceInfoPlugin().deviceInfo;
      if (info is AndroidDeviceInfo) {
        return {
          'platform': platform,
          'model': '${info.manufacturer} ${info.model}',
          'os': 'Android ${info.version.release}',
          'sdk': info.version.sdkInt,
        };
      }
      if (info is IosDeviceInfo) {
        return {
          'platform': platform,
          'model': info.utsname.machine,
          'os': 'iOS ${info.systemVersion}',
        };
      }
    } catch (_) {
      // Sem o plugin (testes, desktop): fica só a plataforma.
    }
    return {'platform': platform};
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _end();
    super.dispose();
  }
}
