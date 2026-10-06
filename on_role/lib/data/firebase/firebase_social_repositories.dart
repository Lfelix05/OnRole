import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/media.dart';
import '../../models/posts.dart';
import '../../models/reply.dart';
import '../../models/story.dart';
import '../../models/user.dart';
import '../../services/media_chunks.dart';
import '../repositories.dart';

// Posts, respostas, stories e mídia no Cloud Firestore:
//
//   posts/{id}                  authorId, authorName, text, media[], venueId,
//                               atVenue, likedBy[], replyCount, lastReplyId, createdAt
//   posts/{id}/replies/{id}     authorId, authorName, text, createdAt
//   stories/{id}                authorId, authorName, media, venueId, atVenue,
//                               createdAt, expiresAt
//   media/{id}                  ownerId, kind, mimeType, size, chunkCount, createdAt
//   media/{id}/chunks/{n}       data (até 900 KB de bytes)
//
// Fotos e vídeos ficam no próprio banco, em pedaços, porque o Cloud Storage
// exige o plano pago do Firebase.

DateTime _timestamp(Object? value) =>
    (value as Timestamp?)?.toDate() ?? DateTime.now();

class FirebasePostRepository implements PostRepository {
  FirebasePostRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  @override
  Stream<List<Posts>> watchFeed({int limit = 30}) {
    return _posts
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => [for (final doc in snapshot.docs) _postFromDoc(doc)],
        );
  }

  @override
  Stream<List<Posts>> watchPostsByAuthor(String authorId) {
    // Usa o índice composto (authorId, createdAt) de firestore.indexes.json.
    return _posts
        .where('authorId', isEqualTo: authorId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => [for (final doc in snapshot.docs) _postFromDoc(doc)],
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
    await _posts.add({
      'authorId': author.id,
      'authorName': author.name,
      'text': text,
      'media': [for (final item in media) item.toJson()],
      'venueId': venueId,
      'atVenue': atVenue,
      'likedBy': <String>[],
      'replyCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setLiked({
    required String postId,
    required String userId,
    required bool liked,
  }) {
    return _posts.doc(postId).update({
      'likedBy': liked
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
    });
  }

  @override
  Future<void> deletePost(String postId) => _posts.doc(postId).delete();

  @override
  Stream<List<Reply>> watchReplies(String postId) {
    return _posts
        .doc(postId)
        .collection('replies')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              Reply(
                id: doc.id,
                postId: postId,
                authorId: doc.data()['authorId'] as String? ?? '',
                authorName: doc.data()['authorName'] as String? ?? 'Usuário',
                text: doc.data()['text'] as String? ?? '',
                createdAt: _timestamp(doc.data()['createdAt']),
              ),
          ],
        );
  }

  @override
  Future<void> addReply({
    required String postId,
    required User author,
    required String text,
  }) {
    final post = _posts.doc(postId);
    final reply = post.collection('replies').doc();
    // A resposta e o contador sobem juntos; as regras conferem que o
    // contador só aumenta quando a resposta existe (lastReplyId).
    final batch = _db.batch()
      ..set(reply, {
        'authorId': author.id,
        'authorName': author.name,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..update(post, {
        'replyCount': FieldValue.increment(1),
        'lastReplyId': reply.id,
      });
    return batch.commit();
  }

  static Posts _postFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Posts(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Usuário',
      // Posts da versão anterior guardavam o texto em "content".
      text: data['text'] as String? ?? data['content'] as String? ?? '',
      media: [
        for (final item in data['media'] as List? ?? const [])
          MediaRef.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      venueId: data['venueId'] as String?,
      atVenue: data['atVenue'] as bool? ?? false,
      likedBy: List<String>.from(data['likedBy'] as List? ?? const []),
      replyCount: (data['replyCount'] as num?)?.toInt() ?? 0,
      createdAt: _timestamp(data['createdAt']),
    );
  }
}

class FirebaseStoryRepository implements StoryRepository {
  FirebaseStoryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _stories =>
      _db.collection('stories');

  @override
  Stream<List<Story>> watchActiveStories() {
    return _stories
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .snapshots()
        .map((snapshot) {
          final stories = [for (final doc in snapshot.docs) _storyFromDoc(doc)];
          stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return stories;
        });
  }

  @override
  Future<void> addStory({
    required User author,
    required MediaRef media,
    String? venueId,
    bool atVenue = false,
  }) async {
    await _stories.add({
      'authorId': author.id,
      'authorName': author.name,
      'media': media.toJson(),
      'venueId': venueId,
      'atVenue': atVenue,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(storyLifetime)),
    });
  }

  @override
  Future<List<Story>> expiredStoriesOf(String userId) async {
    final snapshot = await _stories.where('authorId', isEqualTo: userId).get();
    final now = DateTime.now();
    return [
      for (final doc in snapshot.docs) _storyFromDoc(doc),
    ].where((story) => !story.isActiveAt(now)).toList();
  }

  @override
  Future<void> deleteStory(String storyId) => _stories.doc(storyId).delete();

  static Story _storyFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = _timestamp(data['createdAt']);
    return Story(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Usuário',
      media: MediaRef.fromJson(Map<String, dynamic>.from(data['media'] as Map)),
      venueId: data['venueId'] as String?,
      atVenue: data['atVenue'] as bool? ?? false,
      createdAt: createdAt,
      expiresAt:
          (data['expiresAt'] as Timestamp?)?.toDate() ??
          createdAt.add(storyLifetime),
    );
  }
}

