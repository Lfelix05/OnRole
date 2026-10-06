import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../data/venue_catalog.dart';
import '../models/media.dart';
import '../models/story.dart';
import '../providers/auth_provider.dart';
import '../providers/media_loader.dart';
import '../providers/presence_provider.dart';
import '../providers/stories_provider.dart';
import '../services/media_drafts.dart'
    show displayAspectRatio, maxRecordingDuration;
import '../services/video_source.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'widgets/media_view.dart';
import 'widgets/post_card.dart';

/// Quanto tempo uma foto fica na tela.
const _photoDuration = Duration(seconds: 5);

/// Stories em tela cheia: toque à direita avança, à esquerda volta, segurar
/// pausa e arrastar para baixo fecha. Ao acabar os stories de uma pessoa,
/// passa para a próxima.
class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.groups,
    required this.initialGroup,
  });

  final List<StoryGroup> groups;
  final int initialGroup;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _next();
    });
  late int _group = widget.initialGroup;
  late int _index = context.read<StoriesProvider>().firstUnseenIndex(
    widget.groups[_group],
  );
  VideoPlayerController? _video;

  StoryGroup get _currentGroup => widget.groups[_group];

  Story get _story => _currentGroup.stories[_index];

  @override
  void initState() {
    super.initState();
    _show();
  }

  void _show() {
    final story = _story;
    _video = null;
    _progress
      ..stop()
      ..value = 0;
    // Depois do quadro: marcar como visto atualiza a fileira de stories.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StoriesProvider>().markSeen(story);
    });
    if (story.media.isVideo) {
      // O tempo começa quando o vídeo estiver pronto (ver _onVideoReady).
      _progress.duration = story.media.duration ?? maxRecordingDuration;
    } else {
      _progress.duration = _photoDuration;
      context.read<MediaLoader>().load(story.media).then((_) {
        if (mounted && _story.id == story.id) _progress.forward(from: 0);
      }, onError: (Object _) {});
    }
  }

  void _onVideoReady(VideoPlayerController controller) {
    _video = controller;
    if (controller.value.duration > Duration.zero) {
      _progress.duration = controller.value.duration;
    }
    _progress.forward(from: 0);
  }

  void _next() {
    if (_index < _currentGroup.stories.length - 1) {
      setState(() => _index++);
    } else if (_group < widget.groups.length - 1) {
      setState(() {
        _group++;
        _index = context.read<StoriesProvider>().firstUnseenIndex(
          _currentGroup,
        );
      });
    } else {
      Navigator.pop(context);
      return;
    }
    _show();
  }

  void _previous() {
    if (_index > 0) {
      setState(() => _index--);
    } else if (_group > 0) {
      setState(() {
        _group--;
        _index = 0;
      });
    }
    _show();
  }

  void _pause() {
    _progress.stop();
    _video?.pause();
  }

  void _resume() {
    if (_progress.duration != null &&
        (!_story.media.isVideo || _video != null)) {
      _progress.forward();
    }
    _video?.play();
  }

  Future<void> _delete() async {
    _pause();
    final stories = context.read<StoriesProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = await stories.deleteStory(_story);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      _resume();
      return;
    }
    navigator.pop();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final venue = findVenue(story.venueId);
    // Como no Instagram: mídia em pé preenche a tela; deitada aparece inteira.
    final fit = story.media.aspectRatio < 1 ? BoxFit.cover : BoxFit.contain;
    final isMine =
        story.authorId == context.read<AuthProvider>().currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final width = MediaQuery.sizeOf(context).width;
          details.localPosition.dx < width / 3 ? _previous() : _next();
        },
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) Navigator.pop(context);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Os toques são da tela de stories, não do player.
            IgnorePointer(
              child: story.media.isVideo
                  ? MediaVideo(
                      key: ValueKey(story.id),
                      media: story.media,
                      autoplay: true,
                      looping: false,
                      fit: fit,
                      onReady: _onVideoReady,
                    )
                  : MediaImage(
                      key: ValueKey(story.id),
                      media: story.media,
                      fit: fit,
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) => Row(
                        children: [
                          for (var i = 0; i < _currentGroup.stories.length; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: i < _index
                                        ? 1
                                        : i == _index
                                        ? _progress.value
                                        : 0,
                                    minHeight: 2.5,
                                    color: Colors.white,
                                    backgroundColor: Colors.white30,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        InitialAvatar(name: story.authorName, radius: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            story.authorName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatTimeAgo(story.createdAt),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const Spacer(),
                        if (isMine)
                          IconButton(
                            tooltip: 'Apagar story',
                            onPressed: _delete,
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                          ),
                        IconButton(
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                    if (venue != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: VenueTag(venue: venue, atVenue: story.atVenue),
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

/// Prévia do que foi capturado antes de virar story.
class StoryPublishScreen extends StatefulWidget {
  const StoryPublishScreen({super.key, required this.draft});

  final MediaDraft draft;

  static Future<void> open(BuildContext context, MediaDraft draft) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StoryPublishScreen(draft: draft),
      ),
    );
  }

  @override
  State<StoryPublishScreen> createState() => _StoryPublishScreenState();
}

class _StoryPublishScreenState extends State<StoryPublishScreen> {
  late bool _atVenue = context.read<PresenceProvider>().checkedInVenue != null;
  double? _progress;

  Future<void> _publish() async {
    final venue = context.read<PresenceProvider>().checkedInVenue;
    setState(() => _progress = 0);
    final error = await context.read<StoriesProvider>().publish(
      widget.draft,
      venueId: _atVenue ? venue?.id : null,
      atVenue: _atVenue && venue != null,
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _progress = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final venue = context.watch<PresenceProvider>().checkedInVenue;
    final publishing = _progress != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: widget.draft.isVideo
                ? _DraftVideo(draft: widget.draft)
                : Image.memory(widget.draft.bytes, fit: BoxFit.contain),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Descartar',
                onPressed: publishing ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (venue != null)
                      FilterChip(
                        selected: _atVenue,
                        onSelected: publishing
                            ? null
                            : (value) => setState(() => _atVenue = value),
                        avatar: const Icon(
                          Icons.verified,
                          color: AppColors.success,
                          size: 16,
                        ),
                        label: Text('No rolê agora: ${venue.name}'),
                        backgroundColor: AppColors.surface,
                        selectedColor: AppColors.success.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (publishing)
                      LinearProgressIndicator(
                        value: _progress,
                        color: AppColors.primary,
                        backgroundColor: Colors.white24,
                      )
                    else
                      GradientButton(
                        label: 'Publicar story',
                        onPressed: _publish,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vídeo ainda no aparelho, tocando em loop na prévia.
class _DraftVideo extends StatefulWidget {
  const _DraftVideo({required this.draft});

  final MediaDraft draft;

  @override
  State<_DraftVideo> createState() => _DraftVideoState();
}

class _DraftVideoState extends State<_DraftVideo> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final controller = await videoControllerFromBytes(
      'previa_${DateTime.now().microsecondsSinceEpoch}',
      widget.draft.bytes,
      widget.draft.mimeType,
    );
    await controller.initialize();
    await controller.setLooping(true);
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
    await controller.play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return AspectRatio(
      aspectRatio: displayAspectRatio(controller.value),
      child: VideoPlayer(controller),
    );
  }
}
