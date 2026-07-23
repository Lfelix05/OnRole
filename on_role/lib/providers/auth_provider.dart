import 'package:flutter/material.dart';

import '../models/database.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Outras contas cadastradas, usado para preencher a fileira de stories.
  List<User> get otherUsers => MockDatabase.instance.users
      .where((u) => u.id != _currentUser?.id)
      .toList();

  /// retorna mensagem de erro, ou null se o login deu certo.
  String? login({required String email, required String password}) {
    final user = MockDatabase.instance.findUserByEmail(email.trim());
    if (user == null) return 'Usuário não encontrado.';
    if (user.password != password) return 'Senha incorreta.';

    _currentUser = user;
    notifyListeners();
    return null;
  }

  String? register({
    required String name,
    required String email,
    required String password,
    required DateTime birthDate,
  }) {
    if (MockDatabase.instance.emailExists(email.trim())) {
      return 'Já existe uma conta com esse email.';
    }

    final user = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      email: email.trim(),
      password: password,
      birthDate: birthDate,
    );
    MockDatabase.instance.addUser(user);

    _currentUser = user;
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
