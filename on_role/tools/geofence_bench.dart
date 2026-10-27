// Bancada de precisão das geocercas (H2) com trajetos sintéticos, fora do
// aparelho. Usa o mesmo CheckInTracker do app.
//
//   dart run tools/geofence_bench.dart                 200 noites, semente 1, parâmetros do app
//   dart run tools/geofence_bench.dart --nights 1000 --seed 7
//   dart run tools/geofence_bench.dart --seeds 5       sementes 1 a 5: média e desvio-padrão
//   dart run tools/geofence_bench.dart --dwell 300     permanência de 5 min (padrão: 180)
//   dart run tools/geofence_bench.dart --exit 120 --hysteresis 40
//   dart run tools/geofence_bench.dart --still 45      detecção de parada (padrão: 30; 0 desliga)
//
// Imprime a tabela em Markdown, pronta para o capítulo de resultados.

import 'dart:math' as math;

import 'package:on_role/data/venue_catalog.dart';
import 'package:on_role/services/geofence_benchmark.dart';
import 'package:on_role/services/geofence_engine.dart';

void main(List<String> args) {
  int option(String name, int fallback) {
    final index = args.indexOf('--$name');
    if (index == -1 || index + 1 >= args.length) return fallback;
    return int.parse(args[index + 1]);
  }

  final config = GeofenceConfig(
    dwellTime: Duration(seconds: option('dwell', 180)),
    exitDelay: Duration(seconds: option('exit', 60)),
    exitHysteresisMeters: option('hysteresis', 25).toDouble(),
    stillRadiusMeters: option('still', 30) == 0 ? null : option('still', 30).toDouble(),
  );
  final firstSeed = option('seed', 1);
  final reports = [
    for (var seed = firstSeed; seed < firstSeed + option('seeds', 1); seed++)
      GeofenceReport.run(venues: venueCatalog, nights: option('nights', 200), seed: seed, config: config),
  ];
  // ignore: avoid_print
  print(reports.length == 1 ? reports.single.toMarkdown() : _summary(reports));
}

/// Média ± desvio-padrão amostral de cada métrica entre as sementes.
String _summary(List<GeofenceReport> reports) {
  String stat(double Function(GeofenceScore score) metric, {String unit = '%', double scale = 100}) {
    final values = [for (final report in reports) metric(report.score) * scale];
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / (values.length - 1);
    return '${mean.toStringAsFixed(1)}$unit ± ${math.sqrt(variance).toStringAsFixed(1)}';
  }

  double median(List<double> values) => percentiles(values)?.median ?? double.nan;
  final config = reports.first.config;
  final still = config.stillRadiusMeters;
  return [
    '### Precisão das geocercas com trajetos sintéticos (H2)',
    '',
    '${reports.length} sementes (${reports.first.seed} a ${reports.last.seed}), '
        '${reports.first.score.nights} noites cada. Média ± desvio-padrão entre as sementes.',
    'Geocerca: permanência ${config.dwellTime.inSeconds} s, saída ${config.exitDelay.inSeconds} s, '
        'histerese ${config.exitHysteresisMeters.round()} m, '
        '${still == null ? 'sem detecção de parada' : 'detecção de parada de ${still.round()} m'}.',
    '',
    '| Métrica | Valor |',
    '| --- | --- |',
    '| Transições corretas (meta > 95%) | ${stat((s) => s.transitionAccuracy)} |',
    '| Visitas detectadas (sensibilidade) | ${stat((s) => s.recall)} |',
    '| Check-ins certos (precisão) | ${stat((s) => s.precision)} |',
    '| Check-outs no tempo | ${stat((s) => s.detected == 0 ? 0 : s.checkOutsOnTime / s.detected)} |',
    '| Check-ins falsos por noite | ${stat((s) => s.falseCheckIns / s.nights, unit: '', scale: 1)} |',
    '| Atraso mediano do check-in | ${stat((s) => median(s.checkInDelays), unit: ' s', scale: 1)} |',
    '| Atraso mediano do check-out | ${stat((s) => median(s.checkOutDelays), unit: ' s', scale: 1)} |',
  ].join('\n');
}
