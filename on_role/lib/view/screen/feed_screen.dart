import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/presence_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../compose_screen.dart';
import '../post_detail_screen.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_bar.dart';

/// Início: stories no topo e o feed no estilo do Threads, com os posts mais
/// recentes primeiro.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final postsProvider = context.watch<PostsProvider>();
    final posts = postsProvider.posts;
    final me = context.watch<AuthProvider>().currentUser;
    final checkedInVenue = context.watch<PresenceProvider>().checkedInVenue;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo post',
        onPressed: () => ComposeScreen.open(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                      InitialAvatar(name: me?.name ?? '?', radius: 18),
                    ],
                  ),
                ),
              ),
              if (checkedInVenue != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Você está no rolê: ${checkedInVenue.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.success,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: StoriesBar()),
              const SliverToBoxAdapter(child: Divider(height: 1)),
              SliverToBoxAdapter(child: _ComposePrompt(name: me?.name ?? '?')),
              const SliverToBoxAdapter(child: Divider(height: 1)),
              if (!postsProvider.isLoaded)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (posts.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Nenhum post ainda.\nChame a galera para o primeiro rolê!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: posts.length + (postsProvider.hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == posts.length) {
                      return Center(
                        child: TextButton(
                          onPressed: postsProvider.loadMore,
                          child: const Text('Carregar mais'),
                        ),
                      );
                    }
                    final post = posts[index];
                    return PostCard(
                      post: post,
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(post: post),
                        ),
                      ),
                    );
                  },
                ),
              // Espaço para o botão flutuante não cobrir o último post.
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Atalho no topo do feed, como no Threads.
class _ComposePrompt extends StatelessWidget {
  const _ComposePrompt({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => ComposeScreen.open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            InitialAvatar(name: name, radius: 18),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'O que tá rolando?',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 15),
              ),
            ),
            const Icon(
              Icons.photo_library_outlined,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
