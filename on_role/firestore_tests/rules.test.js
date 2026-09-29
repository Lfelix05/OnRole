// Testes das regras de segurança do Firestore (../firestore.rules). Rodam no
// emulador local, num projeto "demo-" que nunca toca o banco de verdade:
//
//   cd on_role
//   firebase emulators:exec --only firestore --project demo-onrole "npm --prefix firestore_tests test"
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  FieldPath,
  getDoc,
  getDocs,
  increment,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-onrole',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(() => env.clearFirestore());

const as = (uid) => env.authenticatedContext(uid).firestore();
const anonymous = () => env.unauthenticatedContext().firestore();
const seed = (write) => env.withSecurityRulesDisabled((context) => write(context.firestore()));

const hoursFromNow = (hours) => Timestamp.fromMillis(Date.now() + hours * 60 * 60 * 1000);
const minutesAgo = (minutes) => Timestamp.fromMillis(Date.now() - minutes * 60 * 1000);

function newPost(overrides = {}) {
  return {
    authorId: 'ana',
    authorName: 'Ana',
    venueId: 'boteco-central',
    title: 'Novo rolê',
    content: 'Bar cheio e som bom!',
    type: 'text',
    createdAt: serverTimestamp(),
    expiresAt: hoursFromNow(12),
    ...overrides,
  };
}

function presentAt(uid, venueId, lastSeenAt = Timestamp.now()) {
  return seed((db) => setDoc(doc(db, 'presence', uid), { venueId, since: minutesAgo(5), lastSeenAt }));
}

describe('leitura', () => {
  test('quem não está logado não lê nada', async () => {
    await assertFails(getDocs(collection(anonymous(), 'posts')));
    await assertFails(getDoc(doc(anonymous(), 'users/ana')));
    await assertFails(getDocs(collection(anonymous(), 'presence')));
  });

  test('quem está logado lê perfis, presenças e posts', async () => {
    const db = as('bia');
    await assertSucceeds(getDoc(doc(db, 'users/ana')));
    await assertSucceeds(getDocs(collection(db, 'presence')));
    await assertSucceeds(getDocs(collection(db, 'posts')));
  });

  test('dados privados e histórico de check-ins só para o dono', async () => {
    await assertSucceeds(getDoc(doc(as('ana'), 'users/ana/private/account')));
    await assertFails(getDoc(doc(as('bia'), 'users/ana/private/account')));
    await assertSucceeds(getDocs(collection(as('ana'), 'users/ana/checkins')));
    await assertFails(getDocs(collection(as('bia'), 'users/ana/checkins')));
  });
});

describe('perfil', () => {
  const profile = { name: 'Ana', bio: null, avatarUrl: null, visits: {}, createdAt: serverTimestamp() };

  test('cada um cria só o próprio perfil', async () => {
    await assertSucceeds(setDoc(doc(as('ana'), 'users/ana'), profile));
    await assertFails(setDoc(doc(as('bia'), 'users/ana'), profile));
  });

  test('perfil público não aceita campos extras, como o e-mail', async () => {
    await assertFails(setDoc(doc(as('ana'), 'users/ana'), { ...profile, email: 'ana@exemplo.com' }));
  });

  test('só o dono conta as próprias visitas', async () => {
    await seed((db) => setDoc(doc(db, 'users/ana'), { ...profile, createdAt: Timestamp.now() }));
    const visit = [new FieldPath('visits', 'boteco-central'), increment(1)];
    await assertSucceeds(updateDoc(doc(as('ana'), 'users/ana'), ...visit));
    await assertFails(updateDoc(doc(as('bia'), 'users/ana'), ...visit));
  });
});

describe('presença', () => {
  const presence = { venueId: 'boteco-central', since: Timestamp.now(), lastSeenAt: serverTimestamp() };

  test('cada um marca só a própria presença', async () => {
    await assertSucceeds(setDoc(doc(as('ana'), 'presence/ana'), presence));
    await assertFails(setDoc(doc(as('bia'), 'presence/ana'), presence));
  });

  test('presença não aceita coordenadas', async () => {
    await assertFails(setDoc(doc(as('ana'), 'presence/ana'), { ...presence, lat: -19.53, lng: -40.62 }));
  });

  test('lastSeenAt tem que ser a hora do servidor, não do aparelho', async () => {
    await assertFails(setDoc(doc(as('ana'), 'presence/ana'), { ...presence, lastSeenAt: hoursFromNow(5) }));
  });
});

describe('posts: só quem está no local posta (H2)', () => {
  const posts = (uid) => collection(as(uid), 'posts');

  test('sem check-in, não posta', async () => {
    await assertFails(addDoc(posts('ana'), newPost()));
  });

  test('com check-in em outro local, não posta', async () => {
    await presentAt('ana', 'praca-municipal');
    await assertFails(addDoc(posts('ana'), newPost()));
  });

  test('com check-in no local, posta', async () => {
    await presentAt('ana', 'boteco-central');
    await assertSucceeds(addDoc(posts('ana'), newPost()));
  });

  test('presença sem renovação há mais de 20 minutos não vale', async () => {
    await presentAt('ana', 'boteco-central', minutesAgo(30));
    await assertFails(addDoc(posts('ana'), newPost()));
  });

  test('não posta em nome de outra pessoa', async () => {
    await presentAt('ana', 'boteco-central');
    await presentAt('bia', 'boteco-central');
    await assertFails(addDoc(posts('ana'), newPost({ authorId: 'bia' })));
  });

  test('post precisa expirar em até 13 horas', async () => {
    await presentAt('ana', 'boteco-central');
    await assertFails(addDoc(posts('ana'), newPost({ expiresAt: hoursFromNow(48) })));
  });

  test('texto entre 1 e 500 caracteres', async () => {
    await presentAt('ana', 'boteco-central');
    await assertFails(addDoc(posts('ana'), newPost({ content: '' })));
    await assertFails(addDoc(posts('ana'), newPost({ content: 'x'.repeat(501) })));
  });

  test('ninguém edita; só o autor apaga', async () => {
    await seed((db) => setDoc(doc(db, 'posts/p1'), { ...newPost(), createdAt: Timestamp.now() }));
    await assertFails(updateDoc(doc(as('ana'), 'posts/p1'), { content: 'editado' }));
    await assertFails(deleteDoc(doc(as('bia'), 'posts/p1')));
    await assertSucceeds(deleteDoc(doc(as('ana'), 'posts/p1')));
  });
});

describe('histórico de check-ins', () => {
  test('o dono abre e fecha o próprio check-in', async () => {
    const checkIn = doc(as('ana'), 'users/ana/checkins/c1');
    await assertSucceeds(setDoc(checkIn, { venueId: 'boteco-central', checkedInAt: Timestamp.now(), checkedOutAt: null }));
    await assertSucceeds(updateDoc(checkIn, { checkedOutAt: Timestamp.now() }));
  });

  test('não mexe no histórico de outra pessoa', async () => {
    const checkIn = { venueId: 'boteco-central', checkedInAt: Timestamp.now(), checkedOutAt: null };
    await assertFails(setDoc(doc(as('bia'), 'users/ana/checkins/c1'), checkIn));
  });
});
