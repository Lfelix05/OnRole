import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/main.dart';

void main() {
  testWidgets('abre na tela de boas-vindas', (tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.text('OnRolê'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
  });
}
