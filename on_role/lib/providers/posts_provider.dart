import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repositories.dart';
import '../models/posts.dart';
import '../models/user.dart';
import 'auth_provider.dart';

class PostsProvider extends ChangeNotifier {
  PostsProvider({required PostRepository repository, required AuthProvider auth})
      : _repository = repository,
        _auth = auth {
    auth.addListener(_syncSession);
    _syncSession();
  }

  final PostRepository _repository;
  final AuthProvider _auth;
  StreamSubscription<List<Posts>>? _subscription;
  String? _userId;
  List<Posts> _posts = const [];

  /// Posts ainda não expirados, do mais novo para o mais antigo. O filtro roda
  /// na leitura porque um post pode vencer sem que chegue dado novo do banco.
  List<Posts> get posts {
    final now = DateTime.now();
    return _posts.where((post) => post.expiresAt.isAfter(now)).toList();
  }

  List<Posts> postsByAuthor(String authorId) {
    return posts.where((post) => post.authorId == authorId).toList();
  }

  /// Retorna a mensagem de erro, ou null se publicou.
  Future<String?> addPost({required User author, required String venueId, required String content}) async {
    try {
      await _repository.addPost(author: author, venueId: venueId, content: content);
      return null;
    } catch (error) {
      debugPrint('PostsProvider: $error');
      return 'Não foi possível publicar. Confira a conexão e se o check-in continua ativo.';
    }
  }

  void _syncSession() {
    final userId = _auth.currentUser?.id;
    if (userId == _userId) return;
    _userId = userId;
    _subscription?.cancel();
    _subscription = null;
    _posts = const [];
    // O feed só pode ser lido por quem está logado.
    if (userId != null) {
      _subscription = _repository.watchFeed().listen((posts) {
        _posts = posts;
        notifyListeners();
      }, onError: (Object error) => debugPrint('PostsProvider: $error'));
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_syncSession);
    _subscription?.cancel();
    super.dispose();
  }
}
