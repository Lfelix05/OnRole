import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/match.dart';
import '../repositories.dart';

// Match geossocial no Cloud Firestore:
//
//   swipes/{de}_{para}           from, to, decision, source, score, createdAt
//   matches/{a}_{b}              users [a, b] (em ordem), createdAt
//
// Cada pessoa só lê as próprias decisões e, uma a uma, as curtidas que
// recebeu: é o que confirma um match sem expor quem passou.

class FirebaseMatchRepository implements MatchRepository {
  FirebaseMatchRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _swipes =>
      _db.collection('swipes');

  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection('matches');

  @override
  Stream<Set<String>> watchSwipedIds(String userId) {
    return _swipes
        .where('from', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => {
            for (final doc in snapshot.docs) doc.data()['to'] as String,
          },
        );
  }

  @override
  Future<UserMatch?> swipe(Swipe swipe) async {
    final mine = _swipes.doc('${swipe.fromId}_${swipe.toId}');
    final data = {
      'from': swipe.fromId,
      'to': swipe.toId,
      'decision': swipe.decision.name,
      'source': swipe.source.name,
      'score': swipe.score,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (swipe.decision == SwipeDecision.pass) {
      await mine.set(data);
      return null;
    }

    final matchId = UserMatch.idFor(swipe.fromId, swipe.toId);
    final userIds = [swipe.fromId, swipe.toId]..sort();
    final batch = _db.batch()..set(mine, data);
    final theyLiked = await _likedMe(swipe);
    if (theyLiked) {
      // Curtida e match no mesmo lote: as regras conferem as duas curtidas
      // depois da gravação (getAfter).
      batch.set(_matches.doc(matchId), {
        'users': userIds,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    if (theyLiked) return _match(matchId, userIds);

    // Se os dois curtiram ao mesmo tempo, nenhum viu a curtida do outro antes
    // de gravar; uma segunda checagem fecha esse buraco.
    if (!await _likedMe(swipe)) return null;
    try {
      await _matches.doc(matchId).set({
        'users': userIds,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      // O outro lado já criou o match (o documento só pode ser criado uma vez).
      if (error.code != 'permission-denied') rethrow;
    }
    return _match(matchId, userIds);
  }

  @override
  Stream<List<UserMatch>> watchMatches(String userId) {
    return _matches
        .where('users', arrayContains: userId)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              UserMatch(
                id: doc.id,
                userIds: List<String>.from(doc.data()['users'] as List),
                createdAt:
                    (doc.data()['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
              ),
          ],
        );
  }

  /// A outra pessoa já curtiu? As regras só liberam ler a curtida recebida;
  /// "passou" e "ainda não decidiu" aparecem iguais (acesso negado).
  Future<bool> _likedMe(Swipe swipe) async {
    try {
      final theirs = await _swipes.doc('${swipe.toId}_${swipe.fromId}').get();
      return theirs.exists && theirs.data()?['decision'] == 'like';
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return false;
      rethrow;
    }
  }

  static UserMatch _match(String id, List<String> userIds) =>
      UserMatch(id: id, userIds: userIds, createdAt: DateTime.now());
}
