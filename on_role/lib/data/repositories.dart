import '../models/check_in.dart';
import '../models/posts.dart';
import '../models/user.dart';

// Contratos da camada de dados. Telas e providers só conhecem estas
// interfaces; por trás delas fica o Firebase (app de verdade) ou o banco mock
// (testes, Windows e apresentações sem internet).

/// Quanto tempo um post fica no feed ("Instagram do agora").
const postLifetime = Duration(hours: 12);

/// Presença sem renovação há mais que isso deixa de contar na lotação (app
/// fechado à força, bateria acabou...).
const presenceTimeout = Duration(minutes: 15);

/// Erro de login ou cadastro, com uma mensagem pronta para a tela.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthRepository {
  /// Usuário logado (ou null), emitido a cada mudança de sessão ou de perfil.
  Stream<User?> watchCurrentUser();

  /// Lança [AuthException] se não der certo.
  Future<void> signIn({required String email, required String password});

  /// Lança [AuthException] se não der certo.
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required DateTime birthDate,
  });

  Future<void> signOut();
}

abstract class UserRepository {
  /// Perfis públicos (stories, busca e, depois, o match geossocial).
  Stream<List<User>> watchUsers();
}

abstract class PresenceRepository {
  /// Registra o check-in: presença atual, histórico e contagem de visitas.
  Future<void> checkIn(CheckIn checkIn);

  /// Encerra o check-in, com o horário de [CheckIn.checkedOutAt].
  Future<void> checkOut(CheckIn checkIn);

  /// Renova a presença enquanto o usuário continua no local.
  Future<void> keepAlive(CheckIn checkIn);

  /// Apaga uma presença que tenha sobrado da sessão anterior (app fechado à
  /// força com check-in ativo).
  Future<void> clearPresence(String userId);

  /// Pessoas em cada local agora (id do local → quantidade).
  Stream<Map<String, int>> watchCrowd();
}

abstract class PostRepository {
  /// Posts ainda não expirados, do mais novo para o mais antigo.
  Stream<List<Posts>> watchFeed();

  Future<void> addPost({required User author, required String venueId, required String content});
}

/// As implementações que o app usa.
class Repositories {
  const Repositories({
    required this.auth,
    required this.users,
    required this.presence,
    required this.posts,
  });

  final AuthRepository auth;
  final UserRepository users;
  final PresenceRepository presence;
  final PostRepository posts;
}
