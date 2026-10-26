#!/usr/bin/env node
// Descarta do Firestore os dados da antiga coleta de campo: os lotes de
// telemetria (com o diário de campo, que tem horários e locais reais) e o
// consentimento de cada conta. Com --checkins, apaga também o histórico de
// check-ins, a presença e a contagem de visitas de todas as contas, que são
// localização real de quem testou o app completo.
//
//   node purge.js                     só conta o que seria apagado
//   node purge.js --apply             apaga a telemetria e os consentimentos
//   node purge.js --apply --checkins  apaga também check-ins, presença e visitas
//
// Usa o Admin SDK, porque as regras não deixam mais ninguém ler a telemetria.

import { parseArgs } from 'node:util';

import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const { values: args } = parseArgs({
  options: {
    apply: { type: 'boolean', default: false },
    checkins: { type: 'boolean', default: false },
    project: { type: 'string', default: process.env.GCLOUD_PROJECT ?? 'onrole-tcc' },
  },
});

const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
if (!usingEmulator && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Defina GOOGLE_APPLICATION_CREDENTIALS com a chave da conta de serviço (veja o README).');
  process.exit(1);
}
const app = initializeApp(
  usingEmulator ? { projectId: args.project } : { credential: applicationDefault(), projectId: args.project },
);
const db = getFirestore(app);

const count = async (query) => (await query.count().get()).data().count;

// listDocuments também acha documentos "fantasmas": pais sem campos, que só
// existem porque têm subcoleções (é o caso de telemetry/{uid}).
const participants = await db.collection('telemetry').listDocuments();
let batches = 0;
for (const ref of participants) batches += await count(ref.collection('batches'));

const users = await db.collection('users').listDocuments();
const consents = [];
for (const ref of users) {
  const consent = ref.collection('private').doc('experiment');
  if ((await consent.get()).exists) consents.push(consent);
}

console.log(`Projeto: ${args.project}${usingEmulator ? ' (emulador)' : ''}`);
console.log(`Telemetria: ${batches} lotes de ${participants.length} contas.`);
console.log(`Consentimentos do experimento: ${consents.length}.`);

let checkins = 0;
let presence = 0;
let withVisits = [];
if (args.checkins) {
  checkins = await count(db.collectionGroup('checkins'));
  presence = await count(db.collection('presence'));
  withVisits = (await db.collection('users').get()).docs.filter(
    (doc) => Object.keys(doc.get('visits') ?? {}).length > 0,
  );
  console.log(`Check-ins: ${checkins}. Presenças: ${presence}. Contas com visitas: ${withVisits.length}.`);
}

if (!args.apply) {
  console.log('\nNada foi apagado. Rode de novo com --apply para apagar.');
  process.exit(0);
}

for (const ref of participants) await db.recursiveDelete(ref);
for (const ref of consents) await ref.delete();
if (args.checkins) {
  await db.recursiveDelete(db.collection('presence'));
  for (const ref of users) await db.recursiveDelete(ref.collection('checkins'));
  for (const doc of withVisits) await doc.ref.update({ visits: {} });
}

// Confere que não sobrou nada.
let left = 0;
for (const ref of await db.collection('telemetry').listDocuments()) left += await count(ref.collection('batches'));
if (args.checkins) left += await count(db.collectionGroup('checkins'));
console.log(left === 0 ? '\nPronto: nada sobrou.' : `\nAtenção: ainda há ${left} documentos. Rode de novo.`);
