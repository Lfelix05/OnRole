import 'package:flutter_test/flutter_test.dart';
import 'package:on_role/data/mock/mock_database.dart';
import 'package:on_role/data/mock/mock_repositories.dart';
import 'package:on_role/data/repositories.dart';
import 'package:on_role/providers/auth_provider.dart';
import 'package:on_role/providers/follow_provider.dart';

/// Deixa os streams e futures pendentes terminarem.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabase db;
  late Repositories repositories;
  late AuthProvider auth;
  late FollowProvider follows;

  setUp(() async {
    db = MockDatabase();
    repositories = createMockRepositories(database: db);
    auth = AuthProvider(auth: repositories.auth, users: repositories.users);
    follows = FollowProvider(repository: repositories.follows, auth: auth);
    await settle();
    await auth.login(email: 'demo@onrole.com', password: '123456');
    await settle();
  });

  tearDown(() {
    follows.dispose();
    auth.dispose();
  });

  test('carrega quem o usuário segue e quem segue ele', () {
    expect(follows.following, {'ana'});
    expect(follows.followers, {'ana', 'julia'});
    expect(follows.followsMe('julia'), isTrue);
    expect(follows.isFollowing('julia'), isFalse);
  });

  test('conectar e desfazer a conexão', () async {
    expect(await follows.toggle('pedro'), isNull);
    expect(follows.isFollowing('pedro'), isTrue);
    await settle();
    expect(db.followersOf('pedro'), contains('demo-user'));

    expect(await follows.toggle('pedro'), isNull);
    await settle();
    expect(follows.isFollowing('pedro'), isFalse);
    expect(db.followersOf('pedro'), isNot(contains('demo-user')));
  });

  test('não conecta consigo mesmo', () async {
    expect(await follows.toggle('demo-user'), isNull);
    expect(follows.isFollowing('demo-user'), isFalse);
    expect(db.followingOf('demo-user'), isNot(contains('demo-user')));
  });

  test('se o banco recusa, a tela volta ao que era', () async {
    final error = await follows.toggle('nao-existe');
    expect(error, isNotNull);
    expect(follows.isFollowing('nao-existe'), isFalse);
  });

  test('perfil de outra pessoa: conexões e seguidores ao vivo', () async {
    final followers = <Set<String>>[];
    final subscription = follows.followersOf('pedro').listen(followers.add);
    await settle();
    await follows.toggle('pedro');
    await settle();
    await subscription.cancel();

    expect(followers.first, isEmpty);
    expect(followers.last, {'demo-user'});
    expect(await follows.followingOf('pedro').first, {'ana'});
  });

  test('ao sair, esquece as conexões da conta anterior', () async {
    await auth.logout();
    await settle();
    expect(follows.following, isEmpty);
    expect(follows.followers, isEmpty);
  });
}
