import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repositories.dart';
import '../models/media.dart';
import '../models/story.dart';
import 'auth_provider.dart';
import 'media_loader.dart';

/// Stories de 24 horas no topo do feed, agrupados por pessoa.
class StoriesProvider extends ChangeNotifier {
  StoriesProvider({
    required StoryRepository repository,
    required MediaRepository media,
    required MediaLoader loader,
    required AuthProvider auth,
  }) : _repository = repository,
       _media = media,
       _loader = loader,
       _auth = auth {
    auth.addListener(_syncSession);
    _syncSession();
  }

  final StoryRepository _repository;
  final MediaRepository _media;
  final MediaLoader _loader;
  final AuthProvider _auth;
  StreamSubscription<List<Story>>? _subscription;
  Timer? _expiryTimer;
  String? _userId;
  List<Story> _stories = const [];
  final Set<String> _seen = {};

  /// Um grupo por pessoa com story ativo: os seus primeiro, depois quem tem
  /// story não visto, do mais recente para o mais antigo.
  List<StoryGroup> get groups {
    final now = DateTime.now();
    final byAuthor = <String, List<Story>>{};
    for (final story in _stories) {
      if (story.isActiveAt(now)) {
        byAuthor.putIfAbsent(story.authorId, () => []).add(story);
      }
    }
    final groups = [
      for (final entry in byAuthor.entries)
        StoryGroup(
          authorId: entry.key,
          authorName: entry.value.last.authorName,
          stories: entry.value,
        ),
    ];
    groups.sort((a, b) {
      if (a.authorId == _userId) return -1;
      if (b.authorId == _userId) return 1;
      final unseenA = hasUnseen(a);
      if (unseenA != hasUnseen(b)) return unseenA ? -1 : 1;
      return b.latest.compareTo(a.latest);
    });
    return groups;
  }

  StoryGroup? groupOf(String authorId) {
    for (final group in groups) {
      if (group.authorId == authorId) return group;
    }
    return null;
  }

  bool hasUnseen(StoryGroup group) =>
      group.stories.any((story) => !_seen.contains(story.id));

  /// Onde começar a assistir: no primeiro story ainda não visto.
  int firstUnseenIndex(StoryGroup group) {
    final index = group.stories.indexWhere(
      (story) => !_seen.contains(story.id),
    );
    return index == -1 ? 0 : index;
  }

  void markSeen(Story story) {
    if (_seen.add(story.id)) notifyListeners();
  }

  /// Retorna a mensagem de erro, ou null se publicou.
  Future<String?> publish(
    MediaDraft draft, {
    String? venueId,
    bool atVenue = false,
    void Function(double progress)? onProgress,
  }) async {
    final author = _auth.currentUser;
    if (author == null) return 'Sua sessão expirou. Entre de novo.';
    MediaRef? uploaded;
    try {
      uploaded = await _media.upload(
        ownerId: author.id,
        draft: draft,
        onProgress: onProgress,
      );
      _loader.remember(uploaded.id, draft.bytes);
      await _repository.addStory(
        author: author,
        media: uploaded,
        venueId: venueId,
        atVenue: atVenue,
      );
      return null;
    } on MediaException catch (error) {
      return error.message;
    } catch (error) {
      debugPrint('StoriesProvider: $error');
      if (uploaded != null) {
        _media
            .delete(uploaded)
            .catchError(
              (Object error) => debugPrint('StoriesProvider: $error'),
            );
      }
      return 'Não foi possível publicar o story. Confira a conexão.';
    }
  }

  /// Retorna a mensagem de erro, ou null se apagou.
  Future<String?> deleteStory(Story story) async {
    try {
      await _repository.deleteStory(story.id);
      _media
          .delete(story.media)
          .catchError((Object error) => debugPrint('StoriesProvider: $error'));
      return null;
    } catch (error) {
      debugPrint('StoriesProvider: $error');
      return 'Não foi possível apagar o story.';
    }
  }

  /// O plano gratuito não apaga nada sozinho (a exclusão automática, TTL, é
  /// do plano pago), então cada pessoa limpa os próprios stories vencidos e
  /// as mídias deles ao abrir o app.
  Future<void> _cleanUpExpired(String userId) async {
    try {
      final expired = await _repository.expiredStoriesOf(userId);
      for (final story in expired) {
        await _media.delete(story.media);
        await _repository.deleteStory(story.id);
      }
    } catch (error) {
      debugPrint('StoriesProvider: $error');
    }
  }

  void _syncSession() {
    final userId = _auth.currentUser?.id;
    if (userId == _userId) return;
    _userId = userId;
    _subscription?.cancel();
    _subscription = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _stories = const [];
    _seen.clear();
    // Stories só podem ser lidos por quem está logado.
    if (userId == null) return;

    _subscription = _repository.watchActiveStories().listen((stories) {
      _stories = stories;
      notifyListeners();
    }, onError: (Object error) => debugPrint('StoriesProvider: $error'));
    // Stories vencem com o tempo, sem mudança no banco.
    _expiryTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => notifyListeners(),
    );
    _cleanUpExpired(userId);
  }

  @override
  void dispose() {
    _auth.removeListener(_syncSession);
    _subscription?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }
}
