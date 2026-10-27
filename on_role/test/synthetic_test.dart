import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:on_role/app_mode.dart';
import 'package:on_role/data/mock/mock_database.dart';
import 'package:on_role/data/mock/mock_repositories.dart';
import 'package:on_role/data/venue_catalog.dart';
import 'package:on_role/models/match.dart';
import 'package:on_role/providers/presence_provider.dart';
import 'package:on_role/services/check_in_tracker.dart';
import 'package:on_role/services/crowd_simulator.dart';
import 'package:on_role/services/geo.dart';
import 'package:on_role/services/geofence_benchmark.dart';
import 'package:on_role/services/geofence_engine.dart';
import 'package:on_role/services/synthetic_trajectories.dart';

void main() {
  final start = DateTime(2026, 11, 6, 20);
  DateTime at(int seconds) => start.add(Duration(seconds: seconds));

  group('rastreador de check-in', () {
    // Dois bares a ~60 m um do outro, com cercas de 50 m sobrepostas.
    const a = LatLng(-19.5300, -40.6620);
    final b = const Distance().offset(a, 60, 90);

    CheckInTracker tracker() => CheckInTracker(
          GeofenceEngine(
            fences: [
              const Geofence(id: 'a', center: a, radiusMeters: 50),
              Geofence(id: 'b', center: b, radiusMeters: 50),
            ],
            config: const GeofenceConfig(dwellTime: Duration(minutes: 2), stillRadiusMeters: null),
          ),
        );

    LocationFix fix(LatLng position, int seconds) =>
        LocationFix(position: position, accuracyMeters: 5, timestamp: at(seconds));

    test('faz check-in depois da permanência e check-out ao sair', () {
      final t = tracker();
      expect(t.process(fix(a, 0)).changes, isEmpty);
      expect(t.tick(at(60)).changes, isEmpty);
      expect(t.tick(at(121)).changes, [(venueId: 'a', checkedIn: true, at: at(121))]);

      final away = const Distance().offset(a, 300, 270);
      t.process(fix(away, 200));
      expect(t.tick(at(261)).changes, [(venueId: 'a', checkedIn: false, at: at(261))]);
      expect(t.venueId, isNull);
    });

    test('com duas cercas em permanência, vai para o local mais perto', () {
      final t = tracker();
      // A 15 m de "b" e 45 m de "a": dentro das duas.
      t.process(fix(const Distance().offset(b, 15, 270), 0));
      final step = t.tick(at(121));
      expect(step.changes.map((change) => change.venueId), ['b']);
    });

    test('checkOut encerra o check-in atual', () {
      final t = tracker();
      t.process(fix(a, 0));
      t.tick(at(121));
      expect(t.checkOut(at(130)), (venueId: 'a', checkedIn: false, at: at(130)));
      expect(t.checkOut(at(140)), isNull);
    });
  });

  test('sair de um bar dentro de uma praça faz check-in na praça depois de parar', () {
    // Como o Bharem dentro da cerca da Área Verde: a pessoa sai do bar e vai
    // ao centro da praça sem nunca sair da cerca dela.
    const praca = LatLng(-19.5276, -40.6195);
    final bar = const Distance().offset(praca, 100, 0);
    final t = CheckInTracker(
      GeofenceEngine(fences: [
        const Geofence(id: 'praca', center: praca, radiusMeters: 120),
        Geofence(id: 'bar', center: bar, radiusMeters: 50),
      ]),
    );
    final changes = <CheckInChange>[];
    void run(LatLng position, int from, int to) {
      for (var s = from; s < to; s += 10) {
        changes
          ..addAll(t.process(LocationFix(position: position, accuracyMeters: 5, timestamp: at(s))).changes)
          ..addAll(t.tick(at(s)).changes);
      }
    }

    run(bar, 0, 600);
    expect(t.venueId, 'bar');
    run(praca, 600, 1200);
    expect(t.venueId, 'praca');
    expect(changes.map((change) => (change.venueId, change.checkedIn)), [
      ('bar', true),
      ('bar', false),
      ('praca', true),
    ]);
  });

  group('trajetos sintéticos', () {
    test('a mesma semente gera o mesmo trajeto', () {
      final first = TrajectoryGenerator(venues: venueCatalog, seed: 5).night();
      final second = TrajectoryGenerator(venues: venueCatalog, seed: 5).night();
      expect(second.fixes.length, first.fixes.length);
      expect(second.fixes.last.position, first.fixes.last.position);
      expect(second.visits.map((visit) => visit.venueId), first.visits.map((visit) => visit.venueId));
    });

    test('cada noite tem de 2 a 4 visitas, com leituras em ordem e filtro de distância', () {
      final generator = TrajectoryGenerator(venues: venueCatalog, seed: 2);
      for (var i = 0; i < 20; i++) {
        final night = generator.night();
        expect(night.visits.length, inInclusiveRange(2, 4));
        for (final visit in night.visits) {
          expect(visit.leftAt.difference(visit.arrivedAt), greaterThanOrEqualTo(const Duration(minutes: 10)));
        }
        for (var f = 1; f < night.fixes.length; f++) {
          expect(night.fixes[f].timestamp.isAfter(night.fixes[f - 1].timestamp), isTrue);
          expect(haversineDistance(night.fixes[f].position, night.fixes[f - 1].position), greaterThanOrEqualTo(10));
        }
      }
    });

    test('sem erro de GPS, toda visita é detectada no local certo', () {
      final report = GeofenceReport.run(
        venues: venueCatalog,
        nights: 30,
        seed: 3,
        noise: const GpsNoiseModel(
          outdoorAccuracyMeters: 0,
          indoorAccuracyMeters: 0,
          outlierChance: 0,
        ),
      );
      expect(report.score.visits, greaterThan(60));
      expect(report.score.recall, 1);
      expect(report.score.fragments, 0);
      expect(report.toMarkdown(), contains('Transições corretas'));
    });
  });

  group('comparação com o gabarito', () {
    final visits = [
      TruthVisit(venueId: 'a', arrivedAt: at(0), leftAt: at(3600)),
      TruthVisit(venueId: 'b', arrivedAt: at(5000), leftAt: at(7000)),
    ];
    final night = SyntheticNight(start: at(-600), end: at(8000), fixes: const [], visits: visits, passBys: 1, shortStops: 0);

    test('separa detecção, fragmentação e check-ins falsos', () {
      final score = GeofenceScore()
        ..addNight(night, [
          CheckInSession(venueId: 'c', start: at(-300), end: at(-200)), // passagem
          CheckInSession(venueId: 'a', start: at(100), end: at(1800)), // detectou, saiu cedo
          CheckInSession(venueId: 'x', start: at(1900), end: at(2000)), // vizinho
          CheckInSession(venueId: 'a', start: at(2100), end: at(3700)), // fragmentação
          CheckInSession(venueId: 'b', start: at(5100), end: at(7120)), // certo
        ]);
      expect(score.detected, 2);
      expect(score.missed, 0);
      expect(score.checkOutsOnTime, 1);
      expect(score.fragments, 1);
      expect(score.falseNeighbor, 1);
      expect(score.falsePassing, 1);
      expect(score.precision, 2 / 5);
      // (2 entradas + 1 saída certas) / (4 esperadas + 2 x 3 erradas).
      expect(score.transitionAccuracy, closeTo(3 / 10, 1e-9));
      expect(score.checkInDelays, [100, 100]);
    });

    test('sessões vêm das mudanças de check-in, fechando a que ficou aberta', () {
      final sessions = sessionsFrom([
        (venueId: 'a', checkedIn: true, at: at(0)),
        (venueId: 'a', checkedIn: false, at: at(10)),
        (venueId: 'b', checkedIn: true, at: at(20)),
      ], closeAt: at(99));
      expect([for (final s in sessions) (s.venueId, s.start, s.end)], [('a', at(0), at(10)), ('b', at(20), at(99))]);
    });
  });

  group('demonstração', () {
    test('a lotação sintética fica em torno da média de cada local', () {
      final crowd = SyntheticCrowd(baseline: demoCrowdBaseline, seed: 4);
      final sums = <String, int>{};
      const steps = 2000;
      for (var i = 0; i < steps; i++) {
        crowd.step();
        for (final id in demoCrowdBaseline.keys) {
          sums[id] = (sums[id] ?? 0) + crowd.countAt(id);
        }
      }
      for (final entry in demoCrowdBaseline.entries) {
        expect(sums[entry.key]! / steps, closeTo(entry.value, entry.value * 0.3 + 3));
      }
    });

    test('o banco da demonstração tem só o visitante e pessoas sintéticas', () {
      final db = MockDatabase.demo();
      final account = db.accountFor(demoGuestEmail)!;
      expect(account.userId, 'visitante');
      expect(db.accountFor('demo@onrole.com'), isNull);
      expect(db.users.length, 31);
      expect(db.users.where((user) => user.id != 'visitante').every((user) => user.id.startsWith('sintetico-')), isTrue);
      expect(db.posts, isNotEmpty);
      final likedGuest = db.users.where((user) => db.swipeOf(user.id, 'visitante')?.decision == SwipeDecision.like);
      expect(likedGuest, isNotEmpty);
      expect(likedGuest.length, lessThan(30));
    });

    test('sem GPS, a presença começa simulada e não pede permissão', () async {
      final repositories = createMockRepositories(database: MockDatabase.demo());
      final presence = PresenceProvider(repository: repositories.presence, gpsEnabled: false);
      // Sem nenhum canal do geolocator simulado: se o GPS fosse chamado, o
      // teste quebraria com MissingPluginException.
      await presence.start(userId: 'visitante');
      expect(presence.isSimulating, isTrue);
      expect(presence.availability, isNotNull);

      await presence.setSimulating(false);
      expect(presence.isSimulating, isTrue);
      await presence.stop();
      presence.dispose();
    });
  });
}
