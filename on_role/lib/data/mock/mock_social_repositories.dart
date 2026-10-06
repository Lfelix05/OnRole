import 'dart:typed_data';

import '../../models/media.dart';
import '../../models/posts.dart';
import '../../models/reply.dart';
import '../../models/story.dart';
import '../../models/user.dart';
import '../repositories.dart';
import 'mock_database.dart';

// Posts, stories e mídia em memória. As validações repetem as regras do
// Firestore (firestore.rules) para o mock se comportar como o servidor.

const _maxTextLength = 500;

class MockPostRepository implements PostRepository {
  MockPostRepository(this._db);

  final MockDatabase _db;

  @override
  Stream<List<Posts>> watchFeed({int limit = 30}) {
    return watchValue(_db.changes, () => _db.posts.take(limit).toList());
  }

  @override
  Stream<List<Posts>> watchPostsByAuthor(String authorId) {
    return watchValue(
      _db.changes,
      () => _db.posts.where((post) => post.authorId == authorId).toList(),
    );
  }

  @override
  Future<void> addPost({
    required User author,
    required String text,
    List<MediaRef> media = const [],
    String? venueId,
    bool atVenue = false,
  }) async {
    if (text.length > _maxTextLength || media.length > maxPostMedia) {
      throw StateError('Post fora dos limites.');
    }
    if (text.trim().isEmpty && media.isEmpty) {
      throw StateError('Post vazio.');
    }
    _checkVenueTag(author.id, venueId, atVenue);
    final now = DateTime.now();
    _db.addPost(
      Posts(
        id: now.microsecondsSinceEpoch.toString(),
        authorId: author.id,
        authorName: author.name,
        text: text,
        media: media,
        venueId: venueId,
        atVenue: atVenue,
        createdAt: now,
      ),
    );
  }

  @override
  Future<void> setLiked({
    required String postId,
    required String userId,
    required bool liked,
  }) async {
    _db.setLiked(postId, userId, liked: liked);
  }

  @override
  Future<void> deletePost(String postId) async => _db.removePost(postId);

  @override
  Stream<List<Reply>> watchReplies(String postId) {
    return watchValue(_db.changes, () => _db.repliesOf(postId));
  }

  @override
  Future<void> addReply({
    required String postId,
    required User author,
    required String text,
  }) async {
    if (text.trim().isEmpty || text.length > _maxTextLength) {
      throw StateError('Resposta fora dos limites.');
    }
    _db.addReply(
      Reply(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        postId: postId,
        authorId: author.id,
        authorName: author.name,
        text: text,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _checkVenueTag(String userId, String? venueId, bool atVenue) {
    if (atVenue &&
        (venueId == null || !_db.hasActiveCheckIn(userId, venueId))) {
      throw StateError('Selo "no rolê agora" sem check-in ativo.');
    }
  }
}

class MockStoryRepository implements StoryRepository {
  MockStoryRepository(this._db);

  final MockDatabase _db;

  @override
  Stream<List<Story>> watchActiveStories() {
    return watchValue(_db.changes, () {
      final now = DateTime.now();
      return _db.stories.where((story) => story.isActiveAt(now)).toList();
    });
  }

  @override
  Future<void> addStory({
    required User author,
    required MediaRef media,
    String? venueId,
    bool atVenue = false,
  }) async {
    if (atVenue &&
        (venueId == null || !_db.hasActiveCheckIn(author.id, venueId))) {
      throw StateError('Selo "no rolê agora" sem check-in ativo.');
    }
    final now = DateTime.now();
    _db.addStory(
      Story(
        id: now.microsecondsSinceEpoch.toString(),
        authorId: author.id,
        authorName: author.name,
        media: media,
        venueId: venueId,
        atVenue: atVenue,
        createdAt: now,
        expiresAt: now.add(storyLifetime),
      ),
    );
  }

  @override
  Future<List<Story>> expiredStoriesOf(String userId) async {
    final now = DateTime.now();
    return _db.stories
        .where((story) => story.authorId == userId && !story.isActiveAt(now))
        .toList();
  }

  @override
  Future<void> deleteStory(String storyId) async => _db.removeStory(storyId);
}

class MockMediaRepository implements MediaRepository {
  MockMediaRepository(this._db);

  final MockDatabase _db;

  @override
  Future<MediaRef> upload({
    required String ownerId,
    required MediaDraft draft,
    void Function(double progress)? onProgress,
  }) async {
    if (draft.bytes.isEmpty || draft.bytes.length > maxMediaBytes) {
      throw const MediaException('Arquivo vazio ou grande demais.');
    }
    final chunkCount = (draft.bytes.length / mediaChunkSize).ceil();
    for (var i = 1; i <= chunkCount; i++) {
      onProgress?.call(i / chunkCount);
    }
    final id = 'media-${DateTime.now().microsecondsSinceEpoch}';
    _db.putMedia(id, draft.bytes);
    return MediaRef(
      id: id,
      kind: draft.kind,
      mimeType: draft.mimeType,
      chunkCount: chunkCount,
      aspectRatio: draft.aspectRatio,
      duration: draft.duration,
    );
  }

  @override
  Future<Uint8List> load(MediaRef media) async {
    final bytes = _db.mediaBytes(media.id);
    if (bytes == null) throw const MediaException('Mídia não encontrada.');
    return bytes;
  }

  @override
  Future<void> delete(MediaRef media) async => _db.removeMedia(media.id);
}
