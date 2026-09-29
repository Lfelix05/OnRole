import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repositories.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthRepository auth, required UserRepository users})
      : _auth = auth,
        _usersRepository = users {
    _sessionSubscription = auth.watchCurrentUser().listen(_onSession, onError: _logError);
  }

  final AuthRepository _auth;
  final UserRepository _usersRepository;
  StreamSubscription<User?>? _sessionSubscription;
  StreamSubscription<List<User>>? _usersSubscription;

  bool _initialized = false;
  User? _currentUser;
  List<User> _users = const [];

  bool get isInitialized => _initialized;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Outras contas, usadas na fileira de stories e na busca.
  List<User> get otherUsers => _users.where((user) => user.id != _currentUser?.id).toList();

  /// Retorna a mensagem de erro, ou null se o login deu certo.
  Future<String?> login({required String email, required String password}) async {
    try {
      await _auth.signIn(email: email, password: password);
      return null;
    } on AuthException catch (error) {
      return error.message;
    }
  }

  /// Retorna a mensagem de erro, ou null se o cadastro deu certo.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required DateTime birthDate,
  }) async {
    try {
      await _auth.register(name: name, email: email, password: password, birthDate: birthDate);
      return null;
    } on AuthException catch (error) {
      return error.message;
    }
  }

  Future<void> logout() => _auth.signOut();

  void _onSession(User? user) {
    final accountChanged = user?.id != _currentUser?.id;
    _currentUser = user;
    _initialized = true;

    if (accountChanged) {
      _usersSubscription?.cancel();
      _usersSubscription = null;
      _users = const [];
      // Perfis só podem ser lidos por quem está logado.
      if (user != null) {
        _usersSubscription = _usersRepository.watchUsers().listen((users) {
          _users = users;
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
