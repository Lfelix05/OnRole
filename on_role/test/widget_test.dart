import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/data/mock/mock_repositories.dart';
import 'package:on_role/main.dart';

void main() {
  testWidgets('abre na tela de boas-vindas', (tester) async {
    await tester.pumpWidget(MainApp(repositories: createMockRepositories()));
    // A primeira resposta sobre a sessão chega de forma assíncrona.
    await tester.pump();

    expect(find.text('OnRolê'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
  });
}
