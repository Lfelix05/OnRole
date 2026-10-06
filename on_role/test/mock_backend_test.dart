import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/data/mock/mock_database.dart';
import 'package:on_role/data/mock/mock_repositories.dart';
import 'package:on_role/data/repositories.dart';
import 'package:on_role/data/venue_catalog.dart';
import 'package:on_role/models/check_in.dart';
import 'package:on_role/models/media.dart';
import 'package:on_role/models/story.dart';
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
    return CheckIn(
      id: '$userId-$venueId',
      userId: userId,
      venueId: venueId,
      checkedInAt: DateTime.now(),
    );
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

      expect(
        await auth.login(email: 'demo@onrole.com', password: '123456'),
        isNull,
      );
      await settle();

      expect(auth.currentUser?.name, 'Convidado Demo');
    });

    test('explica o erro de senha ou e-mail errados', () async {
      expect(
        await auth.login(email: 'demo@onrole.com', password: 'errada'),
        'Senha incorreta.',
      );
      expect(
        await auth.login(email: 'ninguem@onrole.com', password: '123456'),
        'Usuário não encontrado.',
      );
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
      expect(
        auth.otherUsers.map((user) => user.name),
        contains('Convidado Demo'),
      );

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
    test('qualquer pessoa logada posta, com ou sem local', () async {
      final author = db.findUserById('demo-user')!;

      await repositories.posts.addPost(author: author, text: 'Bora hoje?');
      await repositories.posts.addPost(
        author: author,
        text: 'Alguém no Boteco às 22h?',
        venueId: 'boteco-central',
      );

      final feed = await repositories.posts.watchFeed().first;
      expect(feed[0].text, 'Alguém no Boteco às 22h?');
      expect(feed[0].venueId, 'boteco-central');
      expect(feed[0].atVenue, isFalse);
      expect(feed[1].text, 'Bora hoje?');
    });

    test('o selo "no rolê agora" exige check-in ativo no local', () async {
      final author = db.findUserById('demo-user')!;

      await expectLater(
        repositories.posts.addPost(
          author: author,
          text: 'Tô aqui!',
          venueId: 'boteco-central',
          atVenue: true,
        ),
        throwsStateError,
      );

      await repositories.presence.checkIn(checkInAt('boteco-central'));
      await repositories.posts.addPost(
        author: author,
        text: 'Tô aqui!',
        venueId: 'boteco-central',
        atVenue: true,
      );
      final feed = await repositories.posts.watchFeed().first;
      expect(feed.first.atVenue, isTrue);
    });

    test('não aceita post vazio nem mais de $maxPostMedia mídias', () async {
      final author = db.findUserById('demo-user')!;
      const photo = MediaRef(
        id: 'm',
        kind: MediaKind.image,
        mimeType: 'image/jpeg',
        chunkCount: 1,
        aspectRatio: 1,
      );

      await expectLater(
        repositories.posts.addPost(author: author, text: '  '),
        throwsStateError,
      );
      await expectLater(
        repositories.posts.addPost(
          author: author,
          text: '',
          media: List.filled(maxPostMedia + 1, photo),
        ),
        throwsStateError,
      );
    });

    test('curtir e descurtir', () async {
      await repositories.posts.setLiked(
        postId: 'seed-demo',
        userId: 'ana',
        liked: true,
      );
      expect(db.findPost('seed-demo')!.isLikedBy('ana'), isTrue);

      await repositories.posts.setLiked(
        postId: 'seed-demo',
        userId: 'ana',
        liked: false,
      );
      expect(db.findPost('seed-demo')!.likeCount, 0);
    });

    test('responder conta no post', () async {
      final author = db.findUserById('demo-user')!;
      final before = db.findPost('seed-ana')!.replyCount;

      await repositories.posts.addReply(
        postId: 'seed-ana',
        author: author,
        text: 'Também vou!',
      );

      final replies = await repositories.posts.watchReplies('seed-ana').first;
      expect(replies.last.text, 'Também vou!');
      expect(db.findPost('seed-ana')!.replyCount, before + 1);
    });
  });

  group('mídia e stories', () {
    final bytes = Uint8List.fromList(List.generate(2000, (i) => i % 256));
    final draft = MediaDraft(
      bytes: bytes,
      kind: MediaKind.image,
      mimeType: 'image/jpeg',
      aspectRatio: 1.5,
    );

    test('sobe e baixa os mesmos bytes', () async {
      final ref = await repositories.media.upload(
        ownerId: 'demo-user',
        draft: draft,
      );

      expect(ref.aspectRatio, 1.5);
      expect(await repositories.media.load(ref), bytes);
    });

    test('recusa arquivos acima do limite', () async {
      final huge = MediaDraft(
        bytes: Uint8List(maxMediaBytes + 1),
        kind: MediaKind.video,
        mimeType: 'video/mp4',
        aspectRatio: 1,
      );

      await expectLater(
        repositories.media.upload(ownerId: 'demo-user', draft: huge),
        throwsA(isA<MediaException>()),
      );
    });

    test('story aparece por 24 h e depois entra na limpeza', () async {
      final author = db.findUserById('demo-user')!;
      final ref = await repositories.media.upload(
        ownerId: author.id,
        draft: draft,
      );
      await repositories.stories.addStory(author: author, media: ref);

      final active = await repositories.stories.watchActiveStories().first;
      expect(active.single.authorId, author.id);
      expect(
        active.single.expiresAt.difference(active.single.createdAt),
        storyLifetime,
      );
      expect(await repositories.stories.expiredStoriesOf(author.id), isEmpty);

      final old = DateTime.now().subtract(const Duration(days: 2));
      db.addStory(
        Story(
          id: 'velho',
          authorId: author.id,
          authorName: author.name,
          media: ref,
          createdAt: old,
          expiresAt: old.add(storyLifetime),
        ),
      );
      final expired = await repositories.stories.expiredStoriesOf(author.id);
      expect(expired.map((story) => story.id), ['velho']);
    });
  });

  group('presença', () {
    test('check-in e check-out mudam a lotação do local', () async {
      const venueId = 'boteco-central';
      final baseline = demoCrowdBaseline[venueId]!;
      Future<int> crowd() async =>
          (await repositories.presence.watchCrowd().first)[venueId]!;

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
      await repositories.presence.checkIn(
        checkInAt('praca-municipal', userId: 'demo-user'),
      );

      expect(db.findUserById('demo-user')!.visits, {'praca-municipal': 2});
    });

    test('limpar a presença fecha check-ins que sobraram', () async {
      await repositories.presence.checkIn(checkInAt('area-eventos'));
      await repositories.presence.clearPresence('demo-user');

      expect(db.activeCheckInsAt('area-eventos'), 0);
    });
  });
}
