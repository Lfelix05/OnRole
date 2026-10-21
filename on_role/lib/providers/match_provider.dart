import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/repositories.dart';
import '../models/match.dart';
import '../models/user.dart';
import '../services/affinity.dart';
import 'auth_provider.dart';

/// Match geossocial (H3): sugestões estilo Tinder pela afinidade de locais e
/// gostos de rolê, intercaladas com sugestões sorteadas (grupo controle).
class MatchProvider extends ChangeNotifier {
  MatchProvider({
    required MatchRepository repository,
    required AuthProvider auth,
    math.Random? random,
  }) : _repository = repository,
       _auth = auth,
       _random = random ?? math.Random() {
    auth.addListener(_syncSession);
    _syncSession();
  }

  final MatchRepository _repository;
  final AuthProvider _auth;
  final math.Random _random;
  StreamSubscription<Set<String>>? _swipesSubscription;
  StreamSubscription<List<UserMatch>>? _matchesSubscription;
  String? _userId;
  bool _swipesLoaded = false;
  Set<String> _swiped = const {};
  List<MatchCandidate>? _deck;
  List<UserMatch> _matches = const [];

  /// Falso até as decisões anteriores e os perfis chegarem do banco.
  bool get isReady => _deck != null;

  /// Fila de sugestões; a primeira é a carta de cima.
  List<MatchCandidate> get deck => _deck ?? const [];

  /// Do match mais novo para o mais antigo.
  List<UserMatch> get matches => _matches;

  User? userById(String id) {
    for (final user in _auth.otherUsers) {
      if (user.id == id) return user;
    }
    return null;
  }

  /// Monta a fila de novo com quem ainda não foi avaliado (ex.: depois de
  /// novos check-ins ou de gente nova no app).
  void refreshDeck() {
    _deck = null;
    _buildDeckIfReady();
    notifyListeners();
  }

  /// Registra a decisão e devolve o match se a outra pessoa também curtiu.
  Future<UserMatch?> decide(
    MatchCandidate candidate,
    SwipeDecision decision,
  ) async {
    final me = _auth.currentUser;
    if (me == null) return null;
    // A carta sai da tela na hora; o banco grava em seguida.
    _deck = deck.where((item) => item.user.id != candidate.user.id).toList();
    _swiped = {..._swiped, candidate.user.id};
    notifyListeners();
    try {
      return await _repository.swipe(
        Swipe(
          fromId: me.id,
          toId: candidate.user.id,
          decision: decision,
          source: candidate.source,
          score: (candidate.affinity.score * 1000).round() / 1000,
          createdAt: DateTime.now(),
        ),
      );
    } catch (error) {
      debugPrint('MatchProvider: $error');
      return null;
    }
  }

  void _syncSession() {
    final userId = _auth.currentUser?.id;
    if (userId != _userId) {
      _userId = userId;
      _swipesSubscription?.cancel();
      _matchesSubscription?.cancel();
      _swipesSubscription = null;
      _matchesSubscription = null;
      _swipesLoaded = false;
      _swiped = const {};
      _deck = null;
      _matches = const [];
      if (userId != null) {
        _swipesSubscription = _repository.watchSwipedIds(userId).listen((ids) {
          _swiped = ids;
          _swipesLoaded = true;
          _buildDeckIfReady();
          notifyListeners();
        }, onError: (Object error) => debugPrint('MatchProvider: $error'));
        _matchesSubscription = _repository.watchMatches(userId).listen((
          matches,
        ) {
          _matches = [...matches]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          notifyListeners();
        }, onError: (Object error) => debugPrint('MatchProvider: $error'));
      }
    }
    // Os perfis podem chegar depois das decisões; a fila espera os dois.
    if (_buildDeckIfReady()) notifyListeners();
  }

  /// Monta a fila uma vez só (para as cartas não se embaralharem enquanto a
  /// pessoa decide). Devolve se montou agora.
  bool _buildDeckIfReady() {
    final me = _auth.currentUser;
    if (_deck != null || !_swipesLoaded || !_auth.usersLoaded || me == null) {
      return false;
    }
    _deck = buildDeck(
      me: me,
      others: _auth.otherUsers,
      alreadySwiped: _swiped,
      random: _random,
    );
    return true;
  }

  @override
  void dispose() {
    _auth.removeListener(_syncSession);
    _swipesSubscription?.cancel();
    _matchesSubscription?.cancel();
    super.dispose();
  }
}
