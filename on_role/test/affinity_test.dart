import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/models/match.dart';
import 'package:on_role/models/user.dart';
import 'package:on_role/services/affinity.dart';
import 'package:on_role/services/frame_stats.dart';

User person(
  String id, {
  Map<String, int> visits = const {},
  List<String> interests = const [],
}) => User(id: id, name: id, visits: visits, interests: interests);

void main() {
  group('Jaccard', () {
    test('ponderado: soma dos mínimos sobre a soma dos máximos', () {
      expect(weightedJaccard({'a': 3, 'b': 1}, {'a': 1, 'c': 2}), 1 / 6);
      expect(weightedJaccard({'a': 2}, {'a': 2}), 1);
      expect(weightedJaccard({'a': 2}, {'b': 2}), 0);
      expect(weightedJaccard({}, {}), 0);
    });

    test('simples: interseção sobre união', () {
      expect(jaccard({'Bar', 'Rock'}, {'Bar', 'Funk', 'MPB'}), 1 / 4);
      expect(jaccard({}, {}), 0);
    });
  });

  group('afinidade', () {
    test('combina locais (70%) e gostos (30%)', () {
      final me = person('eu', visits: {'boteco': 2}, interests: ['Bar']);
      final other = person(
        'outro',
        visits: {'boteco': 1},
        interests: ['Bar', 'Rock'],
      );
      final affinity = affinityBetween(me, other);

      expect(affinity.venueSimilarity, 0.5);
      expect(affinity.interestSimilarity, 0.5);
      expect(affinity.score, closeTo(0.7 * 0.5 + 0.3 * 0.5, 1e-9));
      expect(affinity.sharedVenueIds, ['boteco']);
      expect(affinity.sharedInterests, ['Bar']);
    });

    test('sem histórico de um dos lados, usa só o sinal que existe', () {
      final onlyInterests = affinityBetween(
        person('eu', interests: ['Bar']),
        person('outro', visits: {'boteco': 1}, interests: ['Bar']),
      );
      expect(onlyInterests.score, 1);

      final onlyVenues = affinityBetween(
        person('eu', visits: {'boteco': 1}),
        person('outro', visits: {'boteco': 1}, interests: ['Bar']),
      );
      expect(onlyVenues.score, 1);

      expect(affinityBetween(person('eu'), person('outro')).score, 0);
    });

    test('locais em comum vêm do mais frequentado pelos dois', () {
      final affinity = affinityBetween(
        person('eu', visits: {'praca': 1, 'boteco': 5, 'lounge': 3}),
        person('outro', visits: {'praca': 4, 'boteco': 2, 'lounge': 3}),
      );
      expect(affinity.sharedVenueIds, ['lounge', 'boteco', 'praca']);
    });
  });

  group('fila de sugestões', () {
    final me = person('eu', visits: {'boteco': 3}, interests: ['Bar']);
    final others = [
      me,
      person('alta', visits: {'boteco': 3}, interests: ['Bar']),
      person('media', visits: {'boteco': 1}),
      person('baixa', interests: ['Bar', 'Rock', 'Funk']),
      person('zero', visits: {'praca': 2}),
      person('ja-vista', visits: {'boteco': 3}, interests: ['Bar']),
    ];

    List<MatchCandidate> deck([int seed = 1]) => buildDeck(
      me: me,
      others: others,
      alreadySwiped: {'ja-vista'},
      random: math.Random(seed),
    );

    test('não sugere a própria pessoa nem quem já foi avaliado', () {
      final ids = deck().map((candidate) => candidate.user.id);
      expect(ids, unorderedEquals(['alta', 'media', 'baixa', 'zero']));
    });

    test('alterna afinidade e controle, começando pela maior afinidade', () {
      for (var seed = 0; seed < 20; seed++) {
        final candidates = deck(seed);
        expect(candidates.first.user.id, 'alta');
        expect(candidates.map((candidate) => candidate.source), [
          SuggestionSource.afinidade,
          SuggestionSource.controle,
          SuggestionSource.afinidade,
          SuggestionSource.controle,
        ]);
        // Cada sugestão por afinidade é a maior entre as que sobraram.
        final remaining = {...candidates};
        for (final candidate in candidates) {
          if (candidate.source == SuggestionSource.afinidade) {
            final best = remaining
                .map((item) => item.affinity.score)
                .reduce(math.max);
            expect(candidate.affinity.score, best);
          }
          remaining.remove(candidate);
        }
      }
    });
  });

  group('quadros (H4)', () {
    FrameSample frame(int buildMs, int rasterMs) => (
      build: Duration(milliseconds: buildMs),
      raster: Duration(milliseconds: rasterMs),
    );

    test('sem quadros, sem resumo', () {
      expect(summarizeFrames(const []), isNull);
    });

    test('o custo do quadro é o maior entre construção e rasterização', () {
      final stats = summarizeFrames([
        for (var i = 0; i < 9; i++) frame(4, 8),
        frame(30, 10),
      ])!;
      expect(stats.frames, 10);
      expect(stats.avgBuildMs, closeTo(6.6, 1e-9));
      expect(stats.avgRasterMs, closeTo(8.2, 1e-9));
      expect(stats.p90FrameMs, 8);
      expect(stats.jankRatio, 0.1);
      expect(stats.toJson()['avgBuildMs'], 6.6);
    });
  });
}
