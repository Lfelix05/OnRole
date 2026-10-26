import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/data/mock/mock_database.dart';
import 'package:on_role/data/mock/mock_repositories.dart';
import 'package:on_role/data/repositories.dart';
import 'package:on_role/models/match.dart';
import 'package:on_role/providers/auth_provider.dart';
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
}
