import 'package:flutter/material.dart';
import 'package:on_role/view/screen/feed_screen.dart';
import 'package:on_role/view/screen/map_screen.dart';
import 'package:on_role/view/screen/match_screen.dart';
import 'package:on_role/view/screen/profile_screen.dart';
import 'package:on_role/view/screen/search_screen.dart';
import 'package:provider/provider.dart';

import '../app_mode.dart';
import '../providers/auth_provider.dart';
import '../providers/presence_provider.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Localização e check-in automático rodam enquanto o usuário está logado,
    // em qualquer aba.
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) context.read<PresenceProvider>().start(userId: userId);
  }

  // Match geossocial (aba "Conexões" estilo Tinder): só na versão de
  // demonstração, com pessoas sintéticas, para a avaliação da H3. No app
  // completo, "conexões" é seguir alguém pelo perfil (FollowProvider).
  List<Widget> get _pages => <Widget>[
    const FeedScreen(),
    const MapScreen(),
    if (appMode.isDemo) const MatchScreen(),
    const SearchScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.gps_fixed), label: 'Mapa'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Conexões',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Procurar'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
