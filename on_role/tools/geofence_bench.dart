// Bancada de precisão das geocercas (H2) com trajetos sintéticos, fora do
// aparelho. Usa o mesmo CheckInTracker do app.
//
//   dart run tools/geofence_bench.dart                 200 noites, semente 1
//   dart run tools/geofence_bench.dart --nights 1000 --seed 7
//   dart run tools/geofence_bench.dart --dwell 300     permanência de 5 min
//
// Imprime a tabela em Markdown, pronta para o capítulo de resultados.

import 'package:on_role/data/venue_catalog.dart';
import 'package:on_role/services/geofence_benchmark.dart';
import 'package:on_role/services/geofence_engine.dart';

void main(List<String> args) {
  int option(String name, int fallback) {
    final index = args.indexOf('--$name');
    if (index == -1 || index + 1 >= args.length) return fallback;
    return int.parse(args[index + 1]);
  }

  final report = GeofenceReport.run(
    venues: venueCatalog,
    nights: option('nights', 200),
    seed: option('seed', 1),
    config: GeofenceConfig(dwellTime: Duration(seconds: option('dwell', 120))),
  );
  // ignore: avoid_print
  print(report.toMarkdown());
}
