enum SwipeDecision { like, pass }

/// De onde veio a sugestão: ranqueada por afinidade ou sorteada (grupo
/// controle). É a variável do experimento da H3.
enum SuggestionSource {
  afinidade,
  controle;

  static SuggestionSource fromName(String? name) =>
      SuggestionSource.values.asNameMap()[name] ?? SuggestionSource.controle;
}

/// Decisão de uma pessoa sobre uma sugestão.
class Swipe {
  const Swipe({
    required this.fromId,
    required this.toId,
    required this.decision,
    required this.source,
    required this.score,
    required this.createdAt,
  });

  final String fromId;
  final String toId;
  final SwipeDecision decision;
  final SuggestionSource source;

  /// Afinidade calculada na hora da sugestão (0 a 1).
  final double score;
  final DateTime createdAt;
}

/// Curtida recíproca entre duas pessoas.
class UserMatch {
  const UserMatch({
    required this.id,
    required this.userIds,
    required this.createdAt,
  });

  /// Os dois ids em ordem alfabética, unidos por "_".
  final String id;
  final List<String> userIds;
  final DateTime createdAt;

  String otherUserId(String me) => userIds.firstWhere((id) => id != me);

  static String idFor(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }
}
