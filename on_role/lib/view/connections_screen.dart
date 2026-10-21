import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'user_profile_screen.dart';
import 'widgets/follow_button.dart';
import 'widgets/user_avatar.dart';

/// Lista de pessoas de um perfil: as conexões (quem a pessoa segue) ou os
/// seguidores. Cada uma abre o próprio perfil.
class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({
    super.key,
    required this.title,
    required this.userIds,
    required this.emptyText,
  });

  final String title;
  final Stream<Set<String>> userIds;
  final String emptyText;

  static Future<void> open(
    BuildContext context, {
    required String title,
    required Stream<Set<String>> userIds,
    required String emptyText,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectionsScreen(
          title: title,
          userIds: userIds,
          emptyText: emptyText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myId = auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AppBackground(
        child: StreamBuilder<Set<String>>(
          stream: userIds,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator());
            }
            // Contas que não carregaram (ex.: apagadas) ficam de fora.
            final people = [
              for (final id in snapshot.data ?? const <String>{})
                ?auth.userById(id),
            ]..sort((a, b) => a.name.compareTo(b.name));
            if (people.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    emptyText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = people[index];
                return Material(
                  color: AppColors.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: InkWell(
                    onTap: () => UserProfileScreen.open(context, user),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          UserAvatar(user: user, radius: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  user.handle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (user.id != myId)
                            FollowButton(userId: user.id, compact: true),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
