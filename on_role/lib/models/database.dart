import 'posts.dart';
import 'user.dart';

class MockDatabase {
  MockDatabase._internal() {
    _seed();
  }

  static final MockDatabase instance = MockDatabase._internal();

  final List<User> _users = [];
  final List<Posts> _posts = [];

  List<User> get users => List.unmodifiable(_users);
  List<Posts> get posts => List.unmodifiable(_posts);

  User? findUserByEmail(String email) {
    for (final user in _users) {
      if (user.email == email) return user;
    }
    return null;
  }

  User? findUserById(String id) {
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  bool emailExists(String email) => findUserByEmail(email) != null;

  void addUser(User user) {
    _users.add(user);
  }

  void addPost(Posts post) {
    _posts.insert(0, post);
  }

  void _seed() {
    final demoUser = User(
      id: 'demo-user',
      name: 'Convidado Demo',
      email: 'demo@onrole.com',
      password: '123456',
      birthDate: DateTime(2000, 1, 1),
      bio: 'Conta de demonstração do OnRolê.',
    );
    _users.add(demoUser);

    final now = DateTime.now();
    _posts.addAll([
      Posts(
        id: 'seed-1',
        title: 'Sextou no centro!',
        content: 'Bar lotado e som bom, bora pra cá.',
        type: PostType.text,
        authorId: demoUser.id,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      Posts(
        id: 'seed-2',
        title: 'Pico na praça',
        content: 'Movimento começando a subir por aqui.',
        type: PostType.text,
        authorId: demoUser.id,
        createdAt: now.subtract(const Duration(minutes: 40)),
        updatedAt: now.subtract(const Duration(minutes: 40)),
      ),
    ]);
  }
}
