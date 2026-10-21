import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/posts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/experiment_provider.dart';
import '../../providers/follow_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/presence_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../connections_screen.dart';
import '../edit_profile_screen.dart';
import '../experiment_screen.dart';
import '../widgets/profile_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // O perfil sempre abre em "Fotos e vídeos".
  bool _gridTab = true;
  String? _postsUserId;
  Stream<List<Posts>>? _posts;

  /// Posts da pessoa direto do banco (o feed só carrega os mais recentes).
  Stream<List<Posts>> _postsOf(String userId) {
    if (_postsUserId != userId) {
      _postsUserId = userId;
      _posts = context.read<PostsProvider>().postsByAuthor(userId);
    }
    return _posts!;
  }

  Future<void> _logout() async {
    final presence = context.read<PresenceProvider>();
    final auth = context.read<AuthProvider>();
    // Primeiro o check-out (precisa da sessão ativa para chegar ao servidor).
    // Depois do logout, a raiz (AuthGate) volta para as boas-vindas sozinha.
    await presence.stop();
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final enrolled = context.watch<ExperimentProvider>().isEnrolled;
    final follows = context.watch<FollowProvider>();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: user == null
              ? const Center(
                  child: Text(
                    'Nenhum usuário logado',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : StreamBuilder<List<Posts>>(
                  stream: _postsOf(user.id),
                  builder: (context, snapshot) {
                    final posts = snapshot.data ?? const <Posts>[];
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: ProfileHeader(
                            user: user,
                            actions: [
                              CoverButton(
                                tooltip: 'Experimento do TCC',
                                icon: enrolled
                                    ? Icons.science
                                    : Icons.science_outlined,
                                highlighted: enrolled,
                                onPressed: () => ExperimentScreen.open(context),
                              ),
                              CoverButton(
                                tooltip: 'Sair',
                                icon: Icons.logout,
                                onPressed: _logout,
                              ),
                            ],
                            badges: [
                              if (enrolled)
                                const ProfileBadge(
                                  icon: Icons.science,
                                  label: 'Participando do experimento',
                                ),
                            ],
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            child: ProfileStatsRow(
                              stats: [
                                ProfileStat(
                                  icon: Icons.grid_view_rounded,
                                  value: posts.length,
                                  label: 'Posts',
                                ),
                                ProfileStat(
                                  icon: Icons.people_alt_rounded,
                                  value: follows.followers.length,
                                  label: 'Seguidores',
                                  onTap: () => ConnectionsScreen.open(
                                    context,
                                    title: 'Seus seguidores',
                                    userIds: follows.followersOf(user.id),
                                    emptyText:
                                        'Ninguém se conectou com você ainda.',
                                  ),
                                ),
                                ProfileStat(
                                  icon: Icons.link_rounded,
                                  value: follows.following.length,
                                  label: 'Conexões',
                                  onTap: () => ConnectionsScreen.open(
                                    context,
                                    title: 'Suas conexões',
                                    userIds: follows.followingOf(user.id),
                                    emptyText:
                                        'Você ainda não se conectou com '
                                        'ninguém. Toque em alguém no feed '
                                        'ou na busca e escolha Conectar.',
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
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: ProfileOutlinedButton(
                              icon: Icons.edit_outlined,
                              label: 'Editar perfil',
                              onPressed: () => EditProfileScreen.open(context),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: InterestsCard(
                              interests: user.interests,
                              empty: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Conte do que você curte no rolê.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        EditProfileScreen.open(context),
                                    child: const Text('Adicionar'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: FavoriteVenuesCard(
                              visits: user.visits,
                              title: 'Onde mais vou',
                              emptyText:
                                  'Seus check-ins nos locais do mapa '
                                  'aparecem aqui.',
                            ),
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: ProfileTabsHeader(
                            gridTab: _gridTab,
                            onChanged: (grid) =>
                                setState(() => _gridTab = grid),
                          ),
                        ),
                        ProfilePostsSliver(posts: posts, gridTab: _gridTab),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}
