import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/venue_catalog.dart';
import '../../models/posts.dart';
import '../../models/venue.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import 'media_view.dart';

const _likeColor = Color(0xFFEC4899);

/// Post no estilo do Threads: avatar ao lado, texto, mídias e ações.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onOpen});

  final Posts post;

  /// Toque no post e no botão de respostas (no feed, abre a conversa).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().currentUser?.id;
    final venue = findVenue(post.venueId);
    final liked = post.isLikedBy(myId);

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialAvatar(name: post.authorName, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
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
                      const SizedBox(width: 6),
                      Text(
                        formatTimeAgo(post.createdAt),
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (post.authorId == myId) _PostMenu(post: post),
                    ],
                  ),
                  if (venue != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: VenueTag(venue: venue, atVenue: post.atVenue),
                    ),
                  if (post.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Text(
                        post.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                    ),
                  if (post.media.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 8),
                      child: PostMediaGallery(media: post.media),
                    ),
                  Row(
                    children: [
                      _ActionButton(
                        icon: liked ? Icons.favorite : Icons.favorite_border,
                        color: liked ? _likeColor : AppColors.textSecondary,
                        count: post.likeCount,
                        tooltip: liked ? 'Descurtir' : 'Curtir',
                        onTap: () =>
                            context.read<PostsProvider>().toggleLike(post),
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
                ],
              ),
            ),
          ],
        ),
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
