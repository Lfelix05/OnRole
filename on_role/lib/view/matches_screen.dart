import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/venue_catalog.dart';
import '../providers/auth_provider.dart';
import '../providers/match_provider.dart';
import '../services/affinity.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'user_profile_screen.dart';
import 'widgets/user_avatar.dart';

/// Pessoas com quem houve match (curtida recíproca).
///
/// Pausada junto com o match geossocial (ver home_view.dart).
class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MatchesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final matchProvider = context.watch<MatchProvider>();
    final me = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Suas conexões')),
      body: AppBackground(
        child: me == null || matchProvider.matches.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Nenhum match ainda.\nCurta quem frequenta os mesmos rolês '
                    'que você na aba Conexões.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            : ListView.separated(
                itemCount: matchProvider.matches.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final match = matchProvider.matches[index];
                  final other = matchProvider.userById(
                    match.otherUserId(me.id),
                  );
                  if (other == null) return const SizedBox.shrink();
                  final venue = findVenue(
                    affinityBetween(me, other).sharedVenueIds.firstOrNull,
                  );
                  return ListTile(
                    leading: UserAvatar(user: other, radius: 24),
                    title: Text(
                      other.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      venue == null
                          ? 'Match ${formatTimeAgo(match.createdAt)} atrás'
                          : 'Vocês frequentam ${venue.name}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                    ),
                    onTap: () => UserProfileScreen.open(context, other),
                  );
                },
              ),
      ),
    );
  }
}
