import 'dart:math' as math;

import '../models/match.dart';
import '../models/user.dart';

/// Peso dos locais frequentados na afinidade; o resto vem dos gostos de rolê.
const venueAffinityWeight = 0.7;

/// Afinidade entre duas pessoas (0 a 1) e o que elas têm em comum.
class Affinity {
  const Affinity({
    required this.score,
    required this.venueSimilarity,
    required this.interestSimilarity,
    required this.sharedVenueIds,
    required this.sharedInterests,
  });

  final double score;
  final double venueSimilarity;
  final double interestSimilarity;

  /// Locais que os dois frequentam, do mais frequentado em comum ao menos.
  final List<String> sharedVenueIds;
  final List<String> sharedInterests;
}

/// Jaccard ponderado sobre as visitas: Σ min(aᵢ, bᵢ) / Σ max(aᵢ, bᵢ). Quem
/// vai muito ao mesmo lugar pesa mais do que quem foi uma vez.
double weightedJaccard(Map<String, int> a, Map<String, int> b) {
  var minSum = 0;
  var maxSum = 0;
  for (final key in {...a.keys, ...b.keys}) {
    final x = a[key] ?? 0;
    final y = b[key] ?? 0;
    minSum += math.min(x, y);
    maxSum += math.max(x, y);
  }
  return maxSum == 0 ? 0 : minSum / maxSum;
}

/// Jaccard simples: |A ∩ B| / |A ∪ B|.
double jaccard(Set<String> a, Set<String> b) {
  final union = a.union(b);
  return union.isEmpty ? 0 : a.intersection(b).length / union.length;
}

Affinity affinityBetween(User me, User other) {
  final venues = weightedJaccard(me.visits, other.visits);
  final interests = jaccard(me.interests.toSet(), other.interests.toSet());

  // Sem histórico de um dos lados, a afinidade usa só o sinal que existe.
  final hasVenues = me.visits.isNotEmpty && other.visits.isNotEmpty;
  final hasInterests = me.interests.isNotEmpty && other.interests.isNotEmpty;
  final double score;
  if (hasVenues && hasInterests) {
    score =
        venueAffinityWeight * venues + (1 - venueAffinityWeight) * interests;
  } else if (hasVenues) {
    score = venues;
  } else if (hasInterests) {
    score = interests;
  } else {
    score = 0;
  }

  final sharedVenueIds = [
    for (final entry in me.visits.entries)
      if (entry.value > 0 && (other.visits[entry.key] ?? 0) > 0) entry.key,
  ];
  int inCommon(String venueId) =>
      math.min(me.visits[venueId]!, other.visits[venueId]!);
  sharedVenueIds.sort((a, b) => inCommon(b).compareTo(inCommon(a)));

  return Affinity(
    score: score,
    venueSimilarity: venues,
    interestSimilarity: interests,
    sharedVenueIds: sharedVenueIds,
    sharedInterests: [
      for (final interest in me.interests)
        if (other.interests.contains(interest)) interest,
    ],
  );
}

class MatchCandidate {
  const MatchCandidate({
    required this.user,
    required this.affinity,
    required this.source,
  });

  final User user;
  final Affinity affinity;
  final SuggestionSource source;
}

/// Fila de sugestões para a H3: alterna a pessoa de maior afinidade ainda não
/// sugerida com uma sorteada entre as restantes (grupo controle). Cada
/// participante vê os dois tipos, e a reciprocidade pode ser comparada entre
/// eles mesmo com poucos participantes.
List<MatchCandidate> buildDeck({
  required User me,
  required List<User> others,
  required Set<String> alreadySwiped,
  required math.Random random,
}) {
  final affinities = <String, Affinity>{};
  final pool = <User>[];
  for (final user in others) {
    if (user.id == me.id || alreadySwiped.contains(user.id)) continue;
    pool.add(user);
    affinities[user.id] = affinityBetween(me, user);
  }
  final ranked = [
    ...pool,
  ]..sort((a, b) => affinities[b.id]!.score.compareTo(affinities[a.id]!.score));

  final remaining = [...pool];
  final deck = <MatchCandidate>[];
  var byAffinity = true;
  while (remaining.isNotEmpty) {
    final User next;
    if (byAffinity) {
      next = ranked.firstWhere(remaining.contains);
    } else {
      next = remaining[random.nextInt(remaining.length)];
    }
    remaining.remove(next);
    deck.add(
      MatchCandidate(
        user: next,
        affinity: affinities[next.id]!,
        source: byAffinity
            ? SuggestionSource.afinidade
            : SuggestionSource.controle,
      ),
    );
    byAffinity = !byAffinity;
  }
  return deck;
}
