import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_mode.dart';
import 'data/firebase/firebase_repositories.dart';
import 'data/mock/mock_database.dart';
import 'data/mock/mock_repositories.dart';
import 'data/repositories.dart';
import 'data/venue_catalog.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/bench_provider.dart';
import 'providers/follow_provider.dart';
import 'providers/match_provider.dart';
import 'providers/media_loader.dart';
import 'providers/posts_provider.dart';
import 'providers/presence_provider.dart';
import 'providers/stories_provider.dart';
import 'providers/venues_provider.dart';
import 'services/crowd_simulator.dart';
import 'theme/app_theme.dart';
import 'view/auth_gate.dart';

/// `flutter run --dart-define=BACKEND=mock` roda sem Firebase, com dados de
/// exemplo em memória (desenvolvimento). A versão entregue a quem avalia o
/// app é a `MODE=demo` (ver app_mode.dart).
const _useMockBackend = String.fromEnvironment('BACKEND') == 'mock';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MainApp(repositories: await _createRepositories()));
}

Future<Repositories> _createRepositories() async {
  // Versão de demonstração: o Firebase nem é inicializado, e a população, os
  // posts e a lotação dos locais são sintéticos.
  if (appMode.isDemo) {
    return createMockRepositories(
      database: MockDatabase.demo(),
      simulator: SyntheticCrowd(baseline: demoCrowdBaseline, seed: 1),
    );
  }
  if (_useMockBackend) return createMockRepositories();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return createFirebaseRepositories();
  } on UnsupportedError catch (error) {
    // Plataformas sem Firebase configurado (ex.: Windows) usam o mock.
    debugPrint(
      'Firebase indisponível nesta plataforma, usando dados mock. $error',
    );
    return createMockRepositories();
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.repositories});

  final Repositories repositories;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            auth: repositories.auth,
            users: repositories.users,
            media: repositories.media,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => FollowProvider(
            repository: repositories.follows,
            auth: context.read<AuthProvider>(),
          ),
        ),
        // Match geossocial: só na demonstração por enquanto (ver
        // home_view.dart).
        if (appMode.isDemo)
          ChangeNotifierProvider(
            create: (context) => MatchProvider(
              repository: repositories.matches,
              auth: context.read<AuthProvider>(),
            ),
          ),
        Provider(create: (_) => MediaLoader(repositories.media)),
        ChangeNotifierProvider(
          create: (context) => PostsProvider(
            repository: repositories.posts,
            media: repositories.media,
            loader: context.read<MediaLoader>(),
            auth: context.read<AuthProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => StoriesProvider(
            repository: repositories.stories,
            media: repositories.media,
            loader: context.read<MediaLoader>(),
            auth: context.read<AuthProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => VenuesProvider(
            repository: repositories.presence,
            auth: context.read<AuthProvider>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => PresenceProvider(
            repository: repositories.presence,
            gpsEnabled: !appMode.isDemo,
          ),
        ),
        if (appMode.hasBench)
          ChangeNotifierProvider(
            create: (context) => BenchProvider(
              presence: context.read<PresenceProvider>(),
            ),
          ),
      ],
      child: MaterialApp(
        title: 'OnRolê',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const AuthGate(),
      ),
    );
  }
}
