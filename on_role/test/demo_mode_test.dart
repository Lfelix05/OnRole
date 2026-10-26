// Só roda na versão de demonstração:
//   flutter test --dart-define=MODE=demo test/demo_mode_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/app_mode.dart';
import 'package:on_role/data/mock/mock_database.dart';
import 'package:on_role/data/mock/mock_repositories.dart';
import 'package:on_role/data/venue_catalog.dart';
import 'package:on_role/main.dart';
import 'package:on_role/services/crowd_simulator.dart';

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'entra sem cadastro, com Conexões e simulação, sem pedir localização',
    (tester) async {
      // Nenhum canal de plugin simulado: se o app chamasse o GPS, a bateria
      // ou o Firebase, o teste quebraria.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MainApp(
        repositories: createMockRepositories(
          database: MockDatabase.demo(),
          simulator: SyntheticCrowd(baseline: demoCrowdBaseline, seed: 1),
        ),
      ));
      await tester.pump();

      expect(find.text('Criar conta'), findsNothing);
      expect(find.textContaining('versão de demonstração'), findsOneWidget);
      await tester.tap(find.text('Explorar a demonstração'));
      await _pumpFrames(tester);

      expect(find.text('Conexões'), findsOneWidget);
      await tester.tap(find.text('Mapa'));
      await _pumpFrames(tester);
      expect(find.textContaining('Demonstração: toque no mapa'), findsOneWidget);
      expect(find.byTooltip('Modo simulação'), findsNothing);

      await tester.tap(find.text('Perfil'));
      await _pumpFrames(tester);
      expect(find.text('Demonstração · dados fictícios'), findsOneWidget);
      expect(find.byTooltip('Bancada de testes'), appMode.hasBench ? findsOneWidget : findsNothing);
    },
    skip: !appMode.isDemo,
  );
}
