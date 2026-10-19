import 'dart:math' as math;

/// Orçamento de um quadro a 60 FPS.
const frameBudget = Duration(microseconds: 16667);

/// Desempenho de renderização numa janela de tempo (H4). No Flutter a
/// construção (UI) e a rasterização (GPU) correm em paralelo, então o custo
/// de um quadro é o maior dos dois.
class FrameStats {
  const FrameStats({
    required this.frames,
    required this.avgBuildMs,
    required this.avgRasterMs,
    required this.p90FrameMs,
    required this.jankRatio,
  });

  final int frames;
  final double avgBuildMs;
  final double avgRasterMs;

  /// 90% dos quadros ficaram abaixo disto.
  final double p90FrameMs;

  /// Fração dos quadros acima de [frameBudget] (perderam os 60 FPS).
  final double jankRatio;

  Map<String, Object> toJson() => {
    'frames': frames,
    'avgBuildMs': _round(avgBuildMs),
    'avgRasterMs': _round(avgRasterMs),
    'p90FrameMs': _round(p90FrameMs),
    'jankRatio': _round(jankRatio),
  };

  static double _round(double value) => (value * 100).round() / 100;
}

typedef FrameSample = ({Duration build, Duration raster});

FrameStats? summarizeFrames(List<FrameSample> samples) {
  if (samples.isEmpty) return null;
  double ms(Duration duration) => duration.inMicroseconds / 1000;

  final costs = [
    for (final sample in samples)
      ms(sample.build > sample.raster ? sample.build : sample.raster),
  ]..sort();
  final p90Index = math.min(costs.length - 1, (costs.length * 0.9).ceil() - 1);
  final budgetMs = ms(frameBudget);

  return FrameStats(
    frames: samples.length,
    avgBuildMs:
        samples.map((sample) => ms(sample.build)).reduce((a, b) => a + b) /
        samples.length,
    avgRasterMs:
        samples.map((sample) => ms(sample.raster)).reduce((a, b) => a + b) /
        samples.length,
    p90FrameMs: costs[p90Index],
    jankRatio: costs.where((cost) => cost > budgetMs).length / costs.length,
  );
}
