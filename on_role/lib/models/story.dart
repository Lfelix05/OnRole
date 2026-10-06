import 'media.dart';

/// Story: uma foto ou vídeo que some do app 24 horas depois.
class Story {
  const Story({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.media,
    this.venueId,
    this.atVenue = false,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final MediaRef media;
  final String? venueId;

  /// Selo "no rolê agora", verificado pelo servidor como nos posts.
  final bool atVenue;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool isActiveAt(DateTime now) => expiresAt.isAfter(now);
}

/// Os stories ativos de uma pessoa, na ordem em que foram postados.
class StoryGroup {
  const StoryGroup({
    required this.authorId,
    required this.authorName,
    required this.stories,
  });

  final String authorId;
  final String authorName;
  final List<Story> stories;

  DateTime get latest => stories.last.createdAt;
}
