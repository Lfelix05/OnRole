#!/usr/bin/env node
// Cria os perfis de demonstração no Firebase como o próprio app faria: cada
// perfil é uma conta de verdade (e-mail e senha), e tudo passa pelas regras do
// Firestore (firestore.rules). Veja README.md nesta pasta.
//
//   node seed.js                  cria no projeto onrole-tcc
//   node seed.js --state <arq>    outro arquivo de estado (ex.: no emulador)
//
// O estado (e-mails, senhas e ids das contas criadas) fica em out/, fora do
// git. Rodar de novo continua de onde parou e não duplica nada.

import { randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

import { initializeApp } from 'firebase/app';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
  signInWithEmailAndPassword,
  updateProfile,
} from 'firebase/auth';
import {
  arrayUnion,
  Bytes,
  collection,
  connectFirestoreEmulator,
  doc,
  getFirestore,
  increment,
  serverTimestamp,
  setDoc,
  terminate,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import sharp from 'sharp';

import { posts, profiles } from './profiles.js';

const here = dirname(fileURLToPath(import.meta.url));
const { values: args } = parseArgs({
  options: { state: { type: 'string', default: join(here, 'out', 'state.json') } },
});

// Configuração pública do app web (a mesma de lib/firebase_options.dart).
const firebaseConfig = {
  apiKey: 'AIzaSyCHcJ4Bp3NRhIZUnZeWWrLSnVrobtbvUiw',
  appId: '1:123172023193:web:c3cda76a4a755f66ae0108',
  messagingSenderId: '123172023193',
  projectId: 'onrole-tcc',
  authDomain: 'onrole-tcc.firebaseapp.com',
};

// Igual ao app (lib/data/repositories.dart): pedaços de até 900 KB.
const CHUNK_SIZE = 900 * 1024;

const authEmulator = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const firestoreEmulator = process.env.FIRESTORE_EMULATOR_HOST;
const usingEmulator = Boolean(authEmulator && firestoreEmulator);
// Com só um dos emuladores ativo, o outro serviço seria o de produção.
if (Boolean(authEmulator) !== Boolean(firestoreEmulator)) {
  console.error('Só um dos emuladores (Auth ou Firestore) está ativo. Ligue os dois ou nenhum.');
  process.exit(1);
}
if (usingEmulator) firebaseConfig.projectId = process.env.GCLOUD_PROJECT ?? 'demo-onrole';

function loadState() {
  return existsSync(args.state)
    ? JSON.parse(readFileSync(args.state, 'utf8'))
    : { accounts: {}, postsCreated: 0 };
}

function saveState(state) {
  mkdirSync(dirname(args.state), { recursive: true });
  writeFileSync(args.state, JSON.stringify(state, null, 2));
}

/// Uma instância do Firebase por perfil: cada uma com a própria sessão.
function sessionFor(slug) {
  const app = initializeApp(firebaseConfig, `demo-${slug}`);
  const auth = getAuth(app);
  const db = getFirestore(app);
  if (usingEmulator) {
    connectAuthEmulator(auth, `http://${authEmulator}`, { disableWarnings: true });
    const [host, port] = firestoreEmulator.split(':');
    connectFirestoreEmulator(db, host, Number(port));
  }
  return { auth, db };
}

/// Envia uma foto como o app: metadados primeiro, depois os pedaços.
async function uploadImage(db, uid, fileName) {
  const bytes = readFileSync(join(here, 'images', fileName));
  const { width, height } = await sharp(bytes).metadata();
  const chunkCount = Math.ceil(bytes.length / CHUNK_SIZE);
  const media = doc(collection(db, 'media'));
  await setDoc(media, {
    ownerId: uid,
    kind: 'image',
    mimeType: 'image/jpeg',
    size: bytes.length,
    chunkCount,
    createdAt: serverTimestamp(),
  });
  for (let i = 0; i < chunkCount; i++) {
    const part = bytes.subarray(i * CHUNK_SIZE, (i + 1) * CHUNK_SIZE);
    await setDoc(doc(media, 'chunks', String(i)), { data: Bytes.fromUint8Array(new Uint8Array(part)) });
  }
  return {
    id: media.id,
    kind: 'image',
    mimeType: 'image/jpeg',
    chunkCount,
    aspectRatio: Math.round((width / height) * 1000) / 1000,
    durationMs: null,
  };
}

async function createProfile(profile, session, state) {
  let account = state.accounts[profile.slug];
  if (!account) {
    account = {
      email: `demo.${profile.slug}@example.com`,
      password: randomBytes(12).toString('base64url'),
    };
    const credential = await createUserWithEmailAndPassword(session.auth, account.email, account.password);
    account.uid = credential.user.uid;
    state.accounts[profile.slug] = account;
    saveState(state);
  } else {
    await signInWithEmailAndPassword(session.auth, account.email, account.password);
  }
  if (account.profileDone) return account;

  const { db, auth } = session;
  const uid = account.uid;
  await updateProfile(auth.currentUser, { displayName: profile.name });

  // O mesmo cadastro do app (FirebaseAuthRepository.register)...
  const user = doc(db, 'users', uid);
  const batch = writeBatch(db);
  batch.set(user, { name: profile.name, bio: null, avatarUrl: null, visits: {}, createdAt: serverTimestamp() });
  batch.set(doc(user, 'private', 'account'), {
    email: account.email,
    birthDate: Timestamp.fromDate(new Date(profile.birthDate + 'T12:00:00-03:00')),
  });
  await batch.commit();

  // ...e depois "Editar perfil", com as visitas que os check-ins teriam somado.
  const photo = await uploadImage(db, uid, profile.avatar);
  await updateDoc(user, { bio: profile.bio, interests: profile.interests, photo, visits: profile.visits });

  account.profileDone = true;
  saveState(state);
  console.log(`  ${profile.name}: perfil pronto`);
  return account;
}

async function main() {
  console.log(usingEmulator ? 'Emulador local' : `Projeto ${firebaseConfig.projectId}`);
  const state = loadState();
  const sessions = Object.fromEntries(profiles.map((profile) => [profile.slug, sessionFor(profile.slug)]));
  const names = Object.fromEntries(profiles.map((profile) => [profile.slug, profile.name]));

  for (const profile of profiles) {
    await createProfile(profile, sessions[profile.slug], state);
  }
  const uid = (slug) => state.accounts[slug].uid;

  const already = state.postsCreated ?? 0;
  if (already >= posts.length) {
    console.log('Os posts já tinham sido criados.');
  } else {
    for (const post of posts.slice(already)) {
      const { db } = sessions[post.author];
      const media = [];
      for (const photo of post.photos ?? []) media.push(await uploadImage(db, uid(post.author), photo));
      const ref = doc(collection(db, 'posts'));
      await setDoc(ref, {
        authorId: uid(post.author),
        authorName: names[post.author],
        text: post.text,
        media,
        venueId: post.venueId ?? null,
        atVenue: false,
        likedBy: [],
        replyCount: 0,
        createdAt: serverTimestamp(),
      });
      // Curtidas e respostas de outros perfis, cada um com a própria conta.
      for (const liker of post.likedBy ?? []) {
        await updateDoc(doc(sessions[liker].db, 'posts', ref.id), { likedBy: arrayUnion(uid(liker)) });
      }
      for (const reply of post.replies ?? []) {
        const { db: replierDb } = sessions[reply.from];
        const postRef = doc(replierDb, 'posts', ref.id);
        const replyRef = doc(collection(postRef, 'replies'));
        const replyBatch = writeBatch(replierDb);
        replyBatch.set(replyRef, {
          authorId: uid(reply.from),
          authorName: names[reply.from],
          text: reply.text,
          createdAt: serverTimestamp(),
        });
        replyBatch.update(postRef, { replyCount: increment(1), lastReplyId: replyRef.id });
        await replyBatch.commit();
      }
      state.postsCreated = (state.postsCreated ?? 0) + 1;
      saveState(state);
      // Um pequeno intervalo deixa os horários dos posts diferentes no feed.
      await new Promise((resolve) => setTimeout(resolve, 1500));
    }
    console.log(`  ${posts.length - already} posts criados`);
  }

  await Promise.all(Object.values(sessions).map(({ db }) => terminate(db)));
  console.log(`Pronto. Contas salvas em ${args.state}`);
  process.exit(0);
}

main().catch((error) => {
  console.error(error.code ?? '', error.message ?? error);
  process.exit(1);
});
