import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/posts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
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
    final authorId = context.read<AuthProvider>().currentUser?.id;
    if (authorId == null) return;

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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 14.0),
              TextField(
                controller: _contentController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'O que tá rolando?'),
              ),
              const SizedBox(height: 14.0),
              GradientButton(
                label: 'Publicar',
                onPressed: () {
                  final content = _contentController.text.trim();
                  if (content.isEmpty) return;
                  context.read<PostsProvider>().addPost(
                        title: 'Novo rolê',
                        content: content,
                        authorId: authorId,
                      );
                  _contentController.clear();
                  Navigator.pop(context);
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
    final postsProvider = context.read<PostsProvider>();
    final auth = context.watch<AuthProvider>();

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
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Spacer(),
                    InitialAvatar(name: auth.currentUser?.name ?? '?', radius: 18),
                  ],
                ),
              ),
              SizedBox(
                height: 84,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        itemCount: posts.length,
                        separatorBuilder: (context, index) => const Divider(height: 32),
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return _PostTile(
                            authorName: postsProvider.authorName(post.authorId),
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
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.0),
          ),
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.authorName, required this.post, required this.timeAgo});

  final String authorName;
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
            Text(authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.0)),
            const SizedBox(width: 8.0),
            Text('· $timeAgo', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12.0)),
          ],
        ),
        const SizedBox(height: 8.0),
        Text(post.content, style: const TextStyle(color: Colors.white, fontSize: 14.0, height: 1.3)),
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
