class Posts {
  String id;
  String title;
  String content;
  final PostType type;
  String authorId;

  /// Local onde o autor tinha check-in ativo quando postou.
  String? venueId;
  DateTime createdAt;
  DateTime updatedAt;

  Posts({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.authorId,
    this.venueId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Posts.fromJson(Map<String, dynamic> json) {
    return Posts(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      type: PostType.values.byName(json['type']),
      authorId: json['authorId'],
      venueId: json['venueId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type.name,
      'authorId': authorId,
      'venueId': venueId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

enum PostType {
  text,
  image,
  video,
}