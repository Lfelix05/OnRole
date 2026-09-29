import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/firebase/firebase_repositories.dart';
import 'data/mock/mock_repositories.dart';
import 'data/repositories.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/posts_provider.dart';
import 'providers/presence_provider.dart';
import 'providers/venues_provider.dart';
import 'theme/app_theme.dart';
import 'view/auth_gate.dart';

/// `flutter run --dart-define=BACKEND=mock` roda sem Firebase, com dados de
/// demonstração em memória (útil para apresentar sem internet).
const _useMockBackend = String.fromEnvironment('BACKEND') == 'mock';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MainApp(repositories: await _createRepositories()));
}

Future<Repositories> _createRepositories() async {
  if (_useMockBackend) return createMockRepositories();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    return createFirebaseRepositories();
  } on UnsupportedError catch (error) {
    // Plataformas sem Firebase configurado (ex.: Windows) usam o mock.
    debugPrint('Firebase indisponível nesta plataforma, usando dados mock. $error');
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
          create: (_) => AuthProvider(auth: repositories.auth, users: repositories.users),
        ),
        ChangeNotifierProvider(
          create: (context) => PostsProvider(repository: repositories.posts, auth: context.read<AuthProvider>()),
        ),
        ChangeNotifierProvider(
          create: (context) => VenuesProvider(repository: repositories.presence, auth: context.read<AuthProvider>()),
        ),
        ChangeNotifierProvider(create: (_) => PresenceProvider(repository: repositories.presence)),
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
