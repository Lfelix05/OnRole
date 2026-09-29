import 'dart:async';

import '../../models/check_in.dart';
import '../../models/posts.dart';
import '../../models/user.dart';
import '../repositories.dart';

/// Banco em memória que imita o back-end, com uma conta de demonstração
/// (demo@onrole.com / 123456). Os dados somem quando o app fecha.
class MockDatabase {
  MockDatabase() {
    _seed();
  }

  final List<User> _users = [];
  final Map<String, ({String userId, String password})> _accounts = {};
  final List<Posts> _posts = [];
  final List<CheckIn> _checkIns = [];
  final _changes = StreamController<void>.broadcast();

  /// Avisa a cada alteração, para os repositórios emitirem dados novos.
  Stream<void> get changes => _changes.stream;

  List<User> get users => List.unmodifiable(_users);
  List<Posts> get posts => List.unmodifiable(_posts);
  List<CheckIn> get checkIns => List.unmodifiable(_checkIns);

  User? findUserById(String id) {
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  ({String userId, String password})? accountFor(String email) => _accounts[email.toLowerCase()];

  void addUser(User user, {required String email, required String password}) {
    _users.add(user);
    _accounts[email.toLowerCase()] = (userId: user.id, password: password);
    _notify();
  }

  void addPost(Posts post) {
    _posts.insert(0, post);
    _notify();
  }

  void addCheckIn(CheckIn checkIn) {
    _checkIns.add(checkIn);
    _notify();
  }

  void closeCheckIns(String userId, DateTime at) {
    for (final checkIn in _checkIns) {
      if (checkIn.userId == userId && checkIn.isActive) checkIn.checkedOutAt = at;
    }
    _notify();
  }

  int activeCheckInsAt(String venueId) {
    return _checkIns.where((checkIn) => checkIn.venueId == venueId && checkIn.isActive).length;
  }

  bool hasActiveCheckIn(String userId, String venueId) {
    return _checkIns.any((checkIn) => checkIn.userId == userId && checkIn.venueId == venueId && checkIn.isActive);
  }

  void _notify() => _changes.add(null);

  void _seed() {
    final demoUser = User(
      id: 'demo-user',
      name: 'Convidado Demo',
      birthDate: DateTime(2000, 1, 1),
      bio: 'Conta de demonstração do OnRolê.',
    );
    _users.add(demoUser);
    _accounts['demo@onrole.com'] = (userId: demoUser.id, password: '123456');

    Posts seedPost(String id, String title, String content, String venueId, Duration age) {
      final createdAt = DateTime.now().subtract(age);
      return Posts(
        id: id,
        title: title,
        content: content,
        type: PostType.text,
        authorId: demoUser.id,
        authorName: demoUser.name,
        venueId: venueId,
        createdAt: createdAt,
        updatedAt: createdAt,
        expiresAt: createdAt.add(postLifetime),
      );
    }

    _posts.addAll([
      seedPost('seed-2', 'Pico na praça', 'Movimento começando a subir por aqui.', 'praca-municipal',
          const Duration(minutes: 40)),
      seedPost('seed-1', 'Sextou no centro!', 'Bar lotado e som bom, bora pra cá.', 'boteco-central',
          const Duration(hours: 2)),
    ]);
  }
}
