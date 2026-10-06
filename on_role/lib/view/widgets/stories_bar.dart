import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/story.dart';
import '../../providers/auth_provider.dart';
import '../../providers/stories_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../camera_screen.dart';
import '../story_viewer.dart';

/// Fileira de stories no topo do feed, como no Instagram.
class StoriesBar extends StatelessWidget {
  const StoriesBar({super.key});

  static Future<void> createStory(BuildContext context) async {
    final draft = await CameraCaptureScreen.open(context);
    if (draft == null || !context.mounted) return;
    await StoryPublishScreen.open(context, draft);
  }

  void _openViewer(BuildContext context, List<StoryGroup> groups, int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StoryViewerScreen(groups: groups, initialGroup: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stories = context.watch<StoriesProvider>();
    final me = context.watch<AuthProvider>().currentUser;
    final groups = stories.groups;
    final mineIndex = groups.indexWhere((group) => group.authorId == me?.id);

    return SizedBox(
      height: 106,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: [
          _StoryBubble(
            label: 'Seu story',
            name: me?.name ?? '?',
            ring: mineIndex == -1
                ? _Ring.none
                : stories.hasUnseen(groups[mineIndex])
                ? _Ring.unseen
                : _Ring.seen,
            onTap: mineIndex == -1
                ? () => createStory(context)
                : () => _openViewer(context, groups, mineIndex),
            onAdd: () => createStory(context),
          ),
          for (var i = 0; i < groups.length; i++)
            if (i != mineIndex)
              _StoryBubble(
                label: groups[i].authorName,
                name: groups[i].authorName,
                ring: stories.hasUnseen(groups[i]) ? _Ring.unseen : _Ring.seen,
                onTap: () => _openViewer(context, groups, i),
              ),
        ],
      ),
    );
  }
}

enum _Ring { none, unseen, seen }

class _StoryBubble extends StatelessWidget {
  const _StoryBubble({
    required this.label,
    required this.name,
    required this.ring,
    required this.onTap,
    this.onAdd,
  });

  final String label;
  final String name;
  final _Ring ring;
  final VoidCallback onTap;

  /// Mostra o "+" para criar um story.
  final VoidCallback? onAdd;

  static const _unseenGradient = LinearGradient(
    colors: [Color(0xFFA855F7), Color(0xFFEC4899), Color(0xFFF59E0B)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ring == _Ring.unseen ? _unseenGradient : null,
                    color: ring == _Ring.seen ? AppColors.border : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background,
                    ),
                    child: InitialAvatar(name: name, radius: 27),
                  ),
                ),
                if (onAdd != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.background,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
