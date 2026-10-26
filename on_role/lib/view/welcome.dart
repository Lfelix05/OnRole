import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_mode.dart';
import '../providers/auth_provider.dart';
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
                if (appMode.isDemo) ...[
                  const _DemoNotice(),
                  const SizedBox(height: 20.0),
                  GradientButton(
                    label: 'Explorar a demonstração',
                    onPressed: () => context.read<AuthProvider>().login(
                          email: demoGuestEmail,
                          password: demoGuestPassword,
                        ),
                  ),
                ] else ...[
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
                ],
                const SizedBox(height: 24.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso da versão de demonstração, antes de entrar.
class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        'Esta é uma versão de demonstração. Não tem cadastro e o app não usa '
        'sua localização: você toca no mapa para simular onde está. As pessoas, '
        'os posts e a lotação dos locais são fictícios. Nada do que você fizer '
        'aqui é enviado ou fica guardado depois que o app fecha.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.0, color: AppColors.textSecondary, height: 1.4),
      ),
    );
  }
}
