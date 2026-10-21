import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'home_view.dart';
import 'welcome.dart';

/// Raiz do app: mostra o início para quem está logado (inclusive login salvo
/// de uma abertura anterior) e as boas-vindas para quem não está.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isInitialized) return const _Splash();
    return auth.isLoggedIn ? const HomeView() : const WelcomeView();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AppBackground(
        withGlow: true,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );
  }
}
