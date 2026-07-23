import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'login_view.dart';
import 'register_view.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        withGlow: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              children: <Widget>[
                const Spacer(flex: 4),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 20.0),
                const Text(
                  'OnRolê',
                  style: TextStyle(
                    fontSize: 32.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10.0),
                Text(
                  'Descubra onde a cidade está\npulsando agora, perto de você.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.0,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const Spacer(flex: 5),
                GradientButton(
                  label: 'Entrar',
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginView()));
                  },
                ),
                const SizedBox(height: 14.0),
                OutlinedDarkButton(
                  label: 'Criar conta',
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterView()));
                  },
                ),
                const SizedBox(height: 24.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
