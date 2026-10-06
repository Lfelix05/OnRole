import 'media.dart';

/// Post do feed: texto, fotos e vídeos, no estilo do Threads.
class Posts {
  String id;
  String authorId;

  /// Copiado do perfil na hora do post, para o feed não precisar buscar o
  /// autor de cada post.
  String authorName;
  String text;

  /// Até 4 fotos ou vídeos.
  List<MediaRef> media;

  /// Local marcado no post (opcional), ex.: "bora no Boteco hoje às 22h?".
  String? venueId;

  /// Selo "no rolê agora": o servidor só aceita se o autor tinha check-in
  /// ativo no local na hora de postar.
  bool atVenue;

  /// Quem curtiu (ids dos usuários).
  List<String> likedBy;
  int replyCount;
  DateTime createdAt;

  Posts({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    this.media = const [],
    this.venueId,
    this.atVenue = false,
    List<String>? likedBy,
    this.replyCount = 0,
    required this.createdAt,
  }) : likedBy = likedBy ?? [];

  int get likeCount => likedBy.length;

  bool isLikedBy(String? userId) => userId != null && likedBy.contains(userId);

  factory Posts.fromJson(Map<String, dynamic> json) {
    return Posts(
      id: json['id'],
      authorId: json['authorId'],
      authorName: json['authorName'],
      text: json['text'] ?? '',
      media: [
        for (final item in json['media'] as List? ?? const [])
          MediaRef.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      venueId: json['venueId'],
      atVenue: json['atVenue'] ?? false,
      likedBy: List<String>.from(json['likedBy'] as List? ?? const []),
      replyCount: json['replyCount'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'text': text,
      'media': [for (final item in media) item.toJson()],
      'venueId': venueId,
      'atVenue': atVenue,
      'likedBy': likedBy,
      'replyCount': replyCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
