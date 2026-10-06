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
  arrayRemove,
  arrayUnion,
  Bytes,
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
  writeBatch,
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

const photo = { id: 'm1', kind: 'image', mimeType: 'image/jpeg', chunkCount: 1, aspectRatio: 1.5, durationMs: null };

function newPost(overrides = {}) {
  return {
    authorId: 'ana',
    authorName: 'Ana',
    text: 'Alguém topa o Boteco hoje?',
    media: [],
    venueId: null,
    atVenue: false,
    likedBy: [],
    replyCount: 0,
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

function presentAt(uid, venueId, lastSeenAt = Timestamp.now()) {
  return seed((db) => setDoc(doc(db, 'presence', uid), { venueId, since: minutesAgo(5), lastSeenAt }));
}

function seedPost(id, overrides = {}) {
  return seed((db) => setDoc(doc(db, 'posts', id), { ...newPost(), createdAt: Timestamp.now(), ...overrides }));
}

describe('leitura', () => {
  test('quem não está logado não lê nada', async () => {
    await assertFails(getDocs(collection(anonymous(), 'posts')));
    await assertFails(getDoc(doc(anonymous(), 'users/ana')));
    await assertFails(getDocs(collection(anonymous(), 'presence')));
    await assertFails(getDocs(collection(anonymous(), 'stories')));
    await assertFails(getDoc(doc(anonymous(), 'media/m1')));
  });

  test('quem está logado lê perfis, presenças, posts, stories e mídia', async () => {
    const db = as('bia');
    await assertSucceeds(getDoc(doc(db, 'users/ana')));
    await assertSucceeds(getDocs(collection(db, 'presence')));
    await assertSucceeds(getDocs(collection(db, 'posts')));
    await assertSucceeds(getDocs(collection(db, 'posts/p1/replies')));
    await assertSucceeds(getDocs(collection(db, 'stories')));
    await assertSucceeds(getDocs(collection(db, 'media/m1/chunks')));
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

describe('posts', () => {
  const posts = (uid) => collection(as(uid), 'posts');

  test('qualquer pessoa logada posta, sem check-in', async () => {
    await assertSucceeds(addDoc(posts('ana'), newPost()));
  });

  test('marcar um local sem estar lá é permitido (combinar um rolê)', async () => {
    await assertSucceeds(addDoc(posts('ana'), newPost({ venueId: 'boteco-central' })));
  });

  test('post só com fotos/vídeos, sem texto, é permitido', async () => {
    await assertSucceeds(addDoc(posts('ana'), newPost({ text: '', media: [photo] })));
  });

  test('não posta vazio, nem com mais de 4 mídias ou texto acima de 500', async () => {
    await assertFails(addDoc(posts('ana'), newPost({ text: '' })));
    await assertFails(addDoc(posts('ana'), newPost({ media: [photo, photo, photo, photo, photo] })));
    await assertFails(addDoc(posts('ana'), newPost({ text: 'x'.repeat(501) })));
  });

  test('não posta em nome de outra pessoa nem já com curtidas', async () => {
    await assertFails(addDoc(posts('ana'), newPost({ authorId: 'bia' })));
    await assertFails(addDoc(posts('ana'), newPost({ likedBy: ['ana', 'bia'] })));
    await assertFails(addDoc(posts('ana'), newPost({ replyCount: 9 })));
  });

  describe('selo "no rolê agora" (H2)', () => {
    const verified = { venueId: 'boteco-central', atVenue: true };

    test('sem check-in, o selo é recusado', async () => {
      await assertFails(addDoc(posts('ana'), newPost(verified)));
    });

    test('com check-in em outro local, o selo é recusado', async () => {
      await presentAt('ana', 'praca-municipal');
      await assertFails(addDoc(posts('ana'), newPost(verified)));
    });

    test('com check-in no local, o selo é aceito', async () => {
      await presentAt('ana', 'boteco-central');
      await assertSucceeds(addDoc(posts('ana'), newPost(verified)));
    });

    test('presença sem renovação há mais de 20 minutos não vale', async () => {
      await presentAt('ana', 'boteco-central', minutesAgo(30));
      await assertFails(addDoc(posts('ana'), newPost(verified)));
    });
  });

  test('curtir e descurtir só com o próprio id', async () => {
    await seedPost('p1');
    const post = (uid) => doc(as(uid), 'posts/p1');

    await assertSucceeds(updateDoc(post('bia'), { likedBy: arrayUnion('bia') }));
    await assertFails(updateDoc(post('bia'), { likedBy: arrayUnion('caio') }));
    await assertFails(updateDoc(post('caio'), { likedBy: arrayRemove('bia') }));
    await assertSucceeds(updateDoc(post('bia'), { likedBy: arrayRemove('bia') }));
  });

  test('ninguém edita o texto; só o autor apaga', async () => {
    await seedPost('p1');
    await assertFails(updateDoc(doc(as('ana'), 'posts/p1'), { text: 'editado' }));
    await assertFails(deleteDoc(doc(as('bia'), 'posts/p1')));
    await assertSucceeds(deleteDoc(doc(as('ana'), 'posts/p1')));
  });

  describe('respostas', () => {
    function replyBatch(db, { replyId = 'r1', count = increment(1), lastReplyId = replyId, author = 'bia' } = {}) {
      const batch = writeBatch(db);
      batch.set(doc(db, `posts/p1/replies/${replyId}`), {
        authorId: author,
        authorName: 'Bia',
        text: 'Tô dentro!',
        createdAt: serverTimestamp(),
      });
      batch.update(doc(db, 'posts/p1'), { replyCount: count, lastReplyId });
      return batch.commit();
    }

    test('resposta e contador sobem juntos', async () => {
      await seedPost('p1');
      await assertSucceeds(replyBatch(as('bia')));
    });

    test('resposta sem subir o contador é recusada', async () => {
      await seedPost('p1');
      const db = as('bia');
      await assertFails(
        setDoc(doc(db, 'posts/p1/replies/r1'), {
          authorId: 'bia',
          authorName: 'Bia',
          text: 'Oi',
          createdAt: serverTimestamp(),
        }),
      );
    });

    test('não dá para inflar o contador', async () => {
      await seedPost('p1');
      await assertFails(updateDoc(doc(as('bia'), 'posts/p1'), { replyCount: increment(1), lastReplyId: 'nada' }));
      await assertFails(replyBatch(as('bia'), { count: increment(5) }));
    });

    test('não responde em nome de outra pessoa', async () => {
      await seedPost('p1');
      await assertFails(replyBatch(as('bia'), { author: 'ana' }));
    });
  });
});

describe('stories', () => {
  function newStory(overrides = {}) {
    return {
      authorId: 'ana',
      authorName: 'Ana',
      media: photo,
      venueId: null,
      atVenue: false,
      createdAt: serverTimestamp(),
      expiresAt: hoursFromNow(24),
      ...overrides,
    };
  }

  test('posta um story que vence em até 24 h', async () => {
    await assertSucceeds(addDoc(collection(as('ana'), 'stories'), newStory()));
  });

  test('story não pode durar mais que um dia', async () => {
    await assertFails(addDoc(collection(as('ana'), 'stories'), newStory({ expiresAt: hoursFromNow(72) })));
  });

  test('selo no story também exige check-in', async () => {
    const verified = newStory({ venueId: 'boteco-central', atVenue: true });
    await assertFails(addDoc(collection(as('ana'), 'stories'), verified));
    await presentAt('ana', 'boteco-central');
    await assertSucceeds(addDoc(collection(as('ana'), 'stories'), verified));
  });

  test('só o autor apaga o story', async () => {
    await seed((db) => setDoc(doc(db, 'stories/s1'), { ...newStory(), createdAt: Timestamp.now() }));
    await assertFails(deleteDoc(doc(as('bia'), 'stories/s1')));
    await assertSucceeds(deleteDoc(doc(as('ana'), 'stories/s1')));
  });
});

describe('mídia em pedaços', () => {
  const meta = {
    ownerId: 'ana',
    kind: 'video',
    mimeType: 'video/mp4',
    size: 2_000_000,
    chunkCount: 3,
    createdAt: serverTimestamp(),
  };
  const chunk = (size) => ({ data: Bytes.fromUint8Array(new Uint8Array(size)) });

  test('o dono cria os metadados e depois os pedaços', async () => {
    const db = as('ana');
    await assertSucceeds(setDoc(doc(db, 'media/m1'), meta));
    await assertSucceeds(setDoc(doc(db, 'media/m1/chunks/0'), chunk(900 * 1024)));
    await assertSucceeds(setDoc(doc(db, 'media/m1/chunks/2'), chunk(10)));
  });

  test('não aceita arquivo acima de 10 MB nem mais de 12 pedaços', async () => {
    await assertFails(setDoc(doc(as('ana'), 'media/m1'), { ...meta, size: 11 * 1024 * 1024 }));
    await assertFails(setDoc(doc(as('ana'), 'media/m1'), { ...meta, chunkCount: 13 }));
  });

  test('pedaço só do dono, dentro da quantidade e até 950 KB', async () => {
    await seed((db) => setDoc(doc(db, 'media/m1'), { ...meta, createdAt: Timestamp.now() }));
    await assertFails(setDoc(doc(as('bia'), 'media/m1/chunks/0'), chunk(10)));
    await assertFails(setDoc(doc(as('ana'), 'media/m1/chunks/3'), chunk(10)));
    await assertFails(setDoc(doc(as('ana'), 'media/m1/chunks/0'), chunk(960_000)));
  });

  test('pedaço sem metadados é recusado', async () => {
    await assertFails(setDoc(doc(as('ana'), 'media/sem-meta/chunks/0'), chunk(10)));
  });

  test('pedaços não podem ser trocados depois de enviados', async () => {
    const db = as('ana');
    await assertSucceeds(setDoc(doc(db, 'media/m1'), meta));
    await assertSucceeds(setDoc(doc(db, 'media/m1/chunks/0'), chunk(10)));
    await assertFails(setDoc(doc(db, 'media/m1/chunks/0'), chunk(20)));
  });

  test('só o dono apaga', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'media/m1'), { ...meta, createdAt: Timestamp.now() });
      await setDoc(doc(db, 'media/m1/chunks/0'), chunk(10));
    });
    await assertFails(deleteDoc(doc(as('bia'), 'media/m1/chunks/0')));
    await assertSucceeds(deleteDoc(doc(as('ana'), 'media/m1/chunks/0')));
    await assertFails(deleteDoc(doc(as('bia'), 'media/m1')));
    await assertSucceeds(deleteDoc(doc(as('ana'), 'media/m1')));
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
