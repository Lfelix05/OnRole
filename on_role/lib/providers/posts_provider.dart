import 'package:flutter/material.dart';

import '../models/database.dart';
import '../models/posts.dart';

class PostsProvider extends ChangeNotifier {
  List<Posts> get posts => MockDatabase.instance.posts;

  String authorName(String authorId) {
    return MockDatabase.instance.findUserById(authorId)?.name ?? 'Usuário';
  }

  List<Posts> postsByAuthor(String authorId) {
    return posts.where((post) => post.authorId == authorId).toList();
  }

  void addPost({
    required String title,
    required String content,
    required String authorId,
  }) {
    final now = DateTime.now();
    MockDatabase.instance.addPost(
      Posts(
        id: now.millisecondsSinceEpoch.toString(),
        title: title,
        content: content,
        type: PostType.text,
        authorId: authorId,
        createdAt: now,
        updatedAt: now,
      ),
    );
    notifyListeners();
  }
}
