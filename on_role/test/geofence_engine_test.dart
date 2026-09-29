import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:on_role/services/geofence_engine.dart';

void main() {
  const center = LatLng(-19.53477, -40.62870);
  final start = DateTime(2026, 10, 3, 22);

  /// Leitura a [meters] ao norte do centro da cerca, [elapsed] depois do início.
  LocationFix fix(double meters, Duration elapsed, {double accuracy = 10}) {
    return LocationFix(
      position: const Distance().offset(center, meters, 0),
      accuracyMeters: accuracy,
      timestamp: start.add(elapsed),
    );
  }

  /// Cerca de 50 m com histerese de 25 m: fora de verdade só depois de 75 m.
  GeofenceEngine engine({
    Duration dwellTime = const Duration(minutes: 2),
    Duration exitDelay = const Duration(seconds: 60),
  }) {
    return GeofenceEngine(
      fences: const [Geofence(id: 'bar', center: center, radiusMeters: 50)],
      config: GeofenceConfig(dwellTime: dwellTime, exitDelay: exitDelay, exitHysteresisMeters: 25),
    );
  }

  List<GeofenceTransition> transitions(List<GeofenceEvent> events) => [for (final e in events) e.transition];

  test('entra ao cruzar o raio e confirma o check-in após o tempo de permanência', () {
    final geofences = engine();

    expect(geofences.process(fix(200, Duration.zero)), isEmpty);
    expect(transitions(geofences.process(fix(30, const Duration(seconds: 10)))), [GeofenceTransition.enter]);
    expect(geofences.tick(start.add(const Duration(minutes: 1))), isEmpty);
    expect(
      transitions(geofences.tick(start.add(const Duration(minutes: 2, seconds: 10)))),
      [GeofenceTransition.dwell],
    );
    expect(geofences.statusOf('bar'), FenceStatus.dwelling);
  });

  test('quem só passa pela calçada não faz check-in', () {
    final geofences = engine();

    geofences.process(fix(40, Duration.zero));
    geofences.process(fix(120, const Duration(seconds: 30)));
    final events = [
      ...geofences.tick(start.add(const Duration(seconds: 95))),
      ...geofences.tick(start.add(const Duration(minutes: 5))),
    ];

    expect(transitions(events), [GeofenceTransition.exit]);
  });

  test('leitura na borda, dentro da histerese, não derruba o check-in', () {
    final geofences = engine(dwellTime: Duration.zero);
    geofences.process(fix(20, Duration.zero));
    expect(geofences.statusOf('bar'), FenceStatus.dwelling);

    // 65 m: fora do raio (50 m), mas dentro da histerese (75 m).
    expect(geofences.process(fix(65, const Duration(minutes: 5))), isEmpty);
    expect(geofences.tick(start.add(const Duration(minutes: 10))), isEmpty);
    expect(geofences.statusOf('bar'), FenceStatus.dwelling);
  });

  test('saída mais curta que o exitDelay é tratada como ruído do GPS', () {
    final geofences = engine(dwellTime: Duration.zero);
    geofences.process(fix(20, Duration.zero));

    geofences.process(fix(150, const Duration(minutes: 1)));
    geofences.process(fix(20, const Duration(minutes: 1, seconds: 30)));

    expect(geofences.tick(start.add(const Duration(minutes: 5))), isEmpty);
    expect(geofences.statusOf('bar'), FenceStatus.dwelling);
  });

  test('check-out só depois de ficar fora da cerca pelo exitDelay', () {
    final geofences = engine(dwellTime: Duration.zero);
    geofences.process(fix(20, Duration.zero));

    expect(geofences.process(fix(200, const Duration(minutes: 10))), isEmpty);
    expect(geofences.tick(start.add(const Duration(minutes: 10, seconds: 30))), isEmpty);

    final events = geofences.tick(start.add(const Duration(minutes: 11)));
    expect(transitions(events), [GeofenceTransition.exit]);
    expect(events.single.distanceMeters, closeTo(200, 2));
    expect(geofences.statusOf('bar'), FenceStatus.outside);
  });

  test('descarta leituras com precisão pior que o limite', () {
    final geofences = engine();

    expect(geofences.process(fix(10, Duration.zero, accuracy: 150)), isEmpty);
    expect(geofences.statusOf('bar'), FenceStatus.outside);
  });

  test('cercas sobrepostas disparam para cada local', () {
    final geofences = GeofenceEngine(
      fences: [
        const Geofence(id: 'a', center: center, radiusMeters: 60),
        Geofence(id: 'b', center: const Distance().offset(center, 80, 0), radiusMeters: 60),
      ],
      config: const GeofenceConfig(dwellTime: Duration.zero),
    );

    final events = geofences.process(fix(40, Duration.zero));

    expect(events.where((e) => e.transition == GeofenceTransition.dwell).map((e) => e.fenceId), ['a', 'b']);
  });
}
