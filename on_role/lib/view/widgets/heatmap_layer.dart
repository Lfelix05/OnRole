import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/kernel_density.dart';

/// Camada de mapa de calor para o flutter_map, desenhada a partir da KDE.
///
/// A cada quadro os pontos são projetados na tela, a densidade é estimada numa
/// grade (ver [estimateDensity]) e a grade é pintada como uma malha de
/// triângulos com uma cor por vértice. A GPU interpola as cores entre os
/// vértices, então a mancha sai suave sem precisar de blur.
class HeatmapLayer extends StatelessWidget {
  const HeatmapLayer({
    super.key,
    required this.points,
    required this.saturation,
    this.bandwidthMeters = 70,
  });

  final List<HeatPoint> points;

  /// Densidade que já recebe a cor mais quente da escala.
  final double saturation;

  /// Largura de banda h do kernel, em metros no chão. Com ela maior que o
  /// espalhamento das células de um local, a mancha de cada local soma quase
  /// toda a lotação, e a cor fica estável ao mudar o zoom.
  final double bandwidthMeters;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: IgnorePointer(
        child: CustomPaint(
          size: camera.size,
          painter: _HeatmapPainter(
            camera: camera,
            points: points,
            saturation: saturation,
            bandwidthMeters: bandwidthMeters,
          ),
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.camera,
    required this.points,
    required this.saturation,
    required this.bandwidthMeters,
  });

  final MapCamera camera;
  final List<HeatPoint> points;
  final double saturation;
  final double bandwidthMeters;

  // Com o zoom afastado, a banda em metros vira poucos pixels e a mancha
  // ficaria escondida debaixo dos pinos; com o zoom próximo, ela cobriria a
  // tela. Os limites mantêm a leitura.
  static const double _minBandwidthPx = 24;
  static const double _maxBandwidthPx = 140;

  // Os índices da malha são Uint16, então cabem no máximo 65 536 vértices.
  static const int _maxVertices = 60000;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) return;

    final bandwidth = _metersToPixels(bandwidthMeters).clamp(_minBandwidthPx, _maxBandwidthPx);
    final cellSize = math.max(bandwidth / 3, math.sqrt(size.width * size.height / _maxVertices));

    final grid = estimateDensity(
      points: [for (final point in points) camera.getOffsetFromOrigin(point.position)],
      weights: [for (final point in points) point.weight],
      size: size,
      bandwidth: bandwidth,
      cellSize: cellSize,
    );

    final mesh = _buildMesh(grid);
    if (mesh == null) return;
    canvas.drawVertices(mesh, BlendMode.dst, Paint());
    mesh.dispose();
  }

  /// Quantos pixels correspondem a [meters] no centro da tela, no zoom atual.
  double _metersToPixels(double meters) {
    final center = camera.center;
    final south = const Distance().offset(center, meters, 180);
    return (camera.getOffsetFromOrigin(center) - camera.getOffsetFromOrigin(south)).distance;
  }

  ui.Vertices? _buildMesh(DensityGrid grid) {
    final columns = grid.columns;
    final rows = grid.rows;
    final positions = Float32List(columns * rows * 2);
    final colors = Int32List(columns * rows);

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final index = row * columns + column;
        positions[index * 2] = column * grid.cellSize;
        positions[index * 2 + 1] = row * grid.cellSize;
        final intensity = (grid.values[index] / saturation).clamp(0.0, 1.0);
        colors[index] = _colorRamp[(intensity * 255).round()];
      }
    }

    // Só entram na malha os quadrados com algum calor; o resto da tela fica
    // sem triângulos para a GPU desenhar.
    final threshold = saturation / 255;
    final indices = <int>[];
    for (var row = 0; row < rows - 1; row++) {
      for (var column = 0; column < columns - 1; column++) {
        final topLeft = row * columns + column;
        final topRight = topLeft + 1;
        final bottomLeft = topLeft + columns;
        final bottomRight = bottomLeft + 1;
        if (grid.values[topLeft] < threshold &&
            grid.values[topRight] < threshold &&
            grid.values[bottomLeft] < threshold &&
            grid.values[bottomRight] < threshold) {
          continue;
        }
        indices.addAll([topLeft, topRight, bottomLeft, topRight, bottomRight, bottomLeft]);
      }
    }
    if (indices.isEmpty) return null;

    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      colors: colors,
      indices: Uint16List.fromList(indices),
    );
  }

  @override
  bool shouldRepaint(_HeatmapPainter oldDelegate) {
    return oldDelegate.camera != camera ||
        oldDelegate.points != points ||
        oldDelegate.saturation != saturation ||
        oldDelegate.bandwidthMeters != bandwidthMeters;
  }
}

/// Escala de cores em 256 tons: transparente → roxo → rosa → laranja → amarelo.
final Int32List _colorRamp = _buildColorRamp();

Int32List _buildColorRamp() {
  // O "transparente" tem o mesmo tom do primeiro roxo: a cor interpolada na
  // borda da mancha não escurece.
  const stops = <(double, Color)>[
    (0.00, Color(0x006D28D9)),
    (0.15, Color(0x666D28D9)),
    (0.40, Color(0xB38B5CF6)),
    (0.65, Color(0xCCEC4899)),
    (0.85, Color(0xD9F97316)),
    (1.00, Color(0xE6FACC15)),
  ];

  final ramp = Int32List(256);
  var stop = 0;
  for (var i = 0; i < 256; i++) {
    final t = i / 255;
    while (stop < stops.length - 2 && t > stops[stop + 1].$1) {
      stop++;
    }
    final (t0, from) = stops[stop];
    final (t1, to) = stops[stop + 1];
    ramp[i] = Color.lerp(from, to, (t - t0) / (t1 - t0))!.toARGB32();
  }
  return ramp;
}
