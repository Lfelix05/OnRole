import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/data/mock/mock_database.dart';
import 'package:on_role/data/mock/mock_repositories.dart';
import 'package:on_role/main.dart';
import 'package:on_role/models/media.dart';
import 'package:on_role/theme/app_widgets.dart';
import 'package:on_role/view/widgets/media_view.dart';

const _invite = 'Quer participar do experimento do TCC?';

/// Plugins que o início usa: GPS desligado, bateria em 80% e aparelho sem
/// detalhes (no teste, os plugins de verdade nunca respondem).
void _mockPlugins(WidgetTester tester) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/geolocator'),
    (call) async => call.method == 'isLocationServiceEnabled' ? false : null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/battery'),
    (call) async => call.method == 'getBatteryLevel' ? 80 : 'discharging',
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/device_info'),
    (call) async => throw PlatformException(code: 'indisponivel'),
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('abre na tela de boas-vindas', (tester) async {
    await tester.pumpWidget(MainApp(repositories: createMockRepositories()));
    // A primeira resposta sobre a sessão chega de forma assíncrona.
    await tester.pump();

    expect(find.text('OnRolê'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
  });

  group('convite para o experimento', () {
    testWidgets('aparece ao cadastrar uma conta e inscreve quem aceita', (
      tester,
    ) async {
      _mockPlugins(tester);
      final db = MockDatabase();
      await tester.pumpWidget(
        MainApp(repositories: createMockRepositories(database: db)),
      );
      await tester.pump();

      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();
      Future<void> fill(String hint, String text) =>
          tester.enterText(find.widgetWithText(TextFormField, hint), text);
      await fill('seu_usuario', 'Bia');
      await fill('voce@email.com', 'bia@exemplo.com');
      await fill('••••••••', 'segredo1');
      await fill('Confirmar senha', 'segredo1');
      await tester.tap(find.text('Data de nascimento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final submit = find.widgetWithText(GradientButton, 'Criar conta');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await _pumpFrames(tester);

      expect(find.text(_invite), findsOneWidget);
      // Só fecha com uma escolha explícita.
      await tester.tapAt(const Offset(5, 5));
      await _pumpFrames(tester);
      expect(find.text(_invite), findsOneWidget);

      await tester.tap(find.text('Aceito participar'));
      await _pumpFrames(tester);
      expect(find.text(_invite), findsNothing);
      final userId = db.accountFor('bia@exemplo.com')!.userId;
      expect(db.isEnrolled(userId), isTrue);
      expect(
        find.text('Obrigado! Você está participando do experimento.'),
        findsOneWidget,
      );
      // A tela de cadastro saiu e ficou o início.
      expect(find.text('Procurar'), findsOneWidget);
    });

    testWidgets('quem já tem conta e entra não recebe o convite', (
      tester,
    ) async {
      _mockPlugins(tester);
      final repositories = createMockRepositories(database: MockDatabase());
      await repositories.auth.signIn(
        email: 'demo@onrole.com',
        password: '123456',
      );
      await tester.pumpWidget(MainApp(repositories: repositories));
      await _pumpFrames(tester);

      expect(find.text('Procurar'), findsOneWidget);
      expect(find.text(_invite), findsNothing);
    });
  });

  testWidgets('perfil: abre na grade de fotos e vídeos, textos na lista', (
    tester,
  ) async {
    _mockPlugins(tester);
    final db = MockDatabase();
    final repositories = createMockRepositories(database: db);
    await repositories.auth.signIn(
      email: 'demo@onrole.com',
      password: '123456',
    );
    // PNG de 1x1 pixel.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    final photo = await repositories.media.upload(
      ownerId: 'demo-user',
      draft: MediaDraft(
        bytes: png,
        kind: MediaKind.image,
        mimeType: 'image/png',
        aspectRatio: 1,
      ),
    );
    await repositories.posts.addPost(
      author: db.findUserById('demo-user')!,
      text: 'Foto do rolê',
      media: [photo],
    );

    // Tela de celular: o cabeçalho do perfil ocupa boa parte da altura.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MainApp(repositories: repositories));
    await _pumpFrames(tester);
    await tester.tap(find.text('Perfil'));
    await _pumpFrames(tester);
    final profileScroll = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );

    // Abre em "Fotos e vídeos": só o post com foto.
    const textPost = 'Sextou no centro! Quem tá na rua hoje?';
    await tester.scrollUntilVisible(
      find.byType(MediaImage),
      200,
      scrollable: profileScroll,
    );
    expect(find.byType(MediaImage), findsOneWidget);
    expect(find.text(textPost), findsNothing);

    // Lista: só o post de texto (o seletor fica fixo no topo).
    await tester.tap(find.byIcon(Icons.reorder));
    await _pumpFrames(tester);
    expect(find.text(textPost), findsOneWidget);
    expect(find.text('Foto do rolê'), findsNothing);
    expect(find.byType(MediaImage), findsNothing);
  });

  testWidgets('tocar no autor do post abre o perfil, onde dá para conectar', (
    tester,
  ) async {
    _mockPlugins(tester);
    final db = MockDatabase();
    final repositories = createMockRepositories(database: db);
    await repositories.auth.signIn(
      email: 'demo@onrole.com',
      password: '123456',
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MainApp(repositories: repositories));
    await _pumpFrames(tester);

    // O Pedro ainda não é uma conexão do usuário demo.
    final author = find.text('Pedro Lima');
    await tester.ensureVisible(author);
    await tester.tap(author);
    await _pumpFrames(tester);
    expect(find.text('@pedrolima'), findsWidgets);
    expect(find.byIcon(Icons.grid_on), findsOneWidget);

    await tester.tap(find.text('Conectar'));
    await _pumpFrames(tester);
    expect(find.text('Conectado'), findsOneWidget);
    expect(db.followingOf('demo-user'), contains('pedro'));

    // Tocar de novo desfaz.
    await tester.tap(find.text('Conectado'));
    await _pumpFrames(tester);
    expect(find.text('Conectar'), findsOneWidget);
    expect(db.followingOf('demo-user'), isNot(contains('pedro')));
  });

  testWidgets('busca filtra pessoas e não mostra posts de texto', (
    tester,
  ) async {
    _mockPlugins(tester);
    final repositories = createMockRepositories(database: MockDatabase());
    await repositories.auth.signIn(
      email: 'demo@onrole.com',
      password: '123456',
    );
    await tester.pumpWidget(MainApp(repositories: repositories));
    await _pumpFrames(tester);
    await tester.tap(find.text('Procurar'));
    await _pumpFrames(tester);

    // Sem busca: as pessoas aparecem, os posts de texto do feed não.
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.textContaining('Alguém topa'), findsNothing);

    // "forro" (sem acento) acha a Júlia pelo gosto de rolê "Forró".
    await tester.enterText(find.byType(TextField), 'forro');
    await _pumpFrames(tester);
    expect(find.text('Júlia Rocha'), findsOneWidget);
    expect(find.text('Ana Souza'), findsNothing);

    await tester.enterText(find.byType(TextField), 'ninguem tem isso');
    await _pumpFrames(tester);
    expect(
      find.text('Nada encontrado para "ninguem tem isso".'),
      findsOneWidget,
    );
  });
}
