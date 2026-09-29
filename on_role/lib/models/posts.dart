class Posts {
  String id;
  String title;
  String content;
  final PostType type;
  String authorId;

  /// Copiado do perfil na hora do post, para o feed não precisar buscar o
  /// autor de cada post.
  String authorName;

  /// Local onde o autor tinha check-in ativo quando postou.
  String? venueId;
  DateTime createdAt;
  DateTime updatedAt;

  /// A partir daqui o post some do feed.
  DateTime expiresAt;

  Posts({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.authorId,
    required this.authorName,
    this.venueId,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  factory Posts.fromJson(Map<String, dynamic> json) {
    return Posts(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      type: PostType.values.byName(json['type']),
      authorId: json['authorId'],
      authorName: json['authorName'],
      venueId: json['venueId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type.name,
      'authorId': authorId,
      'authorName': authorName,
      'venueId': venueId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}

enum PostType {
  text,
  image,
  video,
}
