import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/venue_catalog.dart';
import '../../models/posts.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../services/text_search.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../post_detail_screen.dart';
import '../user_profile_screen.dart';
import '../widgets/media_view.dart';
import '../widgets/user_avatar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  bool _peopleOnly = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final postsProvider = context.watch<PostsProvider>();
    final query = _query.text.trim();

    final people = [
      for (final user in auth.otherUsers)
        if (matchesSearch(query, [
          user.name,
          user.handle,
          user.bio,
          ...user.interests,
        ]))
          user,
    ];
    // Só posts com foto ou vídeo: a busca é uma vitrine visual, e os posts de
    // texto ficam no feed.
    final posts = _peopleOnly
        ? const <Posts>[]
        : [
            for (final post in postsProvider.posts)
              if (post.media.isNotEmpty &&
                  matchesSearch(query, [
                    post.text,
                    post.authorName,
                    findVenue(post.venueId)?.name,
                  ]))
                post,
          ];

    // Contagem sobre os posts já carregados no feed.
    int postCountOf(String userId) =>
        postsProvider.posts.where((post) => post.authorId == userId).length;
    Widget personCard(User user) =>
        _PersonCard(user: user, postCount: postCountOf(user.id));

    final items = <Widget>[];
    if (query.isNotEmpty || _peopleOnly) {
      // Buscando: primeiro as pessoas, depois os posts.
      items
        ..addAll(people.map(personCard))
        ..addAll(posts.map((post) => _PostCard(post: post)));
    } else {
      // Sem busca: posts e pessoas intercalados, como uma vitrine.
      var personIndex = 0;
      for (var i = 0; i < posts.length; i++) {
        items.add(_PostCard(post: posts[i]));
        if (personIndex < people.length && i.isOdd) {
          items.add(personCard(people[personIndex++]));
        }
      }
      while (personIndex < people.length) {
        items.add(personCard(people[personIndex++]));
      }
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'Buscar',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  padding: const EdgeInsets.only(left: 14, right: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _query,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Pessoas, gostos, posts ou locais',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      if (_query.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Limpar busca',
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          onPressed: () => setState(_query.clear),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      selected: !_peopleOnly,
                      onTap: () => setState(() => _peopleOnly = false),
                    ),
                    const SizedBox(width: 10.0),
                    _FilterChip(
                      label: 'Pessoas',
                      selected: _peopleOnly,
                      onTap: () => setState(() => _peopleOnly = true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            query.isEmpty
                                ? 'Nada por aqui ainda.'
                                : 'Nada encontrado para "$query".',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: items.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.82,
                            ),
                        itemBuilder: (context, index) => items[index],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final Posts post;

  @override
  Widget build(BuildContext context) {
    final image = post.media.where((item) => !item.isVideo).firstOrNull;
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PostDetailScreen(post: post))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              MediaImage(media: image)
            else
              const MediaPlaceholder(borderRadius: 0),
            if (post.media.first.isVideo || post.media.length > 1)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  post.media.first.isVideo ? Icons.videocam : Icons.collections,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      post.authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${post.likeCount} curtidas · ${post.replyCount} respostas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.user, required this.postCount});

  final User user;
  final int postCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => UserProfileScreen.open(context, user),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              UserAvatar(user: user, radius: 34),
              const SizedBox(height: 10),
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.handle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                postCount == 1 ? '1 post' : '$postCount posts',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                ),
              ),
              if (user.interests.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final interest in user.interests.take(2))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          interest,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primarySoft,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
