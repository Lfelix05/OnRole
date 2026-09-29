import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/data/mock/mock_database.dart';
import 'package:on_role/data/mock/mock_repositories.dart';
import 'package:on_role/data/repositories.dart';
import 'package:on_role/data/venue_catalog.dart';
import 'package:on_role/models/check_in.dart';
import 'package:on_role/models/posts.dart';
import 'package:on_role/providers/auth_provider.dart';

/// Deixa os streams entregarem os eventos pendentes.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late MockDatabase db;
  late Repositories repositories;

  setUp(() {
    db = MockDatabase();
    repositories = createMockRepositories(database: db);
  });

  CheckIn checkInAt(String venueId, {String userId = 'demo-user'}) {
    return CheckIn(id: '$userId-$venueId', userId: userId, venueId: venueId, checkedInAt: DateTime.now());
  }

  group('login', () {
    late AuthProvider auth;

    setUp(() async {
      auth = AuthProvider(auth: repositories.auth, users: repositories.users);
      await settle();
    });

    tearDown(() => auth.dispose());

    test('começa deslogado e entra com a conta de demonstração', () async {
      expect(auth.isInitialized, isTrue);
      expect(auth.isLoggedIn, isFalse);

      expect(await auth.login(email: 'demo@onrole.com', password: '123456'), isNull);
      await settle();

      expect(auth.currentUser?.name, 'Convidado Demo');
    });

    test('explica o erro de senha ou e-mail errados', () async {
      expect(await auth.login(email: 'demo@onrole.com', password: 'errada'), 'Senha incorreta.');
      expect(await auth.login(email: 'ninguem@onrole.com', password: '123456'), 'Usuário não encontrado.');
      await settle();

      expect(auth.isLoggedIn, isFalse);
    });

    test('cadastro entra na conta nova e recusa e-mail repetido', () async {
      final error = await auth.register(
        name: 'Nova Pessoa',
        email: 'nova@onrole.com',
        password: 'segredo',
        birthDate: DateTime(2001, 5, 20),
      );
      await settle();

      expect(error, isNull);
      expect(auth.currentUser?.name, 'Nova Pessoa');
      expect(auth.otherUsers.map((user) => user.name), contains('Convidado Demo'));

      final repeated = await auth.register(
        name: 'Outra',
        email: 'NOVA@onrole.com',
        password: 'segredo',
        birthDate: DateTime(2001, 5, 20),
      );
      expect(repeated, 'Já existe uma conta com esse e-mail.');
    });

    test('logout encerra a sessão', () async {
      await auth.login(email: 'demo@onrole.com', password: '123456');
      await settle();
      await auth.logout();
      await settle();

      expect(auth.isLoggedIn, isFalse);
      expect(auth.otherUsers, isEmpty);
    });
  });

  group('posts', () {
    test('só publica com check-in ativo no mesmo local', () async {
      final author = db.findUserById('demo-user')!;

      await expectLater(
        repositories.posts.addPost(author: author, venueId: 'boteco-central', content: 'Oi!'),
        throwsStateError,
      );

      await repositories.presence.checkIn(checkInAt('boteco-central'));
      await expectLater(
        repositories.posts.addPost(author: author, venueId: 'praca-municipal', content: 'Oi!'),
        throwsStateError,
      );
      await repositories.posts.addPost(author: author, venueId: 'boteco-central', content: 'Oi!');

      final feed = await repositories.posts.watchFeed().first;
      expect(feed.first.content, 'Oi!');
      expect(feed.first.authorName, 'Convidado Demo');
      expect(feed.first.expiresAt.difference(feed.first.createdAt), postLifetime);
    });

    test('posts expirados saem do feed', () async {
      final longAgo = DateTime.now().subtract(const Duration(days: 1));
      db.addPost(Posts(
        id: 'velho',
        title: 'Ontem',
        content: 'Isso já passou.',
        type: PostType.text,
        authorId: 'demo-user',
        authorName: 'Convidado Demo',
        createdAt: longAgo,
        updatedAt: longAgo,
        expiresAt: longAgo.add(postLifetime),
      ));

      final feed = await repositories.posts.watchFeed().first;
      expect(feed.map((post) => post.id), isNot(contains('velho')));
    });
  });

  group('presença', () {
    test('check-in e check-out mudam a lotação do local', () async {
      const venueId = 'boteco-central';
      final baseline = demoCrowdBaseline[venueId]!;
      Future<int> crowd() async => (await repositories.presence.watchCrowd().first)[venueId]!;

      expect(await crowd(), baseline);

      final checkIn = checkInAt(venueId);
      await repositories.presence.checkIn(checkIn);
      expect(await crowd(), baseline + 1);

      checkIn.checkedOutAt = DateTime.now();
      await repositories.presence.checkOut(checkIn);
      expect(await crowd(), baseline);
    });

    test('cada check-in conta uma visita no perfil (base do match)', () async {
      await repositories.presence.checkIn(checkInAt('praca-municipal'));
      await repositories.presence.checkIn(checkInAt('praca-municipal', userId: 'demo-user'));

      expect(db.findUserById('demo-user')!.visits, {'praca-municipal': 2});
    });

    test('limpar a presença fecha check-ins que sobraram', () async {
      await repositories.presence.checkIn(checkInAt('area-eventos'));
      await repositories.presence.clearPresence('demo-user');

      expect(db.activeCheckInsAt('area-eventos'), 0);
    });
  });
}
