import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/posts.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/follow_provider.dart';
import '../providers/posts_provider.dart';
import '../services/affinity.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'connections_screen.dart';
import 'edit_profile_screen.dart';
import 'widgets/follow_button.dart';
import 'widgets/profile_widgets.dart';

/// Perfil de outra pessoa: capa, botão de conectar, números, o que vocês têm
/// em comum e os posts (abre sempre em "Fotos e vídeos").
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.user});

  final User user;

  static Future<void> open(BuildContext context, User user) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)));
  }

  /// Perfil de quem escreveu um post ou resposta. Se o perfil ainda não
  /// carregou, abre com o nome guardado no post e completa quando chegar.
  static Future<void> openAuthor(
    BuildContext context, {
    required String userId,
    required String name,
  }) {
    final user =
        context.read<AuthProvider>().userById(userId) ??
        User(id: userId, name: name);
    return open(context, user);
  }

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _gridTab = true;
  late final Stream<List<Posts>> _posts = context
      .read<PostsProvider>()
      .postsByAuthor(widget.user.id);
  late final Stream<Set<String>> _followers = context
      .read<FollowProvider>()
      .followersOf(widget.user.id);
  late final Stream<Set<String>> _following = context
      .read<FollowProvider>()
      .followingOf(widget.user.id);

  @override
  Widget build(BuildContext context) {
    // A versão carregada do perfil chega atualizada (foto, bio).
    final user =
        context.select<AuthProvider, User?>(
          (auth) => auth.userById(widget.user.id),
        ) ??
        widget.user;
    final me = context.watch<AuthProvider>().currentUser;
    final isMe = me?.id == user.id;
    final affinity = me == null || isMe ? null : affinityBetween(me, user);
    final followsMe = context.select<FollowProvider, bool>(
      (follows) => follows.followsMe(user.id),
    );
    final firstName = user.name.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user.handle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: AppBackground(
        child: StreamBuilder<List<Posts>>(
          stream: _posts,
          builder: (context, snapshot) {
            final posts = snapshot.data ?? const <Posts>[];
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ProfileHeader(
                    user: user,
                    badges: [
                      if (followsMe && !isMe)
                        const ProfileBadge(
                          icon: Icons.people_alt_rounded,
                          label: 'Conectou com você',
                        ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _CountsRow(
                      followers: _followers,
                      following: _following,
                      builder: (followers, following) => ProfileStatsRow(
                        stats: [
                          ProfileStat(
                            icon: Icons.grid_view_rounded,
                            value: snapshot.hasData ? posts.length : null,
                            label: 'Posts',
                          ),
                          ProfileStat(
                            icon: Icons.people_alt_rounded,
                            value: followers,
                            label: 'Seguidores',
                            onTap: () => ConnectionsScreen.open(
                              context,
                              title: 'Seguidores de $firstName',
                              userIds: context
                                  .read<FollowProvider>()
                                  .followersOf(user.id),
                              emptyText:
                                  'Ninguém se conectou com $firstName ainda.',
                            ),
                          ),
                          ProfileStat(
                            icon: Icons.link_rounded,
                            value: following,
                            label: 'Conexões',
                            onTap: () => ConnectionsScreen.open(
                              context,
                              title: 'Conexões de $firstName',
                              userIds: context
                                  .read<FollowProvider>()
                                  .followingOf(user.id),
                              emptyText:
                                  '$firstName ainda não se conectou com '
                                  'ninguém.',
                            ),
                          ),
                          ProfileStat(
                            icon: Icons.place_rounded,
                            value: user.totalVisits,
                            label: 'Rolês',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: isMe
                        ? ProfileOutlinedButton(
                            icon: Icons.edit_outlined,
                            label: 'Editar perfil',
                            onPressed: () => EditProfileScreen.open(context),
                          )
                        : FollowButton(userId: user.id),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: InterestsCard(
                      interests: user.interests,
                      shared: affinity?.sharedInterests.toSet(),
                      empty: Text(
                        isMe
                            ? 'Você ainda não contou do que curte.'
                            : '$firstName ainda não contou do que curte.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: FavoriteVenuesCard(
                      visits: user.visits,
                      title: isMe ? 'Onde mais vou' : 'Onde mais vai',
                      emptyText: 'Ainda sem check-ins nos locais do mapa.',
                      shared: affinity?.sharedVenueIds.toSet() ?? const {},
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: ProfileTabsHeader(
                    gridTab: _gridTab,
                    onChanged: (grid) => setState(() => _gridTab = grid),
                  ),
                ),
                ProfilePostsSliver(
                  posts: posts,
                  gridTab: _gridTab,
                  loaded: snapshot.hasData || snapshot.hasError,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Seguidores e conexões de outra pessoa, ao vivo (null enquanto carrega).
class _CountsRow extends StatelessWidget {
  const _CountsRow({
    required this.followers,
    required this.following,
    required this.builder,
  });

  final Stream<Set<String>> followers;
  final Stream<Set<String>> following;
  final Widget Function(int? followers, int? following) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: followers,
      builder: (context, followersSnapshot) => StreamBuilder<Set<String>>(
        stream: following,
        builder: (context, followingSnapshot) => builder(
          followersSnapshot.data?.length,
          followingSnapshot.data?.length,
        ),
      ),
    );
  }
}
