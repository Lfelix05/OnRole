#!/usr/bin/env node
// Remove os perfis de demonstração e tudo o que eles deixaram: posts (com as
// respostas, inclusive de pessoas reais), fotos, stories, curtidas dadas,
// decisões e matches nas Conexões, presença e a própria conta. Usa o Admin
// SDK, porque as regras não deixam ninguém apagar o próprio perfil pelo app.
//
//   node remove.js                encontra as contas demo.*@example.com
//   node remove.js --state <arq>  usa também as contas de outro estado

import { existsSync, readFileSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const { values: args } = parseArgs({
  options: {
    state: { type: 'string', default: join(here, 'out', 'state.json') },
    project: { type: 'string', default: process.env.GCLOUD_PROJECT ?? 'onrole-tcc' },
  },
});

const DEMO_EMAIL = /^demo\.[a-z0-9-]+@example\.com$/;

const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_AUTH_EMULATOR_HOST);
// Com só um dos emuladores ativo, o outro serviço seria o de produção.
if (Boolean(process.env.FIRESTORE_EMULATOR_HOST) !== Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST)) {
  console.error('Só um dos emuladores (Auth ou Firestore) está ativo. Ligue os dois ou nenhum.');
  process.exit(1);
}
if (!usingEmulator && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Defina GOOGLE_APPLICATION_CREDENTIALS com a chave da conta de serviço (veja o README).');
  process.exit(1);
}
const app = initializeApp(
  usingEmulator ? { projectId: args.project } : { credential: applicationDefault(), projectId: args.project },
);
const auth = getAuth(app);
const db = getFirestore(app);

async function demoUids() {
  const uids = new Set();
  let pageToken;
  do {
    const page = await auth.listUsers(1000, pageToken);
    for (const user of page.users) if (DEMO_EMAIL.test(user.email ?? '')) uids.add(user.uid);
    pageToken = page.pageToken;
  } while (pageToken);
  if (existsSync(args.state)) {
    const state = JSON.parse(readFileSync(args.state, 'utf8'));
    for (const account of Object.values(state.accounts ?? {})) if (account.uid) uids.add(account.uid);
  }
  return [...uids];
}

async function deleteAll(query) {
  const snapshot = await query.get();
  for (const doc of snapshot.docs) await db.recursiveDelete(doc.ref);
  return snapshot.size;
}

async function removeUser(uid) {
  const counts = {
    posts: await deleteAll(db.collection('posts').where('authorId', '==', uid)),
    stories: await deleteAll(db.collection('stories').where('authorId', '==', uid)),
    media: await deleteAll(db.collection('media').where('ownerId', '==', uid)),
    swipes:
      (await deleteAll(db.collection('swipes').where('from', '==', uid))) +
      (await deleteAll(db.collection('swipes').where('to', '==', uid))),
    matches: await deleteAll(db.collection('matches').where('users', 'array-contains', uid)),
  };
  // Curtidas dadas em posts de outras pessoas.
  const liked = await db.collection('posts').where('likedBy', 'array-contains', uid).get();
  for (const doc of liked.docs) await doc.ref.update({ likedBy: FieldValue.arrayRemove(uid) });
  counts.likes = liked.size;

  await db.recursiveDelete(db.doc(`presence/${uid}`));
  await db.recursiveDelete(db.doc(`telemetry/${uid}`));
  await db.recursiveDelete(db.doc(`users/${uid}`));
  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }
  return counts;
}

const uids = await demoUids();
if (uids.length === 0) {
  console.log('Nenhum perfil de demonstração encontrado.');
  process.exit(0);
}
for (const uid of uids) {
  const counts = await removeUser(uid);
  console.log(`  ${uid}: ${Object.entries(counts).map(([key, n]) => `${n} ${key}`).join(', ')}`);
}
if (existsSync(args.state)) rmSync(args.state);
console.log(`${uids.length} perfis de demonstração removidos.`);
