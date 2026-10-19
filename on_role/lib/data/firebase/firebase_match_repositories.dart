import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../models/match.dart';
import '../repositories.dart';

// Match geossocial e dados do experimento no Cloud Firestore:
//
//   swipes/{de}_{para}           from, to, decision, source, score, createdAt
//   matches/{a}_{b}              users [a, b] (em ordem), createdAt
//   telemetry/{uid}/batches/{id} events[], count, createdAt
//   users/{uid}/private/experiment   enrolled, updatedAt
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

class FirebaseExperimentRepository implements ExperimentRepository {
  FirebaseExperimentRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _consent(String userId) => _db
      .collection('users')
      .doc(userId)
      .collection('private')
      .doc('experiment');

  CollectionReference<Map<String, dynamic>> _batches(String userId) =>
      _db.collection('telemetry').doc(userId).collection('batches');

  @override
  Future<bool> isEnrolled(String userId) async {
    final doc = await _consent(userId).get();
    return doc.data()?['enrolled'] == true;
  }

  @override
  Future<void> setEnrolled(String userId, bool enrolled) {
    return _consent(
      userId,
    ).set({'enrolled': enrolled, 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> upload(String userId, List<Map<String, Object?>> events) async {
    // Sem esperar o servidor: offline (bar sem sinal), o Firestore guarda o
    // lote no aparelho e envia quando a conexão voltar.
    _batches(userId)
        .add({
          'events': events,
          'count': events.length,
          'createdAt': FieldValue.serverTimestamp(),
        })
        .then<void>(
          (_) {},
          onError: (Object error) => debugPrint('Experimento: $error'),
        );
  }

  @override
  Future<void> deleteAll(String userId) async {
    final snapshot = await _batches(userId).get();
    for (var start = 0; start < snapshot.docs.length; start += 400) {
      final batch = _db.batch();
      for (final doc in snapshot.docs.skip(start).take(400)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
