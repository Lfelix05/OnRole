import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/posts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/presence_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../post_detail_screen.dart';
import '../widgets/media_view.dart';
import '../widgets/post_card.dart';

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

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: user == null
              ? Center(
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
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                onPressed: _logout,
                                icon: const Icon(
                                  Icons.logout,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InitialAvatar(name: user.name, radius: 44),
                        const SizedBox(height: 12.0),
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          '@${user.name.toLowerCase().replaceAll(' ', '')}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (user.bio != null) ...[
                          const SizedBox(height: 10.0),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32.0,
                            ),
                            child: Text(
                              user.bio!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _StatColumn(
                              value: '${posts.length}',
                              label: 'Posts',
                            ),
                            const SizedBox(width: 32.0),
                            const _StatColumn(value: '0', label: 'Seguidores'),
                            const SizedBox(width: 32.0),
                            const _StatColumn(value: '0', label: 'Seguindo'),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        Row(
                          children: [
                            Expanded(
                              child: _TabButton(
                                icon: Icons.reorder,
                                selected: !_gridTab,
                                onTap: () => setState(() => _gridTab = false),
                              ),
                            ),
                            Expanded(
                              child: _TabButton(
                                icon: Icons.grid_on,
                                selected: _gridTab,
                                onTap: () => setState(() => _gridTab = true),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: posts.isEmpty
                              ? Center(
                                  child: Text(
                                    'Nenhum post ainda.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                )
                              : _gridTab
                              ? GridView.builder(
                                  padding: const EdgeInsets.all(2),
                                  itemCount: posts.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        mainAxisSpacing: 2,
                                        crossAxisSpacing: 2,
                                      ),
                                  itemBuilder: (context, index) => _GridTile(
                                    post: posts[index],
                                    onTap: () => _open(posts[index]),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: posts.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) => PostCard(
                                    post: posts[index],
                                    onOpen: () => _open(posts[index]),
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

/// Quadrado da grade: a primeira foto/vídeo do post, ou o começo do texto.
class _GridTile extends StatelessWidget {
  const _GridTile({required this.post, required this.onTap});

  final Posts post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final media = post.media.isEmpty ? null : post.media.first;
    return GestureDetector(
      onTap: onTap,
      child: media == null
          ? Container(
              color: AppColors.surfaceHigh,
              padding: const EdgeInsets.all(8),
              child: Text(
                post.text,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
          : Stack(
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
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Icon(
          icon,
          color: selected ? Colors.white : AppColors.textTertiary,
        ),
      ),
    );
  }
}
