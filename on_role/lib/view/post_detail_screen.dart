import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/posts.dart';
import '../models/reply.dart';
import '../providers/posts_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'widgets/post_card.dart';

/// Um post com a conversa (respostas) embaixo.
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final Posts post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _replyController = TextEditingController();
  late final Stream<List<Reply>> _replies;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _replies = context.read<PostsProvider>().replies(widget.post.id);
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _send(Posts post) async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final error = await context.read<PostsProvider>().reply(post, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _replyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    // A versão do feed chega atualizada (curtidas, respostas); fora dele, a
    // que veio de quem abriu a tela.
    Posts post = widget.post;
    for (final candidate in context.watch<PostsProvider>().posts) {
      if (candidate.id == widget.post.id) post = candidate;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: AppBackground(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Reply>>(
                stream: _replies,
                builder: (context, snapshot) {
                  final replies = snapshot.data ?? const <Reply>[];
                  return ListView(
                    children: [
                      PostCard(post: post),
                      const Divider(height: 1),
                      if (snapshot.hasData && replies.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Ninguém respondeu ainda. Puxe o assunto!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      for (final reply in replies) _ReplyTile(reply: reply),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Responder a ${post.authorName}...',
                          counterText: '',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Enviar',
                      onPressed: _sending ? null : () => _send(post),
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.reply});

  final Reply reply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialAvatar(name: reply.authorName, radius: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: reply.authorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        text: '  ${formatTimeAgo(reply.createdAt)}',
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reply.text,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
