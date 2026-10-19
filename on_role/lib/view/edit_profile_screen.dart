import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/interest_catalog.dart';
import '../data/repositories.dart';
import '../models/media.dart';
import '../providers/auth_provider.dart';
import '../services/media_drafts.dart';
import '../theme/app_theme.dart';
import 'widgets/user_avatar.dart';

/// Foto, bio e gostos de rolê. Os gostos entram na afinidade das Conexões.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
  }

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _bio;
  late final Set<String> _interests;
  MediaDraft? _newPhoto;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _bio = TextEditingController(text: user?.bio ?? '');
    _interests = {...?user?.interests};
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await chooseProfilePhoto(context);
    if (photo != null && mounted) setState(() => _newPhoto = photo);
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (!_interests.remove(interest)) {
        if (_interests.length >= maxInterests) {
          _showMessage('Escolha até $maxInterests gostos.');
          return;
        }
        _interests.add(interest);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final bio = _bio.text.trim();
    final error = await context.read<AuthProvider>().updateProfile(
      bio: bio.isEmpty ? null : bio,
      // Na ordem do catálogo, para o perfil sempre aparecer igual.
      interests: [
        for (final interest in interestCatalog)
          if (_interests.contains(interest)) interest,
      ],
      newPhoto: _newPhoto,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      _showMessage(error);
      return;
    }
    Navigator.pop(context);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final newPhoto = _newPhoto;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Salvando...' : 'Salvar'),
            ),
          ),
        ],
      ),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _saving ? null : _pickPhoto,
                    child: Stack(
                      children: [
                        if (newPhoto != null)
                          ClipOval(
                            child: Image.memory(
                              newPhoto.bytes,
                              width: 104,
                              height: 104,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          UserAvatar(user: user, radius: 52),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.background,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.photo_camera,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _bio,
                  enabled: !_saving,
                  maxLength: 200,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Bio: conte um pouco do seu rolê',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Gostos de rolê',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Até $maxInterests. Ajudam a sugerir conexões com quem curte '
                  'o mesmo que você.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final interest in interestCatalog)
                      FilterChip(
                        label: Text(interest),
                        selected: _interests.contains(interest),
                        onSelected: _saving
                            ? null
                            : (_) => _toggleInterest(interest),
                        selectedColor: AppColors.primary.withValues(
                          alpha: 0.35,
                        ),
                        backgroundColor: AppColors.surface,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Pergunta se a foto de perfil vem da câmera ou da galeria e prepara a
/// imagem. Usada no cadastro e em Editar perfil.
Future<MediaDraft?> chooseProfilePhoto(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surfaceHigh,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  try {
    return await pickProfilePhoto(source);
  } on MediaException catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.message)));
  } catch (error) {
    debugPrint('chooseProfilePhoto: $error');
    messenger.showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir a foto.')),
    );
  }
  return null;
}
