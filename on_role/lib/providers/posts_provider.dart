import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repositories.dart';
import '../models/media.dart';
import '../models/posts.dart';
import '../models/reply.dart';
import 'auth_provider.dart';
import 'media_loader.dart';

/// Feed no estilo do Threads: posts de texto, fotos e vídeos, curtidas e
/// respostas.
class PostsProvider extends ChangeNotifier {
  PostsProvider({
    required PostRepository repository,
    required MediaRepository media,
    required MediaLoader loader,
    required AuthProvider auth,
  }) : _repository = repository,
       _media = media,
       _loader = loader,
       _auth = auth {
    auth.addListener(_syncSession);
    _syncSession();
  }

  static const _pageSize = 30;

  final PostRepository _repository;
  final MediaRepository _media;
  final MediaLoader _loader;
  final AuthProvider _auth;
  StreamSubscription<List<Posts>>? _subscription;
  String? _userId;
  int _limit = _pageSize;
  bool _loaded = false;
  List<Posts> _posts = const [];

  /// Do mais novo para o mais antigo.
  List<Posts> get posts => _posts;

  /// Falso até a primeira resposta do banco.
  bool get isLoaded => _loaded;

  /// Se o banco devolveu uma página cheia, pode haver posts mais antigos.
  bool get hasMore => _posts.length >= _limit;

  void loadMore() {
    if (!hasMore) return;
    _limit += _pageSize;
    _subscribe();
  }

  Stream<List<Posts>> postsByAuthor(String authorId) =>
      _repository.watchPostsByAuthor(authorId);

  /// Sobe as mídias (uma por vez, com o progresso de 0 a 1) e publica.
  /// Retorna a mensagem de erro, ou null se deu certo.
  Future<String?> publish({
    required String text,
    List<MediaDraft> drafts = const [],
    String? venueId,
    bool atVenue = false,
    void Function(double progress)? onProgress,
  }) async {
    final author = _auth.currentUser;
    if (author == null) return 'Sua sessão expirou. Entre de novo.';

    final uploaded = <MediaRef>[];
    try {
      for (var i = 0; i < drafts.length; i++) {
        final ref = await _media.upload(
          ownerId: author.id,
          draft: drafts[i],
          onProgress: (progress) =>
              onProgress?.call((i + progress) / drafts.length),
        );
        _loader.remember(ref.id, drafts[i].bytes);
        uploaded.add(ref);
      }
      await _repository.addPost(
        author: author,
        text: text.trim(),
        media: uploaded,
        venueId: venueId,
        atVenue: atVenue,
      );
      return null;
    } on MediaException catch (error) {
      _discard(uploaded);
      return error.message;
    } catch (error) {
      debugPrint('PostsProvider: $error');
      _discard(uploaded);
      return atVenue
          ? 'Não foi possível publicar. Confira a conexão e se o check-in '
                'continua ativo.'
          : 'Não foi possível publicar. Confira a conexão e tente de novo.';
    }
  }

  /// Curte ou descurte. O banco avisa a mudança na hora (inclusive offline),
  /// então a tela atualiza pelo próprio feed.
  Future<void> toggleLike(Posts post) async {
    final userId = _auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _repository.setLiked(
        postId: post.id,
        userId: userId,
        liked: !post.isLikedBy(userId),
      );
    } catch (error) {
      debugPrint('PostsProvider: $error');
    }
  }

  /// Retorna a mensagem de erro, ou null se apagou.
  Future<String?> deletePost(Posts post) async {
    try {
      await _repository.deletePost(post.id);
      _discard(post.media);
      return null;
    } catch (error) {
      debugPrint('PostsProvider: $error');
      return 'Não foi possível apagar o post.';
    }
  }

  Stream<List<Reply>> replies(String postId) =>
      _repository.watchReplies(postId);

  /// Retorna a mensagem de erro, ou null se respondeu.
  Future<String?> reply(Posts post, String text) async {
    final author = _auth.currentUser;
    if (author == null) return 'Sua sessão expirou. Entre de novo.';
    try {
      await _repository.addReply(
        postId: post.id,
        author: author,
        text: text.trim(),
      );
      return null;
    } catch (error) {
      debugPrint('PostsProvider: $error');
      return 'Não foi possível responder. Confira a conexão.';
    }
  }

  /// Apaga mídias que ficaram sem post (falha no meio da publicação ou post
  /// apagado). Erros aqui só deixam lixo no banco, então não vão para a tela.
  void _discard(List<MediaRef> media) {
    for (final item in media) {
      _media
          .delete(item)
          .catchError((Object error) => debugPrint('PostsProvider: $error'));
    }
  }

  void _syncSession() {
    final userId = _auth.currentUser?.id;
    if (userId == _userId) return;
    _userId = userId;
    _limit = _pageSize;
    _posts = const [];
    _loaded = false;
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = null;
    // O feed só pode ser lido por quem está logado.
    if (_userId == null) return;
    _subscription = _repository.watchFeed(limit: _limit).listen((posts) {
      _posts = posts;
      _loaded = true;
      notifyListeners();
    }, onError: (Object error) => debugPrint('PostsProvider: $error'));
  }

  @override
  void dispose() {
    _auth.removeListener(_syncSession);
    _subscription?.cancel();
    super.dispose();
  }
}
