import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/venue_catalog.dart';
import '../../models/posts.dart';
import '../../models/venue.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../user_profile_screen.dart';
import 'media_view.dart';
import 'user_avatar.dart';

const _likeColor = Color(0xFFEC4899);

/// Post: autor no topo (toque abre o perfil), texto, mídias e ações.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onOpen,
    this.framed = false,
    this.linkAuthor = true,
  });

  final Posts post;

  /// Toque no post e no botão de respostas (no feed, abre a conversa).
  final VoidCallback? onOpen;

  /// Em cartão próprio (feed e perfis); sem cartão na tela do post.
  final bool framed;

  /// Avatar e nome abrem o perfil de quem escreveu. Desligado quando já
  /// estamos nesse perfil.
  final bool linkAuthor;

  void _openAuthor(BuildContext context) {
    UserProfileScreen.openAuthor(
      context,
      userId: post.authorId,
      name: post.authorName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().currentUser?.id;
    final venue = findVenue(post.venueId);
    final liked = post.isLikedBy(myId);
    final onAuthorTap = linkAuthor ? () => _openAuthor(context) : null;

    final content = InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AuthorLink(
                  onTap: onAuthorTap,
                  label: 'Ver perfil de ${post.authorName}',
                  circle: true,
                  child: AuthorAvatar(
                    userId: post.authorId,
                    name: post.authorName,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: _AuthorLink(
                              onTap: onAuthorTap,
                              label: 'Ver perfil de ${post.authorName}',
                              child: Text(
                                post.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            '  ·  ${formatTimeAgo(post.createdAt)}',
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (venue != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: VenueTag(venue: venue, atVenue: post.atVenue),
                        ),
                    ],
                  ),
                ),
                if (post.authorId == myId)
                  _PostMenu(post: post)
                else
                  const SizedBox(width: 8),
              ],
            ),
            if (post.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 8),
                child: Text(
                  post.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            if (post.media.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 8),
                child: PostMediaGallery(media: post.media),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  _ActionButton(
                    icon: liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? _likeColor : AppColors.textSecondary,
                    count: post.likeCount,
                    tooltip: liked ? 'Descurtir' : 'Curtir',
                    onTap: () => context.read<PostsProvider>().toggleLike(post),
                  ),
                  _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    color: AppColors.textSecondary,
                    count: post.replyCount,
                    tooltip: 'Responder',
                    onTap: onOpen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!framed) return content;
    // Posts feitos com check-in no local ganham a borda do selo.
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: post.atVenue
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: content,
    );
  }
}

/// Avatar ou nome de quem escreveu, tocável para abrir o perfil.
class _AuthorLink extends StatelessWidget {
  const _AuthorLink({
    required this.onTap,
    required this.label,
    required this.child,
    this.circle = false,
  });

  final VoidCallback? onTap;
  final String label;
  final Widget child;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: circle ? const CircleBorder() : null,
        borderRadius: circle ? null : BorderRadius.circular(6),
        child: child,
      ),
    );
  }
}

/// Local marcado num post ou story, com o selo "no rolê agora" quando o autor
/// tinha check-in ativo ali.
class VenueTag extends StatelessWidget {
  const VenueTag({super.key, required this.venue, required this.atVenue});

  final Venue venue;
  final bool atVenue;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on,
              color: AppColors.primarySoft,
              size: 14,
            ),
            const SizedBox(width: 2),
            Text(
              venue.name,
              style: const TextStyle(
                color: AppColors.primarySoft,
                fontSize: 12,
              ),
            ),
          ],
        ),
        if (atVenue)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: AppColors.success, size: 12),
                SizedBox(width: 3),
                Text(
                  'no rolê agora',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final int count;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(icon, key: ValueKey(icon), color: color, size: 20),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostMenu extends StatelessWidget {
  const _PostMenu({required this.post});

  final Posts post;

  Future<void> _confirmDelete(BuildContext context) async {
    final posts = context.read<PostsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: const Text('Apagar post?'),
        content: const Text('Ele sai do feed e do seu perfil.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await posts.deletePost(post);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      icon: const Icon(
        Icons.more_horiz,
        color: AppColors.textTertiary,
        size: 20,
      ),
      color: AppColors.surfaceHigh,
      itemBuilder: (context) => [
        PopupMenuItem(
          onTap: () => _confirmDelete(context),
          child: const Text('Apagar post'),
        ),
      ],
    );
  }
}
