import 'dart:async';
import 'dart:typed_data';

import '../../models/check_in.dart';
import '../../models/posts.dart';
import '../../models/reply.dart';
import '../../models/story.dart';
import '../../models/user.dart';

/// Emite o valor atual assim que alguém escuta e de novo a cada mudança. O
/// valor inicial e a inscrição acontecem juntos, sem janela para perder um
/// evento entre os dois.
Stream<T> watchValue<T>(Stream<void> changes, T Function() read) {
  StreamSubscription<void>? subscription;
  late final StreamController<T> controller;
  controller = StreamController<T>(
    onListen: () {
      controller.add(read());
      subscription = changes.listen((_) => controller.add(read()));
    },
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}

/// Banco em memória que imita o back-end, com uma conta de demonstração
/// (demo@onrole.com / 123456). Os dados somem quando o app fecha.
class MockDatabase {
  MockDatabase() {
    _seed();
  }

  final List<User> _users = [];
  final Map<String, ({String userId, String password})> _accounts = {};

  /// Do mais novo para o mais antigo.
  final List<Posts> _posts = [];
  final Map<String, List<Reply>> _replies = {};

  /// Do mais antigo para o mais novo.
  final List<Story> _stories = [];
  final Map<String, Uint8List> _media = {};
  final List<CheckIn> _checkIns = [];
  final _changes = StreamController<void>.broadcast();

  /// Avisa a cada alteração, para os repositórios emitirem dados novos.
  Stream<void> get changes => _changes.stream;

  List<User> get users => List.unmodifiable(_users);
  List<Posts> get posts => List.unmodifiable(_posts);
  List<Story> get stories => List.unmodifiable(_stories);
  List<CheckIn> get checkIns => List.unmodifiable(_checkIns);

  User? findUserById(String id) {
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  ({String userId, String password})? accountFor(String email) =>
      _accounts[email.toLowerCase()];

  void addUser(User user, {required String email, required String password}) {
    _users.add(user);
    _accounts[email.toLowerCase()] = (userId: user.id, password: password);
    _notify();
  }

  Posts? findPost(String id) {
    for (final post in _posts) {
      if (post.id == id) return post;
    }
    return null;
  }

  void addPost(Posts post) {
    _posts.insert(0, post);
    _notify();
  }

  void removePost(String id) {
    _posts.removeWhere((post) => post.id == id);
    _replies.remove(id);
    _notify();
  }

  void setLiked(String postId, String userId, {required bool liked}) {
    final post = findPost(postId);
    if (post == null) return;
    post.likedBy = [
      ...post.likedBy.where((id) => id != userId),
      if (liked) userId,
    ];
    _notify();
  }

  /// Da mais antiga para a mais nova.
  List<Reply> repliesOf(String postId) =>
      List.unmodifiable(_replies[postId] ?? const <Reply>[]);

  void addReply(Reply reply) {
    (_replies[reply.postId] ??= []).add(reply);
    findPost(reply.postId)?.replyCount += 1;
    _notify();
  }

  void addStory(Story story) {
    _stories.add(story);
    _notify();
  }

  void removeStory(String id) {
    _stories.removeWhere((story) => story.id == id);
    _notify();
  }

  void putMedia(String id, Uint8List bytes) => _media[id] = bytes;

  Uint8List? mediaBytes(String id) => _media[id];

  void removeMedia(String id) => _media.remove(id);

  void addCheckIn(CheckIn checkIn) {
    _checkIns.add(checkIn);
    _notify();
  }

  void closeCheckIns(String userId, DateTime at) {
    for (final checkIn in _checkIns) {
      if (checkIn.userId == userId && checkIn.isActive) {
        checkIn.checkedOutAt = at;
      }
    }
    _notify();
  }

  int activeCheckInsAt(String venueId) {
    return _checkIns
        .where((checkIn) => checkIn.venueId == venueId && checkIn.isActive)
        .length;
  }

  bool hasActiveCheckIn(String userId, String venueId) {
    return _checkIns.any(
      (checkIn) =>
          checkIn.userId == userId &&
          checkIn.venueId == venueId &&
          checkIn.isActive,
    );
  }

  void _notify() => _changes.add(null);

  void _seed() {
    final demo = User(
      id: 'demo-user',
      name: 'Convidado Demo',
      birthDate: DateTime(2000, 1, 1),
      bio: 'Conta de demonstração do OnRolê.',
    );
    final ana = User(id: 'ana', name: 'Ana Souza', bio: 'Sempre no rolê.');
    final pedro = User(id: 'pedro', name: 'Pedro Lima');
    _users.addAll([demo, ana, pedro]);
    _accounts['demo@onrole.com'] = (userId: demo.id, password: '123456');

    DateTime ago(Duration age) => DateTime.now().subtract(age);

    _posts.addAll([
      Posts(
        id: 'seed-ana',
        authorId: ana.id,
        authorName: ana.name,
        text: 'Alguém topa o Boteco Central hoje? Chego lá pelas 22h 🍻',
        venueId: 'boteco-central',
        likedBy: [pedro.id],
        createdAt: ago(const Duration(minutes: 15)),
      ),
      Posts(
        id: 'seed-pedro',
        authorId: pedro.id,
        authorName: pedro.name,
        text: 'O show na Área de Eventos já começou e tá lotado. Bora!',
        venueId: 'area-eventos',
        atVenue: true,
        likedBy: [ana.id, demo.id],
        createdAt: ago(const Duration(minutes: 50)),
      ),
      Posts(
        id: 'seed-demo',
        authorId: demo.id,
        authorName: demo.name,
        text: 'Sextou no centro! Quem tá na rua hoje?',
        createdAt: ago(const Duration(hours: 2)),
      ),
    ]);

    addReply(
      Reply(
        id: 'seed-reply',
        postId: 'seed-ana',
        authorId: pedro.id,
        authorName: pedro.name,
        text: 'Tô dentro! Levo o pessoal da facul.',
        createdAt: ago(const Duration(minutes: 10)),
      ),
    );
  }
}
