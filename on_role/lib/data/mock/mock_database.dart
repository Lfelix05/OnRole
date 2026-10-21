import 'dart:async';
import 'dart:typed_data';

import '../../models/check_in.dart';
import '../../models/match.dart';
import '../../models/media.dart';
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

  /// Conexões: quem segue quem.
  final Set<({String from, String to})> _follows = {};

  /// Chave "quem_avaliou_quem".
  final Map<String, Swipe> _swipes = {};
  final List<UserMatch> _matches = [];
  final Set<String> _enrolled = {};
  final Map<String, List<Map<String, Object?>>> _telemetry = {};
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

  void updateProfile(
    String userId, {
    required String? bio,
    required List<String> interests,
    MediaRef? photo,
  }) {
    final user = findUserById(userId);
    if (user == null) return;
    user
      ..bio = bio
      ..interests = List.of(interests)
      ..photo = photo ?? user.photo;
    _notify();
  }

  Set<String> followingOf(String userId) => {
    for (final follow in _follows)
      if (follow.from == userId) follow.to,
  };

  Set<String> followersOf(String userId) => {
    for (final follow in _follows)
      if (follow.to == userId) follow.from,
  };

  void setFollowing(String fromId, String toId, {required bool following}) {
    final follow = (from: fromId, to: toId);
    following ? _follows.add(follow) : _follows.remove(follow);
    _notify();
  }

  Swipe? swipeOf(String fromId, String toId) => _swipes['${fromId}_$toId'];

  Set<String> swipedIdsOf(String userId) => {
    for (final swipe in _swipes.values)
      if (swipe.fromId == userId) swipe.toId,
  };

  void putSwipe(Swipe swipe) {
    _swipes['${swipe.fromId}_${swipe.toId}'] = swipe;
    _notify();
  }

  List<UserMatch> matchesOf(String userId) =>
      _matches.where((match) => match.userIds.contains(userId)).toList();

  /// Cria o match se ainda não existe. Devolve se criou.
  bool addMatch(UserMatch match) {
    if (_matches.any((existing) => existing.id == match.id)) return false;
    _matches.add(match);
    _notify();
    return true;
  }

  bool isEnrolled(String userId) => _enrolled.contains(userId);

  void setEnrolled(String userId, bool enrolled) {
    enrolled ? _enrolled.add(userId) : _enrolled.remove(userId);
  }

  /// Eventos do experimento enviados por cada pessoa.
  List<Map<String, Object?>> telemetryOf(String userId) =>
      List.unmodifiable(_telemetry[userId] ?? const []);

  void addTelemetry(String userId, List<Map<String, Object?>> events) {
    (_telemetry[userId] ??= []).addAll(events);
  }

  void clearTelemetry(String userId) => _telemetry.remove(userId);

  int _idSequence = 0;

  /// Id único para o que é criado em memória. Só o relógio não basta: no
  /// Windows, duas gravações seguidas podem cair no mesmo microssegundo.
  String newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_idSequence++}';

  void _notify() => _changes.add(null);

  void _seed() {
    final demo = User(
      id: 'demo-user',
      name: 'Convidado Demo',
      birthDate: DateTime(2000, 1, 1),
      bio: 'Conta de demonstração do OnRolê.',
      interests: ['Bar', 'Samba e pagode', 'Show ao vivo'],
      visits: {'bakhanas': 3, 'area-verde': 1},
    );
    final ana = User(
      id: 'ana',
      name: 'Ana Souza',
      bio: 'Sempre no rolê.',
      interests: ['Bar', 'Samba e pagode', 'Balada'],
      visits: {'bakhanas': 2, 'caza-up': 1},
    );
    final pedro = User(
      id: 'pedro',
      name: 'Pedro Lima',
      interests: ['Show ao vivo', 'Rock'],
      visits: {'bunker-music-house': 4},
    );
    final julia = User(
      id: 'julia',
      name: 'Júlia Rocha',
      bio: 'Forró no sábado, praça no domingo.',
      interests: ['Forró', 'Praça e ar livre', 'MPB'],
      visits: {'caraiva-beach-bar': 2, 'cervejaria-divina-beer': 3},
    );
    final rafa = User(
      id: 'rafa',
      name: 'Rafa Mendes',
      interests: ['Eletrônica', 'Balada'],
      visits: {'caza-up': 5},
    );
    _users.addAll([demo, ana, pedro, julia, rafa]);
    _accounts['demo@onrole.com'] = (userId: demo.id, password: '123456');

    DateTime ago(Duration age) => DateTime.now().subtract(age);

    // Algumas conexões para o perfil demo não começar vazio.
    _follows.addAll([
      (from: demo.id, to: ana.id),
      (from: ana.id, to: demo.id),
      (from: julia.id, to: demo.id),
      (from: pedro.id, to: ana.id),
    ]);

    // A Ana já curtiu o usuário demo: curtindo de volta, sai um match.
    _swipes['ana_demo-user'] = Swipe(
      fromId: ana.id,
      toId: demo.id,
      decision: SwipeDecision.like,
      source: SuggestionSource.afinidade,
      score: 0.6,
      createdAt: ago(const Duration(hours: 1)),
    );

    _posts.addAll([
      Posts(
        id: 'seed-ana',
        authorId: ana.id,
        authorName: ana.name,
        text: "Alguém topa o BAKHANA'S hoje? Chego lá pelas 22h 🍻",
        venueId: 'bakhanas',
        likedBy: [pedro.id],
        createdAt: ago(const Duration(minutes: 15)),
      ),
      Posts(
        id: 'seed-pedro',
        authorId: pedro.id,
        authorName: pedro.name,
        text: 'Fim de tarde na Área Verde, quem chega? Trouxe o violão.',
        venueId: 'area-verde',
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
