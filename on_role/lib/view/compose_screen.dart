import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories.dart';
import '../data/venue_catalog.dart';
import '../models/media.dart';
import '../models/venue.dart';
import '../providers/auth_provider.dart';
import '../providers/posts_provider.dart';
import '../providers/presence_provider.dart';
import '../services/media_drafts.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'camera_screen.dart';
import 'widgets/post_card.dart';

const _maxTextLength = 500;

/// Novo post no estilo do Threads: texto, até 4 fotos/vídeos e um local
/// opcional. Qualquer pessoa logada posta; o selo "no rolê agora" só aparece
/// com check-in ativo no local.
class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ComposeScreen(),
      ),
    );
  }

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _text = TextEditingController();
  final List<MediaDraft> _drafts = [];
  Venue? _venue;
  bool _atVenue = false;

  /// Progresso do envio (0 a 1); nulo quando não está publicando.
  double? _progress;

  @override
  void initState() {
    super.initState();
    // Quem está num rolê já começa com o local marcado.
    final checkedIn = context.read<PresenceProvider>().checkedInVenue;
    if (checkedIn != null) {
      _venue = checkedIn;
      _atVenue = true;
    }
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _publishing => _progress != null;

  bool get _canPublish =>
      !_publishing && (_text.text.trim().isNotEmpty || _drafts.isNotEmpty);

  int get _room => maxPostMedia - _drafts.length;

  Future<void> _addFromGallery() async {
    if (_room <= 0) return;
    try {
      final picked = await pickFromGallery(limit: _room);
      if (mounted) setState(() => _drafts.addAll(picked.take(_room)));
    } on MediaException catch (error) {
      _showMessage(error.message);
    } catch (error) {
      debugPrint('ComposeScreen: $error');
      _showMessage('Não foi possível abrir a galeria.');
    }
  }

  Future<void> _addFromCamera() async {
    if (_room <= 0) return;
    final draft = await CameraCaptureScreen.open(context);
    if (draft != null && mounted) setState(() => _drafts.add(draft));
  }

  Future<void> _pickVenue() async {
    final checkedIn = context.read<PresenceProvider>().checkedInVenue;
    final choice = await showModalBottomSheet<({Venue? venue})>(
      context: context,
      backgroundColor: AppColors.surfaceHigh,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Marcar um local',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.location_off_outlined),
              title: const Text('Sem local'),
              onTap: () => Navigator.pop(context, (venue: null)),
            ),
            for (final venue in venueCatalog)
              ListTile(
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primarySoft,
                ),
                title: Text(venue.name),
                subtitle: venue.id == checkedIn?.id
                    ? const Text(
                        'Você está aqui',
                        style: TextStyle(color: AppColors.success),
                      )
                    : Text(venue.category.label),
                onTap: () => Navigator.pop(context, (venue: venue)),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _venue = choice.venue;
      // O selo só vale para o local do check-in; marcar outro é combinar um
      // rolê, não dizer que já está lá.
      _atVenue = choice.venue != null && choice.venue!.id == checkedIn?.id;
    });
  }

  Future<void> _publish() async {
    setState(() => _progress = 0);
    final error = await context.read<PostsProvider>().publish(
      text: _text.text,
      drafts: _drafts,
      venueId: _venue?.id,
      atVenue: _atVenue,
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _progress = null);
      _showMessage(error);
      return;
    }
    Navigator.pop(context);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final author = context.watch<AuthProvider>().currentUser;
    final length = _text.text.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cancelar',
          onPressed: _publishing ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Novo post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _canPublish ? _publish : null,
              child: Text(_publishing ? 'Publicando...' : 'Publicar'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_publishing)
            LinearProgressIndicator(
              value: _drafts.isEmpty ? null : _progress,
              color: AppColors.primary,
              backgroundColor: AppColors.border,
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InitialAvatar(name: author?.name ?? '?', radius: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author?.name ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextField(
                            controller: _text,
                            autofocus: true,
                            enabled: !_publishing,
                            minLines: 2,
                            maxLines: null,
                            maxLength: _maxTextLength,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            decoration: const InputDecoration(
                              hintText:
                                  'O que tá rolando? Chame a galera, combine '
                                  'um rolê, avise de um evento...',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              filled: false,
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                          if (_drafts.isNotEmpty)
                            SizedBox(
                              height: 150,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _drafts.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) => _DraftThumb(
                                  draft: _drafts[index],
                                  onRemove: _publishing
                                      ? null
                                      : () => setState(
                                          () => _drafts.removeAt(index),
                                        ),
                                ),
                              ),
                            ),
                          if (_venue != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: VenueTag(
                                      venue: _venue!,
                                      atVenue: _atVenue,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Tirar local',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _publishing
                                        ? null
                                        : () => setState(() {
                                            _venue = null;
                                            _atVenue = false;
                                          }),
                                    icon: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Galeria',
                    onPressed: _publishing || _room <= 0
                        ? null
                        : _addFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                  ),
                  IconButton(
                    tooltip: 'Câmera',
                    onPressed: _publishing || _room <= 0
                        ? null
                        : _addFromCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                  ),
                  IconButton(
                    tooltip: 'Marcar local',
                    onPressed: _publishing ? null : _pickVenue,
                    icon: const Icon(Icons.location_on_outlined),
                  ),
                  const Spacer(),
                  if (length > _maxTextLength - 100)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${_maxTextLength - length}',
                        style: TextStyle(
                          color: length >= _maxTextLength
                              ? Theme.of(context).colorScheme.error
                              : AppColors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftThumb extends StatelessWidget {
  const _DraftThumb({required this.draft, required this.onRemove});

  final MediaDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final seconds = draft.duration?.inSeconds ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 150 * draft.aspectRatio.clamp(0.6, 1.4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (draft.isVideo)
              ColoredBox(
                color: AppColors.surfaceHigh,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam, color: Colors.white70, size: 32),
                    Text(
                      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            else
              Image.memory(draft.bytes, fit: BoxFit.cover, cacheWidth: 400),
            if (onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
