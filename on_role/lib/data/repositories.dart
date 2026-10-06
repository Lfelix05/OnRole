import 'dart:typed_data';

import '../models/check_in.dart';
import '../models/media.dart';
import '../models/posts.dart';
import '../models/reply.dart';
import '../models/story.dart';
import '../models/user.dart';

// Contratos da camada de dados. Telas e providers só conhecem estas
// interfaces; por trás delas fica o Firebase (app de verdade) ou o banco mock
// (testes, Windows e apresentações sem internet).

/// Quanto tempo um story fica visível.
const storyLifetime = Duration(hours: 24);

/// Fotos e vídeos ficam no próprio Firestore, divididos em pedaços, porque o
/// Cloud Storage exige o plano pago. Cada documento aceita até 1 MiB.
const mediaChunkSize = 900 * 1024;

/// Tamanho máximo de uma foto ou vídeo (12 pedaços).
const maxMediaBytes = 10 * 1024 * 1024;

/// Quantas fotos/vídeos cabem num post.
const maxPostMedia = 4;

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
  /// Os [limit] posts mais recentes, do mais novo para o mais antigo.
  Stream<List<Posts>> watchFeed({int limit = 30});

  /// Posts de uma pessoa, do mais novo para o mais antigo.
  Stream<List<Posts>> watchPostsByAuthor(String authorId);

  /// [atVenue] só é aceito com check-in ativo em [venueId].
  Future<void> addPost({
    required User author,
    required String text,
    List<MediaRef> media = const [],
    String? venueId,
    bool atVenue = false,
  });

  Future<void> setLiked({
    required String postId,
    required String userId,
    required bool liked,
  });

  /// Apaga o post (só o autor). As mídias são apagadas à parte.
  Future<void> deletePost(String postId);

  Stream<List<Reply>> watchReplies(String postId);

  Future<void> addReply({
    required String postId,
    required User author,
    required String text,
  });
}

abstract class StoryRepository {
  /// Stories ainda não expirados, dos mais antigos para os mais novos.
  Stream<List<Story>> watchActiveStories();

  Future<void> addStory({
    required User author,
    required MediaRef media,
    String? venueId,
    bool atVenue = false,
  });

  /// Stories vencidos de uma pessoa (o plano gratuito não tem exclusão
  /// automática, então o próprio app faz a limpeza).
  Future<List<Story>> expiredStoriesOf(String userId);

  Future<void> deleteStory(String storyId);
}

/// Erro de mídia com uma mensagem pronta para a tela.
class MediaException implements Exception {
  const MediaException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class MediaRepository {
  /// Guarda os bytes em pedaços e devolve a referência para o post/story.
  /// [onProgress] vai de 0 a 1. Lança [MediaException] se não couber.
  Future<MediaRef> upload({
    required String ownerId,
    required MediaDraft draft,
    void Function(double progress)? onProgress,
  });

  Future<Uint8List> load(MediaRef media);

  Future<void> delete(MediaRef media);
}

/// As implementações que o app usa.
class Repositories {
  const Repositories({
    required this.auth,
    required this.users,
    required this.presence,
    required this.posts,
    required this.stories,
    required this.media,
  });

  final AuthRepository auth;
  final UserRepository users;
  final PresenceRepository presence;
  final PostRepository posts;
  final StoryRepository stories;
  final MediaRepository media;
}
