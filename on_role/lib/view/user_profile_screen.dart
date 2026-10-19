import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/venue_catalog.dart';
import '../models/posts.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/posts_provider.dart';
import '../services/affinity.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'post_detail_screen.dart';
import 'widgets/post_card.dart';
import 'widgets/user_avatar.dart';

/// Perfil de outra pessoa: foto, bio, o que vocês têm em comum e os posts.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.user});

  final User user;

  static Future<void> open(BuildContext context, User user) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)));
  }

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final Stream<List<Posts>> _posts = context
      .read<PostsProvider>()
      .postsByAuthor(widget.user.id);

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final me = context.watch<AuthProvider>().currentUser;
    final affinity = me == null ? null : affinityBetween(me, user);
    final sharedVenues = [
      for (final id in affinity?.sharedVenueIds ?? const <String>[])
        ?findVenue(id),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(user.name)),
      body: AppBackground(
        child: StreamBuilder<List<Posts>>(
          stream: _posts,
          builder: (context, snapshot) {
            final posts = snapshot.data ?? const <Posts>[];
            return ListView(
              children: [
                const SizedBox(height: 16),
                Center(child: UserAvatar(user: user, radius: 48)),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user.bio != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
                    child: Text(
                      user.bio!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                if (user.interests.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final interest in user.interests)
                          Chip(
                            label: Text(interest),
                            backgroundColor:
                                affinity?.sharedInterests.contains(interest) ==
                                    true
                                ? AppColors.primary.withValues(alpha: 0.35)
                                : AppColors.surface,
                          ),
                      ],
                    ),
                  ),
                if (sharedVenues.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Text(
                      'Vocês frequentam: '
                      '${sharedVenues.map((venue) => venue.name).join(', ')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.primarySoft),
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                if (snapshot.hasData && posts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Nenhum post ainda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                for (final post in posts) ...[
                  PostCard(
                    post: post,
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(post: post),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
