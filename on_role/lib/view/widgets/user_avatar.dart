import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_widgets.dart';
import 'media_view.dart';

/// Foto de perfil, ou a inicial do nome para quem ainda não tem foto.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 20});

  final User user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = user.photo;
    if (photo == null) return InitialAvatar(name: user.name, radius: radius);
    return ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: MediaImage(media: photo),
      ),
    );
  }
}

/// Avatar de quem escreveu um post, story ou resposta. Posts guardam só o id
/// e o nome do autor, então a foto vem do perfil carregado; enquanto ele não
/// chega, aparece a inicial do nome.
class AuthorAvatar extends StatelessWidget {
  const AuthorAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.radius = 20,
  });

  final String userId;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, User?>(
      (auth) => auth.userById(userId),
    );
    return user == null
        ? InitialAvatar(name: name, radius: radius)
        : UserAvatar(user: user, radius: radius);
  }
}
