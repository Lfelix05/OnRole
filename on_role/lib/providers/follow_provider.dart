import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories.dart';
import 'auth_provider.dart';

/// Conexões: conectar com alguém é seguir a pessoa (não precisa ser
/// recíproco). Guarda quem o usuário logado segue e quem segue ele.
class FollowProvider extends ChangeNotifier {
  FollowProvider({
    required FollowRepository repository,
    required AuthProvider auth,
  }) : _repository = repository,
       _auth = auth {
    auth.addListener(_syncSession);
    _syncSession();
  }

  final FollowRepository _repository;
  final AuthProvider _auth;
  StreamSubscription<Set<String>>? _followingSubscription;
  StreamSubscription<Set<String>>? _followersSubscription;
  String? _userId;
  Set<String> _following = const {};
  Set<String> _followers = const {};

  /// Quem o usuário logado segue (as conexões dele).
  Set<String> get following => _following;

  /// Quem segue o usuário logado.
  Set<String> get followers => _followers;

  bool isFollowing(String userId) => _following.contains(userId);

  /// Se [userId] já se conectou com o usuário logado.
  bool followsMe(String userId) => _followers.contains(userId);

  /// Quem [userId] segue (perfil de outra pessoa).
  Stream<Set<String>> followingOf(String userId) =>
      _repository.watchFollowing(userId);

  /// Quem segue [userId] (perfil de outra pessoa).
  Stream<Set<String>> followersOf(String userId) =>
      _repository.watchFollowers(userId);

  /// Conecta ou desfaz a conexão. Retorna a mensagem de erro, ou null se deu
  /// certo.
  Future<String?> toggle(String userId) async {
    final me = _auth.currentUser;
    if (me == null) return 'Sua sessão expirou. Entre de novo.';
    if (userId == me.id) return null;
    final follow = !isFollowing(userId);
    // Muda na tela na hora; volta atrás se o banco recusar.
    _setLocally(userId, follow);
    try {
      await _repository.setFollowing(
        fromId: me.id,
        toId: userId,
        following: follow,
      );
      return null;
    } catch (error) {
      debugPrint('FollowProvider: $error');
      if (_userId == me.id) _setLocally(userId, !follow);
      return follow
          ? 'Não foi possível conectar. Tente de novo.'
          : 'Não foi possível desfazer a conexão. Tente de novo.';
    }
  }

  void _setLocally(String userId, bool following) {
    _following = following
        ? {..._following, userId}
        : ({..._following}..remove(userId));
    notifyListeners();
  }

  void _syncSession() {
    final userId = _auth.currentUser?.id;
    if (userId == _userId) return;
    _userId = userId;
    _followingSubscription?.cancel();
    _followersSubscription?.cancel();
    _followingSubscription = null;
    _followersSubscription = null;
    _following = const {};
    _followers = const {};
    if (userId != null) {
      _followingSubscription = _repository.watchFollowing(userId).listen((ids) {
        _following = ids;
        notifyListeners();
      }, onError: _logError);
      _followersSubscription = _repository.watchFollowers(userId).listen((ids) {
        _followers = ids;
        notifyListeners();
      }, onError: _logError);
    }
    notifyListeners();
  }

  void _logError(Object error) => debugPrint('FollowProvider: $error');

  @override
  void dispose() {
    _auth.removeListener(_syncSession);
    _followingSubscription?.cancel();
    _followersSubscription?.cancel();
    super.dispose();
  }
}
