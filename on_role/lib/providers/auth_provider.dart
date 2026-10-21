import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repositories.dart';
import '../models/media.dart';
import '../models/user.dart';

/// Resultado do cadastro (ver [AuthProvider.register]).
typedef RegisterResult = ({String? error, String? warning});

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository auth,
    required UserRepository users,
    MediaRepository? media,
  }) : _auth = auth,
       _usersRepository = users,
       _media = media {
    _sessionSubscription = auth.watchCurrentUser().listen(
      _onSession,
      onError: _logError,
    );
  }

  final AuthRepository _auth;
  final UserRepository _usersRepository;
  final MediaRepository? _media;
  StreamSubscription<User?>? _sessionSubscription;
  StreamSubscription<List<User>>? _usersSubscription;

  bool _initialized = false;
  bool _usersLoaded = false;
  User? _currentUser;
  List<User> _users = const [];

  /// Falso até a lista de perfis chegar do banco (vazia ≠ carregando).
  bool get usersLoaded => _usersLoaded;

  bool get isInitialized => _initialized;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Outras contas, usadas na fileira de stories e na busca.
  List<User> get otherUsers =>
      _users.where((user) => user.id != _currentUser?.id).toList();

  /// Perfil de quem escreveu um post, story ou resposta (null se ainda não
  /// carregou).
  User? userById(String id) {
    if (id == _currentUser?.id) return _currentUser;
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  /// Retorna a mensagem de erro, ou null se o login deu certo.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signIn(email: email, password: password);
      return null;
    } on AuthException catch (error) {
      return error.message;
    }
  }

  /// Cria a conta e, se veio, envia a foto de perfil. [RegisterResult.error]
  /// impede o cadastro; [RegisterResult.warning] avisa de algo que falhou
  /// depois de a conta existir (a foto pode ser trocada em Editar perfil).
  Future<RegisterResult> register({
    required String name,
    required String email,
    required String password,
    required DateTime birthDate,
    MediaDraft? photo,
  }) async {
    final String userId;
    try {
      userId = await _auth.register(
        name: name,
        email: email,
        password: password,
        birthDate: birthDate,
      );
    } on AuthException catch (error) {
      return (error: error.message, warning: null);
    }

    final media = _media;
    if (photo == null || media == null) return (error: null, warning: null);
    try {
      final ref = await media.upload(ownerId: userId, draft: photo);
      await _usersRepository.updateProfile(
        userId,
        bio: null,
        interests: const [],
        photo: ref,
      );
      return (error: null, warning: null);
    } catch (error) {
      _logError(error);
      return (
        error: null,
        warning:
            'Conta criada, mas a foto não foi enviada. Tente de novo em '
            'Editar perfil.',
      );
    }
  }

  Future<void> logout() => _auth.signOut();

  /// Salva bio, gostos de rolê e (se veio) a foto nova. Retorna a mensagem de
  /// erro, ou null se deu certo.
  Future<String?> updateProfile({
    required String? bio,
    required List<String> interests,
    MediaDraft? newPhoto,
  }) async {
    final user = _currentUser;
    if (user == null) return 'Sua sessão expirou. Entre de novo.';
    try {
      MediaRef? photo;
      final media = _media;
      if (newPhoto != null && media != null) {
        photo = await media.upload(ownerId: user.id, draft: newPhoto);
      }
      await _usersRepository.updateProfile(
        user.id,
        bio: bio,
        interests: interests,
        photo: photo,
      );
      return null;
    } on MediaException catch (error) {
      return error.message;
    } catch (error) {
      _logError(error);
      return 'Não foi possível salvar o perfil. Confira a conexão.';
    }
  }

  void _onSession(User? user) {
    final accountChanged = user?.id != _currentUser?.id;
    _currentUser = user;
    _initialized = true;

    if (accountChanged) {
      _usersSubscription?.cancel();
      _usersSubscription = null;
      _users = const [];
      _usersLoaded = false;
      // Perfis só podem ser lidos por quem está logado.
      if (user != null) {
        _usersSubscription = _usersRepository.watchUsers().listen((users) {
          _users = users;
          _usersLoaded = true;
          notifyListeners();
        }, onError: _logError);
      }
    }
    notifyListeners();
  }

  void _logError(Object error) => debugPrint('AuthProvider: $error');

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _usersSubscription?.cancel();
    super.dispose();
  }
}
