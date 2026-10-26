import '../../models/match.dart';
import '../repositories.dart';
import 'mock_database.dart';

// Match geossocial em memória. As validações repetem
// as regras do Firestore (firestore.rules).

class MockMatchRepository implements MatchRepository {
  MockMatchRepository(this._db);

  final MockDatabase _db;

  @override
  Stream<Set<String>> watchSwipedIds(String userId) {
    return watchValue(_db.changes, () => _db.swipedIdsOf(userId));
  }

  @override
  Future<UserMatch?> swipe(Swipe swipe) async {
    if (swipe.fromId == swipe.toId) throw StateError('Não dá para se avaliar.');
    _db.putSwipe(swipe);
    if (swipe.decision != SwipeDecision.like) return null;
    final theirs = _db.swipeOf(swipe.toId, swipe.fromId);
    if (theirs?.decision != SwipeDecision.like) return null;

    final match = UserMatch(
      id: UserMatch.idFor(swipe.fromId, swipe.toId),
      userIds: [swipe.fromId, swipe.toId]..sort(),
      createdAt: DateTime.now(),
    );
    _db.addMatch(match);
    return match;
  }

  @override
  Stream<List<UserMatch>> watchMatches(String userId) {
    return watchValue(_db.changes, () => _db.matchesOf(userId));
  }
}
