import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/data/mock/mock_database.dart';
import 'package:on_role/data/mock/mock_repositories.dart';
import 'package:on_role/data/repositories.dart';
import 'package:on_role/models/match.dart';
import 'package:on_role/providers/auth_provider.dart';
import 'package:on_role/providers/experiment_provider.dart';
import 'package:on_role/providers/match_provider.dart';

/// Deixa os streams e futures pendentes terminarem.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabase db;
  late Repositories repositories;
  late AuthProvider auth;

  setUp(() async {
    db = MockDatabase();
    repositories = createMockRepositories(database: db);
    auth = AuthProvider(auth: repositories.auth, users: repositories.users);
    await settle();
    await auth.login(email: 'demo@onrole.com', password: '123456');
    await settle();
  });

  tearDown(() => auth.dispose());

  group('conexões', () {
    late MatchProvider matches;

    setUp(() async {
      matches = MatchProvider(
        repository: repositories.matches,
        auth: auth,
        random: math.Random(7),
      );
      await settle();
    });

    tearDown(() => matches.dispose());

    test('a fila começa pela maior afinidade e alterna com o controle', () {
      expect(matches.isReady, isTrue);
      final deck = matches.deck;
      expect(
        deck.map((candidate) => candidate.user.id),
        isNot(contains('demo-user')),
      );
      // Ana frequenta o mesmo boteco e curte bar e samba, como o demo.
      expect(deck.first.user.id, 'ana');
      expect(deck.first.source, SuggestionSource.afinidade);
      expect(deck[1].source, SuggestionSource.controle);
    });

    test('curtir quem já curtiu vira match', () async {
      final ana = matches.deck.firstWhere((item) => item.user.id == 'ana');
      final match = await matches.decide(ana, SwipeDecision.like);
      await settle();

      expect(match?.id, 'ana_demo-user');
      expect(matches.matches.single.otherUserId('demo-user'), 'ana');
      final swipe = db.swipeOf('demo-user', 'ana')!;
      expect(swipe.source, SuggestionSource.afinidade);
      expect(swipe.score, greaterThan(0));
    });

    test('passar ou curtir sem reciprocidade não vira match', () async {
      final pedro = matches.deck.firstWhere((item) => item.user.id == 'pedro');
      expect(await matches.decide(pedro, SwipeDecision.pass), isNull);
      final julia = matches.deck.firstWhere((item) => item.user.id == 'julia');
      expect(await matches.decide(julia, SwipeDecision.like), isNull);
      await settle();
      expect(matches.matches, isEmpty);
    });

    test('quem já foi avaliado não volta para a fila', () async {
      final pedro = matches.deck.firstWhere((item) => item.user.id == 'pedro');
      await matches.decide(pedro, SwipeDecision.pass);
      expect(
        matches.deck.map((item) => item.user.id),
        isNot(contains('pedro')),
      );
      await settle();

      matches.refreshDeck();
      expect(
        matches.deck.map((item) => item.user.id),
        isNot(contains('pedro')),
      );
    });

    test('match é de mão dupla: a Ana também vê', () async {
      final ana = matches.deck.firstWhere((item) => item.user.id == 'ana');
      await matches.decide(ana, SwipeDecision.like);
      expect(db.matchesOf('ana').single.userIds, ['ana', 'demo-user']);
    });
  });

  group('experimento', () {
    late ExperimentProvider experiment;
    var batteryLevel = 90;

    setUp(() async {
      batteryLevel = 90;
      experiment = ExperimentProvider(
        repository: repositories.experiment,
        auth: auth,
        readBattery: () async => (level: batteryLevel, state: 'discharging'),
        readDevice: () async => {'platform': 'android', 'model': 'Teste'},
      );
      await settle();
    });

    tearDown(() => experiment.dispose());

    List<Map<String, Object?>> uploaded() => db.telemetryOf('demo-user');
    List<String> types() => [
      for (final event in uploaded()) event['type'] as String,
    ];

    test('sem consentimento, nada é registrado', () async {
      expect(experiment.isEnrolled, isFalse);
      experiment.log('geofence', {'venueId': 'bakhanas'});
      experiment.recordFix(accuracyMeters: 10, accepted: true);
      await experiment.flush();
      expect(experiment.pendingEvents, 0);
      expect(uploaded(), isEmpty);
    });

    test(
      'ao aceitar, registra o aparelho e a bateria e envia em lote',
      () async {
        expect(await experiment.setEnrolled(true), isNull);
        expect(db.isEnrolled('demo-user'), isTrue);
        experiment.log('check_in', {'venueId': 'bakhanas'});
        experiment.recordFix(accuracyMeters: 12, accepted: true);
        experiment.recordFix(accuracyMeters: 80, accepted: false);
        expect(experiment.pendingEvents, 3);

        await experiment.flush();
        expect(experiment.pendingEvents, 0);
        expect(types(), ['session', 'battery', 'check_in', 'gps']);
        expect(uploaded().first['model'], 'Teste');
        expect(uploaded()[1]['level'], 90);
        final gps = uploaded().last;
        expect(gps['fixes'], 2);
        expect(gps['rejected'], 1);
        expect(gps['avgAccuracy'], 46.0);
        // Nenhum evento carrega coordenadas.
        for (final event in uploaded()) {
          expect(event.keys, isNot(anyOf(contains('lat'), contains('lng'))));
        }
      },
    );

    test('o diário de campo marca chegada e saída na hora', () async {
      await experiment.setEnrolled(true);
      experiment.markGroundTruth(venueId: 'bakhanas', arrived: true);
      await settle();
      final diary = uploaded().where(
        (event) => event['type'] == 'ground_truth',
      );
      expect(diary.single['action'], 'arrived');
      expect(diary.single['venueId'], 'bakhanas');
      expect(diary.single['t'], isA<int>());
    });

    test('quem sai para de registrar e descarta o pendente', () async {
      await experiment.setEnrolled(true);
      await experiment.flush();
      experiment.log('check_in', {'venueId': 'bakhanas'});
      await experiment.setEnrolled(false);
      expect(experiment.pendingEvents, 0);
      experiment.log('check_out', {'venueId': 'bakhanas'});
      await experiment.flush();
      expect(types(), isNot(contains('check_in')));
      expect(types(), isNot(contains('check_out')));
    });

    test('apagar os dados remove o que foi enviado', () async {
      await experiment.setEnrolled(true);
      await experiment.flush();
      expect(uploaded(), isNotEmpty);
      expect(await experiment.deleteMyData(), isNull);
      expect(uploaded(), isEmpty);
    });

    test('a medição do mapa espera o consentimento', () async {
      experiment.startFrameSampling('map');
      expect(experiment.sampledScreen, isNull);
      await experiment.setEnrolled(true);
      expect(experiment.sampledScreen, 'map');
      experiment.stopFrameSampling();
      expect(experiment.sampledScreen, isNull);
    });

    test(
      'aceitar logo depois do cadastro não é desfeito pela leitura inicial',
      () async {
        final fresh = ExperimentProvider(
          repository: repositories.experiment,
          auth: auth,
          readBattery: () async => null,
          readDevice: () async => const {},
        );
        // Sem esperar a leitura do consentimento terminar.
        expect(await fresh.setEnrolled(true), isNull);
        await settle();
        expect(fresh.isEnrolled, isTrue);
        expect(db.isEnrolled('demo-user'), isTrue);
        fresh.dispose();
      },
    );

    test('o consentimento continua depois de reabrir o app', () async {
      await experiment.setEnrolled(true);
      final reopened = ExperimentProvider(
        repository: repositories.experiment,
        auth: auth,
        readBattery: () async => null,
        readDevice: () async => const {},
      );
      await settle();
      expect(reopened.isEnrolled, isTrue);
      reopened.dispose();
    });
  });
}
