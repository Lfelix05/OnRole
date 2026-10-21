import 'dart:math' as math;

/// Simula a lotação de cada local enquanto o back-end não existe: um passeio
/// aleatório que sempre volta para perto da média de cada local, para o mapa
/// "respirar" como se recebesse atualizações em tempo real.
///
/// Quando o back-end existir, esta classe sai e as contagens passam a vir de
/// um stream (Firestore/WebSocket) com os check-ins reais agregados.
class CrowdSimulator {
  CrowdSimulator({required Map<String, int> baseline, int? seed})
      : _baseline = Map.unmodifiable(baseline),
        _counts = Map.of(baseline),
        _random = math.Random(seed);

  final Map<String, int> _baseline;
  final Map<String, int> _counts;
  final math.Random _random;

  int countAt(String venueId) => _counts[venueId] ?? 0;

  void step() {
    for (final entry in _baseline.entries) {
      final current = _counts[entry.key]!;
      final pullToBaseline = ((entry.value - current) * 0.2).round();
      final noise = _random.nextInt(7) - 3;
      _counts[entry.key] = math.max(0, current + pullToBaseline + noise);
    }
  }
}
