import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/posts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_widgets.dart';
import '../welcome.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _gridTab = true;

  void _logout() {
    context.read<AuthProvider>().logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final List<Posts> posts = user == null ? [] : context.watch<PostsProvider>().postsByAuthor(user.id);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: user == null
              ? Center(
                  child: Text('Nenhum usuário logado', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    InitialAvatar(name: user.name, radius: 44),
                    const SizedBox(height: 12.0),
                    Text(user.name, style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2.0),
                    Text(
                      '@${user.name.toLowerCase().replaceAll(' ', '')}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    if (user.bio != null) ...[
                      const SizedBox(height: 10.0),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          user.bio!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StatColumn(value: '${posts.length}', label: 'Rolês'),
                        const SizedBox(width: 32.0),
                        const _StatColumn(value: '0', label: 'Seguidores'),
                        const SizedBox(width: 32.0),
                        const _StatColumn(value: '0', label: 'Seguindo'),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            icon: Icons.grid_on,
                            selected: _gridTab,
                            onTap: () => setState(() => _gridTab = true),
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            icon: Icons.reorder,
                            selected: !_gridTab,
                            onTap: () => setState(() => _gridTab = false),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: posts.isEmpty
                          ? Center(
                              child: Text('Nenhum post ainda.', style: TextStyle(color: AppColors.textSecondary)),
                            )
                          : _gridTab
                              ? GridView.builder(
                                  padding: const EdgeInsets.all(2),
                                  itemCount: posts.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 2,
                                    crossAxisSpacing: 2,
                                  ),
                                  itemBuilder: (context, index) => const MediaPlaceholder(borderRadius: 0),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  itemCount: posts.length,
                                  separatorBuilder: (context, index) => const Divider(height: 24),
                                  itemBuilder: (context, index) {
                                    final post = posts[index];
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(post.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4.0),
                                        Text(post.content, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                      ],
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2.0),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.icon, required this.selected, required this.onTap});

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2),
          ),
        ),
        child: Icon(icon, color: selected ? Colors.white : AppColors.textTertiary),
      ),
    );
  }
}
