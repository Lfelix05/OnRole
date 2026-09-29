import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:latlong2/latlong.dart';

/// Ponto de entrada do mapa de calor. O app nunca recebe a posição crua de
/// outros usuários: cada ponto é uma contagem já agregada por região, com
/// [weight] = número de pessoas.
class HeatPoint {
  const HeatPoint(this.position, this.weight);

  final LatLng position;
  final double weight;
}

/// Grade raster com a densidade estimada em cada nó. O nó (coluna, linha)
/// fica na posição (coluna × cellSize, linha × cellSize) da tela.
class DensityGrid {
  DensityGrid({
    required this.columns,
    required this.rows,
    required this.cellSize,
    required this.values,
  }) : assert(values.length == columns * rows);

  final int columns;
  final int rows;
  final double cellSize;
  final Float32List values;

  double valueAt(int column, int row) => values[row * columns + column];

  double get maxValue {
    var max = 0.0;
    for (final value in values) {
      if (value > max) max = value;
    }
    return max;
  }
}

/// Estimativa de densidade por kernel (KDE) com kernel gaussiano, avaliada
/// numa grade sobre a tela:
///
///   f(x) = Σ wᵢ · exp(−‖x − xᵢ‖² / 2h²)
///
/// onde xᵢ são os pontos já projetados em pixels, wᵢ os pesos e h a largura
/// de banda ([bandwidth], em pixels). O kernel não é normalizado: o pico de
/// um único ponto vale o próprio peso, então f(x) se lê como "quantas pessoas
/// há por perto", independente do zoom.
///
/// Cada ponto só é somado nos nós a até 3h de distância, onde o kernel ainda
/// vale mais de 1% (exp(−4,5) ≈ 0,011). O custo fica proporcional ao número
/// de pontos, e não a pontos × área da tela.
DensityGrid estimateDensity({
  required List<Offset> points,
  required List<double> weights,
  required Size size,
  required double bandwidth,
  required double cellSize,
}) {
  assert(points.length == weights.length);
  assert(bandwidth > 0 && cellSize > 0);

  final columns = (size.width / cellSize).ceil() + 1;
  final rows = (size.height / cellSize).ceil() + 1;
  final values = Float32List(columns * rows);
  final reach = 3 * bandwidth;
  final twoBandwidthSquared = 2 * bandwidth * bandwidth;

  for (var i = 0; i < points.length; i++) {
    final point = points[i];
    final weight = weights[i];
    final firstColumn = math.max(0, ((point.dx - reach) / cellSize).floor());
    final lastColumn = math.min(columns - 1, ((point.dx + reach) / cellSize).ceil());
    final firstRow = math.max(0, ((point.dy - reach) / cellSize).floor());
    final lastRow = math.min(rows - 1, ((point.dy + reach) / cellSize).ceil());

    for (var row = firstRow; row <= lastRow; row++) {
      final dy = row * cellSize - point.dy;
      for (var column = firstColumn; column <= lastColumn; column++) {
        final dx = column * cellSize - point.dx;
        values[row * columns + column] += weight * math.exp(-(dx * dx + dy * dy) / twoBandwidthSquared);
      }
    }
  }

  return DensityGrid(columns: columns, rows: rows, cellSize: cellSize, values: values);
}
