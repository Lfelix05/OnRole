import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/posts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/presence_provider.dart';
import '../../providers/venues_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _openNewPostSheet() {
    final author = context.read<AuthProvider>().currentUser;
    if (author == null) return;

    final venue = context.read<PresenceProvider>().checkedInVenue;
    if (venue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para postar, você precisa estar num rolê. O check-in é automático quando você chega a um local do mapa.',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 20.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Novo post',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4.0),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.success,
                    size: 14,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    venue.name,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14.0),
              TextField(
                controller: _contentController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'O que tá rolando?',
                ),
              ),
              const SizedBox(height: 14.0),
              GradientButton(
                label: 'Publicar',
                onPressed: () {
                  final content = _contentController.text.trim();
                  if (content.isEmpty) return;
                  // O check-in pode ter caído com a folha aberta.
                  if (context.read<PresenceProvider>().checkedInVenue?.id !=
                      venue.id) {
                    Navigator.pop(context);
                    return;
                  }
                  final result = context.read<PostsProvider>().addPost(
                    author: author,
                    venueId: venue.id,
                    content: content,
                  );
                  _contentController.clear();
                  Navigator.pop(context);
                  // O servidor ainda pode recusar (ex.: check-in expirou).
                  result.then((error) {
                    if (error == null || !mounted) return;
                    ScaffoldMessenger.of(
                      this.context,
                    ).showSnackBar(SnackBar(content: Text(error)));
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final posts = context.watch<PostsProvider>().posts;
    final venues = context.read<VenuesProvider>();
    final auth = context.watch<AuthProvider>();
    final checkedInVenue = context.watch<PresenceProvider>().checkedInVenue;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewPostSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    const Text(
                      'OnRolê',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    InitialAvatar(
                      name: auth.currentUser?.name ?? '?',
                      radius: 18,
                    ),
                  ],
                ),
              ),
              if (checkedInVenue != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(
                          'Você está no rolê: ${checkedInVenue.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                height: 84,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    const _StoryItem(name: 'Você', ringColor: AppColors.border),
                    for (final user in auth.otherUsers)
                      _StoryItem(name: user.name, ringColor: AppColors.primary),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: posts.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum post ainda.\nSeja o primeiro a compartilhar o rolê!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        itemCount: posts.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 32),
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return _PostTile(
                            authorName: post.authorName,
                            venueName: venues.venueById(post.venueId)?.name,
                            post: post,
                            timeAgo: _timeAgo(post.createdAt),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  const _StoryItem({required this.name, required this.ringColor});

  final String name;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: Column(
        children: [
          InitialAvatar(name: name, radius: 26, ringColor: ringColor),
          const SizedBox(height: 6.0),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({
    required this.authorName,
    required this.venueName,
    required this.post,
    required this.timeAgo,
  });

  final String authorName;
  final String? venueName;
  final Posts post;
  final String timeAgo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InitialAvatar(name: authorName, radius: 16),
            const SizedBox(width: 10.0),
            Text(
              authorName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.0,
              ),
            ),
            const SizedBox(width: 8.0),
            Text(
              '· $timeAgo',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12.0,
              ),
            ),
            if (venueName != null) ...[
              const SizedBox(width: 8.0),
              const Icon(
                Icons.location_on,
                color: AppColors.primarySoft,
                size: 13,
              ),
              const SizedBox(width: 2.0),
              Flexible(
                child: Text(
                  venueName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primarySoft,
                    fontSize: 12.0,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8.0),
        Text(
          post.content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.0,
            height: 1.3,
          ),
        ),
        if (post.type != PostType.text) ...[
          const SizedBox(height: 10.0),
          SizedBox(
            height: 160,
            child: MediaPlaceholder(showPlayIcon: post.type == PostType.video),
          ),
        ],
      ],
    );
  }
}
