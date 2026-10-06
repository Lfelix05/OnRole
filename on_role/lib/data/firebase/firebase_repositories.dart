import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../models/check_in.dart';
import '../../models/user.dart';
import '../repositories.dart';
import 'firebase_social_repositories.dart';

// Estrutura do Firestore (as regras de acesso estão em firestore.rules):
//
//   users/{uid}                    perfil público: name, bio, avatarUrl, visits, createdAt
//   users/{uid}/private/account    só o dono: email, birthDate
//   users/{uid}/checkins/{id}      só o dono: venueId, checkedInAt, checkedOutAt
//   presence/{uid}                 onde o usuário está agora: venueId, since, lastSeenAt
//   posts, stories e media         ver firebase_social_repositories.dart
//
// Nenhum documento guarda coordenadas: a geocerca roda no aparelho e só o
// local do check-in sobe para o servidor.

/// Repositórios sobre o Firebase (Auth + Cloud Firestore).
Repositories createFirebaseRepositories() {
  final auth = fb.FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  return Repositories(
    auth: FirebaseAuthRepository(auth, db),
    users: FirebaseUserRepository(db),
    presence: FirebasePresenceRepository(db),
    posts: FirebasePostRepository(db),
    stories: FirebaseStoryRepository(db),
    media: FirebaseMediaRepository(db),
  );
}

User _userFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const {};
  final visits = data['visits'] as Map<String, dynamic>? ?? const {};
  return User(
    id: doc.id,
    name: data['name'] as String? ?? 'Usuário',
    bio: data['bio'] as String?,
    avatarUrl: data['avatarUrl'] as String?,
    visits: {for (final entry in visits.entries) entry.key: (entry.value as num).toInt()},
  );
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._db);

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  Stream<User?> watchCurrentUser() {
    StreamSubscription<fb.User?>? sessionSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? profileSubscription;
    late final StreamController<User?> controller;

    controller = StreamController<User?>(
      onListen: () {
        sessionSubscription = _auth.authStateChanges().listen((account) {
          profileSubscription?.cancel();
          profileSubscription = null;
          if (account == null) {
            controller.add(null);
            return;
          }
          // Até o perfil chegar (ou logo depois do cadastro, antes de ele ser
          // gravado), o nome vem da própria conta.
          controller.add(User(id: account.uid, name: account.displayName ?? 'Usuário'));
          profileSubscription = _db.collection('users').doc(account.uid).snapshots().listen(
            (doc) {
              if (doc.exists) controller.add(_userFromDoc(doc));
            },
            onError: controller.addError,
          );
        }, onError: controller.addError);
      },
      onCancel: () async {
        await profileSubscription?.cancel();
        await sessionSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseException catch (error) {
      throw AuthException(_describe(error));
    }
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    required DateTime birthDate,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final account = credential.user!;
      await account.updateDisplayName(name.trim());

      final profile = _db.collection('users').doc(account.uid);
      final batch = _db.batch()
        ..set(profile, {
          'name': name.trim(),
          'bio': null,
          'avatarUrl': null,
          'visits': <String, int>{},
          'createdAt': FieldValue.serverTimestamp(),
        })
        ..set(profile.collection('private').doc('account'), {
          'email': email.trim(),
          'birthDate': Timestamp.fromDate(birthDate),
        });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw AuthException(_describe(error));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static String _describe(FirebaseException error) {
    // No Android esse caso chega como erro genérico, só com o motivo no texto.
    if (error.message?.contains('CONFIGURATION_NOT_FOUND') ?? false) {
      return _authNotEnabled;
    }
    switch (error.code) {
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Já existe uma conta com esse e-mail.';
      case 'weak-password':
        return 'Senha fraca: use pelo menos 6 caracteres.';
      case 'network-request-failed':
      case 'unavailable':
        return 'Sem conexão com a internet.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente de novo em alguns minutos.';
      case 'operation-not-allowed':
      case 'configuration-not-found':
        return _authNotEnabled;
      default:
        return 'Não foi possível concluir (${error.code}).';
    }
  }

  static const _authNotEnabled =
      'O login por e-mail ainda não foi ativado no Firebase (Authentication > Sign-in method).';
}

class FirebaseUserRepository implements UserRepository {
  FirebaseUserRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<User>> watchUsers() {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => [for (final doc in snapshot.docs) _userFromDoc(doc)]);
  }
}

class FirebasePresenceRepository implements PresenceRepository {
  FirebasePresenceRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _presenceOf(String userId) => _db.collection('presence').doc(userId);

  DocumentReference<Map<String, dynamic>> _historyOf(CheckIn checkIn) {
    return _db.collection('users').doc(checkIn.userId).collection('checkins').doc(checkIn.id);
  }

  @override
  Future<void> checkIn(CheckIn checkIn) async {
    final batch = _db.batch()
      ..set(_historyOf(checkIn), {
        'venueId': checkIn.venueId,
        'checkedInAt': Timestamp.fromDate(checkIn.checkedInAt),
        'checkedOutAt': null,
      })
      ..set(_presenceOf(checkIn.userId), {
        'venueId': checkIn.venueId,
        'since': Timestamp.fromDate(checkIn.checkedInAt),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    await batch.commit();

    // Fora do lote: se o perfil não existir, a presença já foi gravada mesmo
    // assim. FieldPath porque os ids dos locais têm hífen.
    await _db.collection('users').doc(checkIn.userId).update({
      FieldPath(['visits', checkIn.venueId]): FieldValue.increment(1),
    });
  }

  @override
  Future<void> checkOut(CheckIn checkIn) {
    final batch = _db.batch()
      ..update(_historyOf(checkIn), {
        'checkedOutAt': Timestamp.fromDate(checkIn.checkedOutAt ?? DateTime.now()),
      })
      ..delete(_presenceOf(checkIn.userId));
    return batch.commit();
  }

  @override
  Future<void> keepAlive(CheckIn checkIn) {
    return _presenceOf(checkIn.userId).update({'lastSeenAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> clearPresence(String userId) => _presenceOf(userId).delete();

  @override
  Stream<Map<String, int>> watchCrowd() {
    QuerySnapshot<Map<String, dynamic>>? latest;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? subscription;
    Timer? timer;
    late final StreamController<Map<String, int>> controller;

    void emitCounts() {
      final snapshot = latest;
      if (snapshot == null) return;
      final now = DateTime.now();
      final counts = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final venueId = data['venueId'] as String?;
        // Escrita local ainda sem a hora do servidor conta como recente.
        final lastSeenAt = (data['lastSeenAt'] as Timestamp?)?.toDate() ?? now;
        if (venueId != null && now.difference(lastSeenAt) < presenceTimeout) {
          counts[venueId] = (counts[venueId] ?? 0) + 1;
        }
      }
      controller.add(counts);
    }

    controller = StreamController(
      onListen: () {
        subscription = _db.collection('presence').snapshots().listen(
          (snapshot) {
            latest = snapshot;
            emitCounts();
          },
          onError: controller.addError,
        );
        // A janela de validade anda com o relógio, mesmo sem mudança no banco.
        timer = Timer.periodic(const Duration(minutes: 1), (_) => emitCounts());
      },
      onCancel: () {
        timer?.cancel();
        return subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
