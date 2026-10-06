import 'dart:async';

import '../../models/check_in.dart';
import '../../models/user.dart';
import '../../services/crowd_simulator.dart';
import '../repositories.dart';
import '../venue_catalog.dart';
import 'mock_database.dart';
import 'mock_social_repositories.dart';

/// Repositórios em memória, com a lotação dos locais simulada.
Repositories createMockRepositories({
  MockDatabase? database,
  CrowdSimulator? simulator,
}) {
  final db = database ?? MockDatabase();
  return Repositories(
    auth: MockAuthRepository(db),
    users: MockUserRepository(db),
    presence: MockPresenceRepository(
      db,
      simulator: simulator ?? CrowdSimulator(baseline: demoCrowdBaseline),
    ),
    posts: MockPostRepository(db),
    stories: MockStoryRepository(db),
    media: MockMediaRepository(db),
  );
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._db);

  final MockDatabase _db;
  final _sessionChanges = StreamController<void>.broadcast();
  User? _current;

  @override
  Stream<User?> watchCurrentUser() =>
      watchValue(_sessionChanges.stream, () => _current);

  @override
  Future<void> signIn({required String email, required String password}) async {
    final account = _db.accountFor(email.trim());
    if (account == null) throw const AuthException('Usuário não encontrado.');
    if (account.password != password) {
      throw const AuthException('Senha incorreta.');
    }
    _setCurrent(_db.findUserById(account.userId));
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required DateTime birthDate,
  }) async {
    if (_db.accountFor(email.trim()) != null) {
      throw const AuthException('Já existe uma conta com esse e-mail.');
    }
    final user = User(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      birthDate: birthDate,
    );
    _db.addUser(user, email: email.trim(), password: password);
    _setCurrent(user);
  }

  @override
  Future<void> signOut() async => _setCurrent(null);

  void _setCurrent(User? user) {
    _current = user;
    _sessionChanges.add(null);
  }
}

class MockUserRepository implements UserRepository {
  MockUserRepository(this._db);

  final MockDatabase _db;

  @override
  Stream<List<User>> watchUsers() => watchValue(_db.changes, () => _db.users);
}

class MockPresenceRepository implements PresenceRepository {
  MockPresenceRepository(
    this._db, {
    required CrowdSimulator simulator,
    this.tick = const Duration(seconds: 5),
  }) : _simulator = simulator;

  final MockDatabase _db;
  final CrowdSimulator _simulator;

  /// Intervalo de atualização da lotação simulada.
  final Duration tick;

  @override
  Future<void> checkIn(CheckIn checkIn) async {
    _db
        .findUserById(checkIn.userId)
        ?.visits
        .update(checkIn.venueId, (count) => count + 1, ifAbsent: () => 1);
    _db.addCheckIn(checkIn);
  }

  @override
  Future<void> checkOut(CheckIn checkIn) async {
    _db.closeCheckIns(checkIn.userId, checkIn.checkedOutAt ?? DateTime.now());
  }

  @override
  Future<void> keepAlive(CheckIn checkIn) async {}

  @override
  Future<void> clearPresence(String userId) async =>
      _db.closeCheckIns(userId, DateTime.now());

  @override
  Stream<Map<String, int>> watchCrowd() {
    Timer? timer;
    StreamSubscription<void>? changes;
    late final StreamController<Map<String, int>> controller;
    controller = StreamController(
      onListen: () {
        controller.add(_counts());
        timer = Timer.periodic(tick, (_) {
          _simulator.step();
          controller.add(_counts());
        });
        changes = _db.changes.listen((_) => controller.add(_counts()));
      },
      onCancel: () {
        timer?.cancel();
        return changes?.cancel();
      },
    );
    return controller.stream;
  }

  Map<String, int> _counts() {
    return {
      for (final venue in venueCatalog)
        venue.id: _simulator.countAt(venue.id) + _db.activeCheckInsAt(venue.id),
    };
  }
}
