import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../models/media.dart';
import '../../providers/media_loader.dart';
import '../../services/media_drafts.dart' show displayAspectRatio;
import '../../services/video_source.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';

/// Foto guardada no banco.
class MediaImage extends StatefulWidget {
  const MediaImage({super.key, required this.media, this.fit = BoxFit.cover});

  final MediaRef media;
  final BoxFit fit;

  @override
  State<MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<MediaImage> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = context.read<MediaLoader>().load(widget.media);
  }

  @override
  void didUpdateWidget(MediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.id != widget.media.id) {
      _bytes = context.read<MediaLoader>().load(widget.media);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      // Já em memória: aparece no primeiro quadro, sem piscar o placeholder.
      initialData: context.read<MediaLoader>().cached(widget.media.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const _MediaError();
        final bytes = snapshot.data;
        if (bytes == null) return const MediaPlaceholder(borderRadius: 0);
        return LayoutBuilder(
          builder: (context, constraints) {
            return Image.memory(
              bytes,
              fit: widget.fit,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              cacheWidth: _decodeWidth(context, constraints),
            );
          },
        );
      },
    );
  }

  /// Decodifica só na resolução que a tela precisa, poupando memória.
  int? _decodeWidth(BuildContext context, BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      return null;
    }
    final neededWidth = widget.fit == BoxFit.cover
        ? math.max(
            constraints.maxWidth,
            constraints.maxHeight * widget.media.aspectRatio,
          )
        : constraints.maxWidth;
    return (neededWidth * MediaQuery.devicePixelRatioOf(context)).round();
  }
}

/// Vídeo guardado no banco. Com [autoplay] falso, só baixa quando a pessoa
/// toca no play: no feed isso evita gastar a cota gratuita com vídeos que
/// só passaram na rolagem.
class MediaVideo extends StatefulWidget {
  const MediaVideo({
    super.key,
    required this.media,
    this.autoplay = false,
    this.looping = true,
    this.fit = BoxFit.cover,
    this.onReady,
  });

  final MediaRef media;
  final bool autoplay;
  final bool looping;
  final BoxFit fit;

  /// Chamado quando o vídeo está pronto (o story usa para saber a duração).
  final ValueChanged<VideoPlayerController>? onReady;

  @override
  State<MediaVideo> createState() => _MediaVideoState();
}

class _MediaVideoState extends State<MediaVideo> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoplay) _prepare();
  }

  Future<void> _prepare() async {
    if (_loading || _controller != null) return;
    setState(() => _loading = true);
    final loader = context.read<MediaLoader>();
    try {
      final bytes = await loader.load(widget.media);
      final controller = await videoControllerFromBytes(
        widget.media.id,
        bytes,
        widget.media.mimeType,
      );
      await controller.initialize();
      await controller.setLooping(widget.looping);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
      widget.onReady?.call(controller);
      await controller.play();
    } catch (error) {
      debugPrint('MediaVideo: $error');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) {
      _prepare();
    } else if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const _MediaError();
    final controller = _controller;
    if (controller == null) {
      return GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const MediaPlaceholder(borderRadius: 0),
            Center(
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const _PlayBadge(),
            ),
            if (widget.media.duration != null)
              Positioned(
                left: 8,
                bottom: 8,
                child: _DurationLabel(duration: widget.media.duration!),
              ),
          ],
        ),
      );
    }

    final aspectRatio = displayAspectRatio(controller.value);
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: 1000 * aspectRatio,
                height: 1000,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (!value.isPlaying && !widget.autoplay)
                    const Center(child: _PlayBadge()),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: IconButton(
                      onPressed: () =>
                          controller.setVolume(value.volume > 0 ? 0 : 1),
                      icon: Icon(
                        value.volume > 0 ? Icons.volume_up : Icons.volume_off,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Fotos e vídeos de um post: um só ocupa a largura toda; vários viram um
/// carrossel horizontal, como no Threads.
class PostMediaGallery extends StatelessWidget {
  const PostMediaGallery({super.key, required this.media});

  final List<MediaRef> media;

  static const _height = 240.0;

  @override
  Widget build(BuildContext context) {
    if (media.length == 1) {
      final item = media.single;
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: item.aspectRatio.clamp(0.75, 1.91),
          child: _tile(context, 0),
        ),
      );
    }
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: _height * media[index].aspectRatio.clamp(0.6, 1.4),
              child: _tile(context, index),
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, int index) {
    final item = media[index];
    if (item.isVideo) return MediaVideo(media: item);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(media: media, initialIndex: index),
        ),
      ),
      child: MediaImage(media: item),
    );
  }
}

/// Fotos e vídeos em tela cheia, com zoom nas fotos.
class MediaViewerScreen extends StatelessWidget {
  const MediaViewerScreen({
    super.key,
    required this.media,
    this.initialIndex = 0,
  });

  final List<MediaRef> media;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: media.length,
        itemBuilder: (context, index) {
          final item = media[index];
          return item.isVideo
              ? MediaVideo(media: item, autoplay: true, fit: BoxFit.contain)
              : InteractiveViewer(
                  maxScale: 4,
                  child: MediaImage(media: item, fit: BoxFit.contain),
                );
        },
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}

class _DurationLabel extends StatelessWidget {
  const _DurationLabel({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final seconds = duration.inSeconds;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

class _MediaError extends StatelessWidget {
  const _MediaError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.surfaceHigh,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
      ),
    );
  }
}
