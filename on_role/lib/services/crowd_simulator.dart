import 'dart:math' as math;

/// De onde o modo mock tira a lotação de cada local.
abstract class CrowdSource {
  int countAt(String venueId);

  /// Avança um passo da simulação.
  void step();
}

/// Lotação inventada por um passeio aleatório que sempre volta para perto da
/// média de cada local, para o mapa "respirar" como se recebesse atualizações
/// em tempo real. Usado nos testes e no modo mock de desenvolvimento.
class CrowdSimulator implements CrowdSource {
  CrowdSimulator({required Map<String, int> baseline, int? seed})
      : _baseline = Map.unmodifiable(baseline),
        _counts = Map.of(baseline),
        _random = math.Random(seed);

  final Map<String, int> _baseline;
  final Map<String, int> _counts;
  final math.Random _random;

  @override
  int countAt(String venueId) => _counts[venueId] ?? 0;

  @override
  void step() {
    for (final entry in _baseline.entries) {
      final current = _counts[entry.key]!;
      final pullToBaseline = ((entry.value - current) * 0.2).round();
      final noise = _random.nextInt(7) - 3;
      _counts[entry.key] = math.max(0, current + pullToBaseline + noise);
    }
  }
}

/// Lotação da versão de demonstração, vinda de check-ins sintéticos: uma
/// população de pessoas fictícias em que cada uma, a cada passo, pode sair de
/// casa para um local (escolhido pela popularidade dele) ou ir embora do
/// local onde está. A contagem de cada local é o número de check-ins ativos
/// dessa população, do mesmo jeito que o servidor contaria os de gente de
/// verdade. Nenhum dado de pessoa real entra no mapa de calor.
///
/// Cadeia de Markov de dois estados por pessoa (em casa / num local): com
/// chance de sair [leaveChance] por passo, a permanência média é
/// 1 / [leaveChance] passos, e a chance de chegar é ajustada para que, no
/// equilíbrio, a lotação média de cada local seja a do [baseline].
class SyntheticCrowd implements CrowdSource {
  SyntheticCrowd({required Map<String, int> baseline, int? seed, this.leaveChance = 1 / 120})
      : _random = math.Random(seed) {
    final total = baseline.values.fold(0, (sum, count) => sum + count);
    final population = (total * 1.5).ceil();
    final outside = total / population;
    _arriveChance = leaveChance * outside / (1 - outside);
    _venueIds = baseline.keys.toList();
    _cumulative = [];
    var sum = 0;
    for (final count in baseline.values) {
      sum += count;
      _cumulative.add(sum);
    }
    // Começa já no equilíbrio, para o mapa não abrir vazio.
    _places = List.generate(population, (_) => _random.nextDouble() < outside ? _pickVenue() : null);
  }

  /// Chance de cada pessoa ir embora do local a cada passo.
  final double leaveChance;
  final math.Random _random;
  late final double _arriveChance;
  late final List<String> _venueIds;
  late final List<int> _cumulative;

  /// Onde cada pessoa sintética está (null: em casa).
  late final List<String?> _places;

  @override
  int countAt(String venueId) => _places.where((place) => place == venueId).length;

  @override
  void step() {
    for (var i = 0; i < _places.length; i++) {
      if (_places[i] == null) {
        if (_random.nextDouble() < _arriveChance) _places[i] = _pickVenue();
      } else if (_random.nextDouble() < leaveChance) {
        _places[i] = null;
      }
    }
  }

  String _pickVenue() {
    final target = _random.nextInt(_cumulative.last);
    for (var i = 0; i < _cumulative.length; i++) {
      if (target < _cumulative[i]) return _venueIds[i];
    }
    return _venueIds.last;
  }
}
