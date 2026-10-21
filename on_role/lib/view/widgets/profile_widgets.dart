import 'package:flutter/material.dart';

import '../../data/venue_catalog.dart';
import '../../models/posts.dart';
import '../../models/user.dart';
import '../../models/venue.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../post_detail_screen.dart';
import 'media_view.dart';
import 'post_card.dart';
import 'user_avatar.dart';

// Peças do perfil, usadas no seu perfil (aba Perfil) e no de outras pessoas.

/// Capa em gradiente, foto sobreposta, nome, @, selos e bio.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    this.actions = const [],
    this.badges = const [],
  });

  final User user;

  /// Botões no canto da capa.
  final List<Widget> actions;

  /// Selos abaixo do @ (ex.: experimento, "conectou com você").
  final List<Widget> badges;

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
                  if (actions.isNotEmpty)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        children: [
                          for (final (index, action) in actions.indexed) ...[
                            if (index > 0) const SizedBox(width: 8),
                            action,
                          ],
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            user.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          user.handle,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: badges,
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

/// Botão redondo sobre a capa.
class CoverButton extends StatelessWidget {
  const CoverButton({
    super.key,
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

/// Selo arredondado abaixo do nome.
class ProfileBadge extends StatelessWidget {
  const ProfileBadge({
    super.key,
    required this.icon,
    required this.label,
    this.color = AppColors.primarySoft,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Superfície arredondada usada pelas seções do perfil.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

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

class ProfileStat {
  const ProfileStat({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;

  /// Null enquanto carrega.
  final int? value;
  final String label;
  final VoidCallback? onTap;
}

/// Números do perfil lado a lado (posts, seguidores, conexões, rolês).
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({super.key, required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, stat) in stats.indexed) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: _StatCard(stat: stat)),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final ProfileStat stat;

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
        onTap: stat.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Icon(stat.icon, size: 18, color: AppColors.primarySoft),
              const SizedBox(height: 6),
              Text(
                stat.value == null ? '–' : '${stat.value}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  stat.label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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

/// Botão largo e contornado (ex.: "Editar perfil").
class ProfileOutlinedButton extends StatelessWidget {
  const ProfileOutlinedButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
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

class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle({
    super.key,
    required this.icon,
    required this.title,
  });

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

/// "Gostos de rolê". No perfil de outra pessoa, [shared] destaca o que vocês
/// têm em comum.
class InterestsCard extends StatelessWidget {
  const InterestsCard({
    super.key,
    required this.interests,
    required this.empty,
    this.shared,
  });

  final List<String> interests;

  /// O que aparece quando a pessoa não escolheu nenhum gosto.
  final Widget empty;

  /// Gostos em comum com quem está vendo; null no próprio perfil.
  final Set<String>? shared;

  @override
  Widget build(BuildContext context) {
    final shared = this.shared;
    final hasShared = shared != null && interests.any(shared.contains);
    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileSectionTitle(
            icon: Icons.local_activity_outlined,
            title: 'Gostos de rolê',
          ),
          const SizedBox(height: 12),
          if (interests.isEmpty)
            empty
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in interests)
                  _InterestChip(
                    label: interest,
                    // Quem vê o perfil de outra pessoa: o que é em comum
                    // ganha destaque e o resto fica neutro.
                    style: shared == null
                        ? _ChipStyle.tinted
                        : shared.contains(interest)
                        ? _ChipStyle.shared
                        : _ChipStyle.neutral,
                  ),
              ],
            ),
          if (hasShared) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppColors.primarySoft,
                ),
                SizedBox(width: 6),
                Text(
                  'Em comum com você',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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

enum _ChipStyle { tinted, shared, neutral }

class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.label, required this.style});

  final String label;
  final _ChipStyle style;

  @override
  Widget build(BuildContext context) {
    final (background, border) = switch (style) {
      _ChipStyle.tinted => (
        AppColors.primary.withValues(alpha: 0.14),
        AppColors.primary.withValues(alpha: 0.35),
      ),
      _ChipStyle.shared => (
        AppColors.primary.withValues(alpha: 0.32),
        AppColors.primarySoft,
      ),
      _ChipStyle.neutral => (AppColors.surfaceHigh, AppColors.border),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (style == _ChipStyle.shared) ...[
            const Icon(Icons.check, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: style == _ChipStyle.neutral
                  ? AppColors.textSecondary
                  : Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Os locais com mais check-ins da pessoa. [shared] marca os que quem está
/// vendo também frequenta.
class FavoriteVenuesCard extends StatelessWidget {
  const FavoriteVenuesCard({
    super.key,
    required this.visits,
    required this.title,
    required this.emptyText,
    this.shared = const {},
  });

  final Map<String, int> visits;
  final String title;
  final String emptyText;
  final Set<String> shared;

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

    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileSectionTitle(icon: Icons.place_outlined, title: title),
          const SizedBox(height: 12),
          if (top.isEmpty)
            Text(
              emptyText,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
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
                  if (shared.contains(item.venue.id)) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'você também',
                        style: TextStyle(
                          color: AppColors.primarySoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
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
class ProfileTabsHeader extends SliverPersistentHeaderDelegate {
  ProfileTabsHeader({required this.gridTab, required this.onChanged});

  final bool gridTab;
  final ValueChanged<bool> onChanged;

  static const _height = 64.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(ProfileTabsHeader oldDelegate) =>
      oldDelegate.gridTab != gridTab;

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

/// Posts do perfil: na grade, só os com foto ou vídeo; na lista, só os de
/// texto. É um sliver (vai direto num CustomScrollView).
class ProfilePostsSliver extends StatelessWidget {
  const ProfilePostsSliver({
    super.key,
    required this.posts,
    required this.gridTab,
    this.loaded = true,
  });

  final List<Posts> posts;
  final bool gridTab;

  /// Falso até os posts chegarem do banco.
  final bool loaded;

  void _open(BuildContext context, Posts post) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final shown = [
      for (final post in posts)
        if (post.media.isNotEmpty == gridTab) post,
    ];
    if (shown.isEmpty) {
      return SliverToBoxAdapter(child: _EmptyPosts(gridTab: gridTab));
    }
    if (gridTab) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        sliver: SliverGrid.builder(
          itemCount: shown.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) => _GridTile(
            post: shown[index],
            onTap: () => _open(context, shown[index]),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      sliver: SliverList.separated(
        itemCount: shown.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => PostCard(
          post: shown[index],
          framed: true,
          // Já estamos no perfil de quem escreveu.
          linkAuthor: false,
          onOpen: () => _open(context, shown[index]),
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
      child: ProfileCard(
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