class FirebaseMediaRepository implements MediaRepository {
  FirebaseMediaRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _media =>
      _db.collection('media');

  @override
  Future<MediaRef> upload({
    required String ownerId,
    required MediaDraft draft,
    void Function(double progress)? onProgress,
  }) async {
    if (draft.bytes.isEmpty || draft.bytes.length > maxMediaBytes) {
      throw const MediaException('Arquivo vazio ou grande demais.');
    }
    final chunks = splitIntoChunks(draft.bytes, mediaChunkSize);
    final doc = _media.doc();
    // Os metadados vêm antes: as regras só aceitam um pedaço se o documento
    // da mídia já existe e pertence a quem está enviando.
    await doc.set({
      'ownerId': ownerId,
      'kind': draft.kind.name,
      'mimeType': draft.mimeType,
      'size': draft.bytes.length,
      'chunkCount': chunks.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (var i = 0; i < chunks.length; i++) {
      await doc.collection('chunks').doc('$i').set({'data': Blob(chunks[i])});
      onProgress?.call((i + 1) / chunks.length);
    }
    return MediaRef(
      id: doc.id,
      kind: draft.kind,
      mimeType: draft.mimeType,
      chunkCount: chunks.length,
      aspectRatio: draft.aspectRatio,
      duration: draft.duration,
    );
  }

  @override
  Future<Uint8List> load(MediaRef media) async {
    final chunks = _media.doc(media.id).collection('chunks');
    // Mídia nunca muda: o cache do aparelho vem antes, para não gastar
    // leituras nem tráfego do plano gratuito.
    QuerySnapshot<Map<String, dynamic>>? snapshot;
    try {
      snapshot = await chunks.get(const GetOptions(source: Source.cache));
    } on FirebaseException {
      snapshot = null;
    }
    if (snapshot == null || snapshot.docs.length < media.chunkCount) {
      snapshot = await chunks.get();
    }

    final parts = {
      for (final doc in snapshot.docs)
        int.parse(doc.id): (doc.data()['data'] as Blob).bytes,
    };
    if (parts.length != media.chunkCount) {
      throw const MediaException('Mídia incompleta.');
    }
    return joinChunks([for (var i = 0; i < media.chunkCount; i++) parts[i]!]);
  }

  @override
  Future<void> delete(MediaRef media) async {
    final doc = _media.doc(media.id);
    // Pedaços antes: as regras checam o dono no documento da mídia.
    for (var i = 0; i < media.chunkCount; i++) {
      await doc.collection('chunks').doc('$i').delete();
    }
    await doc.delete();
  }
}
