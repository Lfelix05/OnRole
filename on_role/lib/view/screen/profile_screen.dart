import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/venue_catalog.dart';
import '../../models/posts.dart';
import '../../models/user.dart';
import '../../models/venue.dart';
import '../../providers/auth_provider.dart';
import '../../providers/experiment_provider.dart';
import '../../providers/match_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/presence_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../edit_profile_screen.dart';
import '../experiment_screen.dart';
import '../matches_screen.dart';
import '../post_detail_screen.dart';
import '../widgets/media_view.dart';
import '../widgets/post_card.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _gridTab = false;
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

  void _open(Posts post) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
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
    final matchCount = context.watch<MatchProvider>().matches.length;

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
                    // Grade: só posts com foto ou vídeo. Lista: só os de texto.
                    final shown = [
                      for (final post in posts)
                        if (post.media.isNotEmpty == _gridTab) post,
                    ];
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _Header(
                            user: user,
                            enrolled: enrolled,
                            onExperiment: () => ExperimentScreen.open(context),
                            onLogout: _logout,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.grid_view_rounded,
                                    value: posts.length,
                                    label: 'Posts',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.favorite_rounded,
                                    value: matchCount,
                                    label: 'Conexões',
                                    onTap: () => MatchesScreen.open(context),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatCard(
                                    icon: Icons.place_rounded,
                                    value: user.visits.values.fold(
                                      0,
                                      (sum, count) => sum + count,
                                    ),
                                    label: 'Rolês',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: _EditButton(
                              onPressed: () => EditProfileScreen.open(context),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: _InterestsCard(user: user),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: _FavoriteVenuesCard(visits: user.visits),
                          ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _TabsHeader(
                            gridTab: _gridTab,
                            onChanged: (grid) =>
                                setState(() => _gridTab = grid),
                          ),
                        ),
                        if (shown.isEmpty)
                          SliverToBoxAdapter(
                            child: _EmptyPosts(gridTab: _gridTab),
                          )
                        else if (_gridTab)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            sliver: SliverGrid.builder(
                              itemCount: shown.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 4,
                                    crossAxisSpacing: 4,
                                  ),
                              itemBuilder: (context, index) => _GridTile(
                                post: shown[index],
                                onTap: () => _open(shown[index]),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            sliver: SliverList.separated(
                              itemCount: shown.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) => _Card(
                                padding: EdgeInsets.zero,
                                child: PostCard(
                                  post: shown[index],
                                  onOpen: () => _open(shown[index]),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// Capa em gradiente, foto sobreposta, nome, @ e bio.
class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.enrolled,
    required this.onExperiment,
    required this.onLogout,
  });

  final User user;
  final bool enrolled;
  final VoidCallback onExperiment;
  final VoidCallback onLogout;

  static const _coverHeight = 128.0;
  static const _avatarRadius = 46.0;

  @override
  Widget build(BuildContext context) {
    final bio = user.bio;
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              height: _coverHeight,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6D28D9),
                    Color(0xFFA855F7),
                    Color(0xFFEC4899),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // Detalhe sutil na capa.
                  Positioned(
                    right: -18,
                    bottom: -28,
                    child: Icon(
                      Icons.nightlife_rounded,
                      size: 140,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        _CoverButton(
                          tooltip: 'Experimento do TCC',
                          icon: enrolled
                              ? Icons.science
                              : Icons.science_outlined,
                          highlighted: enrolled,
                          onPressed: onExperiment,
                        ),
                        const SizedBox(width: 8),
                        _CoverButton(
                          tooltip: 'Sair',
                          icon: Icons.logout,
                          onPressed: onLogout,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8 + _coverHeight - _avatarRadius - 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: UserAvatar(user: user, radius: _avatarRadius),
              ),
            ),
          ],
        ),
        const SizedBox(height: _avatarRadius + 12),
        Text(
          user.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '@${user.name.toLowerCase().replaceAll(' ', '')}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        if (enrolled) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.science, size: 14, color: AppColors.primarySoft),
                SizedBox(width: 6),
                Text(
                  'Participando do experimento',
                  style: TextStyle(color: AppColors.primarySoft, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
        if (bio != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CoverButton extends StatelessWidget {
  const _CoverButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.highlighted = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: highlighted ? 0.45 : 0.25),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Superfície arredondada usada pelas seções do perfil.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, size: 18, color: AppColors.primarySoft),
              const SizedBox(height: 6),
              Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text(
          'Editar perfil',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(23),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primarySoft),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _InterestsCard extends StatelessWidget {
  const _InterestsCard({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.local_activity_outlined,
            title: 'Gostos de rolê',
          ),
          const SizedBox(height: 12),
          if (user.interests.isEmpty)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Conte do que você curte para receber conexões melhores.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => EditProfileScreen.open(context),
                  child: const Text('Adicionar'),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in user.interests)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      interest,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Os locais com mais check-ins da pessoa (a mesma base das Conexões).
class _FavoriteVenuesCard extends StatelessWidget {
  const _FavoriteVenuesCard({required this.visits});

  final Map<String, int> visits;

  static IconData _iconFor(VenueCategory category) => switch (category) {
    VenueCategory.bar => Icons.local_bar,
    VenueCategory.balada => Icons.nightlife,
    VenueCategory.evento => Icons.celebration,
    VenueCategory.praca => Icons.park,
  };

  @override
  Widget build(BuildContext context) {
    final top = [
      for (final entry in visits.entries)
        if (entry.value > 0 && findVenue(entry.key) != null)
          (venue: findVenue(entry.key)!, count: entry.value),
    ]..sort((a, b) => b.count.compareTo(a.count));

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.place_outlined,
            title: 'Onde mais vou',
          ),
          const SizedBox(height: 12),
          if (top.isEmpty)
            const Text(
              'Seus check-ins nos locais do mapa aparecem aqui.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          else
            for (final (index, item) in top.take(3).indexed) ...[
              if (index > 0) const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconFor(item.venue.category),
                      color: AppColors.primarySoft,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.venue.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          item.venue.category.label,
                          style: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.count == 1 ? '1 rolê' : '${item.count} rolês',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}

/// Seletor "Fotos e vídeos" / "Textos", fixo no topo ao rolar.
class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader({required this.gridTab, required this.onChanged});

  final bool gridTab;
  final ValueChanged<bool> onChanged;

  static const _height = 64.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_TabsHeader oldDelegate) => oldDelegate.gridTab != gridTab;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: _Segment(
                icon: Icons.grid_on,
                label: 'Fotos e vídeos',
                selected: gridTab,
                onTap: () => onChanged(true),
              ),
            ),
            Expanded(
              child: _Segment(
                icon: Icons.reorder,
                label: 'Textos',
                selected: !gridTab,
                onTap: () => onChanged(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.textTertiary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPosts extends StatelessWidget {
  const _EmptyPosts({required this.gridTab});

  final bool gridTab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: _Card(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            Icon(
              gridTab
                  ? Icons.photo_library_outlined
                  : Icons.chat_bubble_outline,
              color: AppColors.textTertiary,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              gridTab
                  ? 'Nenhuma foto ou vídeo ainda.'
                  : 'Nenhum post de texto ainda.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quadrado da grade: a primeira foto ou vídeo do post.
class _GridTile extends StatelessWidget {
  const _GridTile({required this.post, required this.onTap});

  final Posts post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final media = post.media.first;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            media.isVideo
                ? const MediaPlaceholder(borderRadius: 0)
                : MediaImage(media: media),
            if (media.isVideo || post.media.length > 1)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  media.isVideo ? Icons.videocam : Icons.collections,
                  color: Colors.white,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
