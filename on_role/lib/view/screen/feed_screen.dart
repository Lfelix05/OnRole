import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../models/venue.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/presence_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../compose_screen.dart';
import '../post_detail_screen.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_bar.dart';
import '../widgets/user_avatar.dart';

/// Início: stories no topo e os posts em cartões, os mais recentes primeiro.
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
              SliverToBoxAdapter(child: _Header(user: me)),
              if (checkedInVenue != null)
                SliverToBoxAdapter(
                  child: _CheckInBanner(venue: checkedInVenue),
                ),
              const SliverToBoxAdapter(child: StoriesBar()),
              SliverToBoxAdapter(child: _ComposePrompt(user: me)),
              if (!postsProvider.isLoaded)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (posts.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyFeed(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.separated(
                    itemCount: posts.length + (postsProvider.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == posts.length) {
                        return _LoadMoreButton(
                          onPressed: postsProvider.loadMore,
                        );
                      }
                      final post = posts[index];
                      return PostCard(
                        post: post,
                        framed: true,
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(post: post),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // Espaço para o botão flutuante não cobrir o último post.
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marca do app em gradiente e a foto de quem está logado.
class _Header extends StatelessWidget {
  const _Header({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFC4B5FD), Color(0xFFA855F7)],
                  ).createShader(bounds),
                  child: const Text(
                    'OnRolê',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Text(
                  'O que tá rolando por aí',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
              ],
            ),
          ),
          if (user != null)
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: UserAvatar(user: user!, radius: 17),
              ),
            ),
        ],
      ),
    );
  }
}

/// Aviso de check-in ativo, com atalho para postar do local.
class _CheckInBanner extends StatelessWidget {
  const _CheckInBanner({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Você está no rolê',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    venue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => ComposeScreen.open(context),
              style: TextButton.styleFrom(foregroundColor: AppColors.success),
              child: const Text('Postar daqui'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Atalho para escrever um post.
class _ComposePrompt extends StatelessWidget {
  const _ComposePrompt({required this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: () => ComposeScreen.open(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                user == null
                    ? const InitialAvatar(name: '?', radius: 18)
                    : UserAvatar(user: user!, radius: 18),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'O que tá rolando?',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primarySoft,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          shape: const StadiumBorder(),
        ),
        child: const Text('Carregar mais'),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.nightlife_rounded,
                color: AppColors.primarySoft,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nenhum post ainda.\nChame a galera para o primeiro rolê!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
