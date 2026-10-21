import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/follow_provider.dart';
import '../../theme/app_theme.dart';

/// "Conectar" (seguir) ou "Conectado". Tocar de novo desfaz a conexão.
class FollowButton extends StatelessWidget {
  const FollowButton({super.key, required this.userId, this.compact = false});

  final String userId;

  /// Versão pequena, para listas de pessoas.
  final bool compact;

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<FollowProvider>().toggle(userId);
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final follows = context.watch<FollowProvider>();
    final following = follows.isFollowing(userId);
    final label = following
        ? 'Conectado'
        : !compact && follows.followsMe(userId)
        ? 'Conectar de volta'
        : 'Conectar';
    final height = compact ? 34.0 : 46.0;
    final radius = BorderRadius.circular(height / 2);

    return Semantics(
      button: true,
      toggled: following,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: DecoratedBox(
          key: ValueKey(following),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: following ? null : AppColors.primaryGradient,
            color: following ? AppColors.surface : null,
            border: following ? Border.all(color: AppColors.border) : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: () => _toggle(context),
              child: SizedBox(
                height: height,
                width: compact ? null : double.infinity,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
                  child: Row(
                    mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        following
                            ? Icons.how_to_reg_rounded
                            : Icons.person_add_alt_1_rounded,
                        size: compact ? 16 : 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: compact ? 13 : 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
