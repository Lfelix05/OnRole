import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/data/mock/mock_database.dart';
import 'package:on_role/data/mock/mock_repositories.dart';
import 'package:on_role/providers/bench_provider.dart';
import 'package:on_role/providers/presence_provider.dart';
import 'package:on_role/services/geofence_benchmark.dart';
import 'package:on_role/services/geofence_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PresenceProvider presence;
  late BenchProvider bench;
  var batteryLevel = 90;

  setUp(() async {
    batteryLevel = 90;
    final repositories = createMockRepositories(database: MockDatabase.demo());
    presence = PresenceProvider(repository: repositories.presence, gpsEnabled: false);
    await presence.start(userId: 'visitante');
    bench = BenchProvider(
      presence: presence,
      readBattery: () async => (level: batteryLevel, state: 'discharging'),
      readDevice: () async => 'Aparelho de teste',
    );
  });

  tearDown(() async {
    bench.dispose();
    await presence.stop();
    presence.dispose();
  });

  test('a precisão roda fora da tela e entra no relatório', () async {
    await bench.runPrecision(nights: 5, seed: 2);
    expect(bench.precisionRunning, isFalse);
    expect(bench.precision!.score.nights, 5);
    expect(bench.report, contains('Precisão das geocercas'));
  });

  test('a rodada de desempenho usa os tempos reais e volta aos da demonstração', () async {
    await bench.startPerformance(duration: const Duration(minutes: 30));
    expect(bench.isRunning, isTrue);
    expect(presence.config.dwellTime, const GeofenceConfig().dwellTime);

    batteryLevel = 88;
    await bench.stopPerformance();
    expect(bench.isRunning, isFalse);
    expect(presence.config.dwellTime, const Duration(seconds: 10));
    final report = bench.performance!;
    expect(report.device, 'Aparelho de teste');
    expect(report.battery.map((reading) => reading.level), [90, 88]);
    expect(bench.report, contains('Desempenho no aparelho'));
  });

  test('o consumo de bateria só vale fora da tomada', () {
    final now = DateTime(2026, 11, 6, 20);
    PerformanceReport report(String state) => PerformanceReport(
          device: 'x',
          duration: const Duration(hours: 1),
          seed: 1,
          frames: null,
          battery: [
            (at: now, level: 90, state: 'discharging'),
            (at: now.add(const Duration(minutes: 30)), level: 86, state: state),
          ],
          score: GeofenceScore(),
        );
    expect(report('discharging').batteryPerHour, 8);
    expect(report('charging').batteryPerHour, isNull);
  });
}
