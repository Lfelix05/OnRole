import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/services/kernel_density.dart';

void main() {
  // Tela de 100×100 px com nós a cada 5 px: o nó (10, 10) fica em (50, 50).
  DensityGrid estimate(List<Offset> points, List<double> weights) {
    return estimateDensity(
      points: points,
      weights: weights,
      size: const Size(100, 100),
      bandwidth: 10,
      cellSize: 5,
    );
  }

  test('o pico de um ponto isolado vale o próprio peso', () {
    final grid = estimate(const [Offset(50, 50)], const [7]);

    expect(grid.valueAt(10, 10), closeTo(7, 1e-4));
    expect(grid.maxValue, closeTo(7, 1e-4));
  });

  test('decai como uma gaussiana e é simétrico', () {
    final grid = estimate(const [Offset(50, 50)], const [1]);

    // A 10 px (uma largura de banda) do ponto: exp(-1/2).
    expect(grid.valueAt(12, 10), closeTo(math.exp(-0.5), 1e-4));
    expect(grid.valueAt(8, 10), closeTo(grid.valueAt(12, 10), 1e-6));
    expect(grid.valueAt(10, 12), closeTo(grid.valueAt(12, 10), 1e-6));
  });

  test('não calcula nada além de 3 larguras de banda', () {
    final grid = estimate(const [Offset(50, 50)], const [1]);

    expect(grid.valueAt(0, 0), 0);
  });

  test('densidades de pontos próximos se somam', () {
    final grid = estimate(const [Offset(50, 50), Offset(50, 50)], const [2, 3]);

    expect(grid.maxValue, closeTo(5, 1e-4));
  });

  test('ponto logo fora da tela ainda aquece a borda', () {
    final grid = estimate(const [Offset(-10, 50)], const [1]);

    expect(grid.valueAt(0, 10), closeTo(math.exp(-0.5), 1e-4));
  });

  test('ponto muito longe da tela é ignorado', () {
    final grid = estimate(const [Offset(-500, -500)], const [1]);

    expect(grid.maxValue, 0);
  });
}
