class Posts {
  String id;
  String title;
  String content;
  final PostType type;
  String authorId;
  DateTime createdAt;
  DateTime updatedAt;

  Posts({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.authorId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Posts.fromJson(Map<String, dynamic> json) {
    return Posts(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      type: PostType.values.firstWhere((e) => e.toString() == json['type']),
      authorId: json['authorId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type.toString().split('.').last,
      'authorId': authorId,
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