#!/usr/bin/env node
// Exporta os dados do experimento de campo do Firestore para planilhas (CSV)
// e um resumo das métricas do TCC. Veja README.md nesta pasta.
//
//   node export.js                         baixa o que é novo e gera out/
//   node export.js --since 2026-10-20      ignora dados de antes (ex.: piloto)
//   node export.js --window 15             janela do diário, em minutos
//   node export.js --dataset out/dataset.json   só refaz a análise, offline
//   node export.js --excel-br              CSV com ; e vírgula decimal (Excel)

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { parseArgs } from 'node:util';

import { analyze, eventRows, localTime, summaryMarkdown, toCsv as toCsvWith } from './analysis.js';
import { buildDataset } from './dataset.js';

const { values: args } = parseArgs({
  options: {
    since: { type: 'string' },
    window: { type: 'string' },
    dataset: { type: 'string' },
    out: { type: 'string', default: 'out' },
    'excel-br': { type: 'boolean', default: false },
    project: { type: 'string', default: process.env.FIREBASE_PROJECT ?? 'onrole-tcc' },
  },
});

const outDir = args.out;
const toCsv = (rows, columns) => toCsvWith(rows, columns, { excelBr: args['excel-br'] });
// O cache guarda os ids do Firebase: fica só nesta máquina (out/ está no
// .gitignore) e nunca vai para o TCC.
const cachePath = join(outDir, '.cache', 'raw.json');

function readJson(path, fallback) {
  return existsSync(path) ? JSON.parse(readFileSync(path, 'utf8')) : fallback;
}

function writeFile(path, content) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content);
}

/// Lê do Firestore só os lotes novos de cada participante. Cada lote lido é
/// uma leitura na cota gratuita (50 mil por dia), então o que já veio fica em
/// cache. Se o número de lotes no servidor cair (a pessoa apagou os dados),
/// o cache dela é refeito; se ela saiu do experimento, é descartado.
async function fetchRaw(projectId) {
  const { applicationDefault, initializeApp } = await import('firebase-admin/app');
  const { getFirestore, Timestamp } = await import('firebase-admin/firestore');

  const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  if (!usingEmulator && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error(
      'Defina GOOGLE_APPLICATION_CREDENTIALS com o caminho da chave da conta de serviço (veja o README).',
    );
  }
  const app = initializeApp(usingEmulator ? { projectId } : { credential: applicationDefault(), projectId });
  const db = getFirestore(app);

  const cache = readJson(cachePath, { users: {} });
  let reads = 0;

  const telemetryUsers = await db.collection('telemetry').listDocuments();
  reads += telemetryUsers.length;
  const seen = new Set();
  for (const userRef of telemetryUsers) {
    const uid = userRef.id;
    seen.add(uid);
    const consent = await db.doc(`users/${uid}/private/experiment`).get();
    reads += 1;
    if (consent.data()?.enrolled !== true) {
      delete cache.users[uid];
      continue;
    }

    const batches = userRef.collection('batches');
    let entry = cache.users[uid] ?? { lastCreatedAtMs: null, batches: {} };
    const remoteCount = (await batches.count().get()).data().count;
    reads += 1;
    if (remoteCount < Object.keys(entry.batches).length) {
      entry = { lastCreatedAtMs: null, batches: {} };
    }

    const query =
      entry.lastCreatedAtMs === null
        ? batches
        : batches.where('createdAt', '>=', Timestamp.fromMillis(entry.lastCreatedAtMs)).orderBy('createdAt');
    const snapshot = await query.get();
    reads += Math.max(1, snapshot.size);
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const createdAtMs = data.createdAt?.toMillis?.() ?? null;
      entry.batches[doc.id] = { createdAtMs, events: data.events ?? [] };
      if (createdAtMs !== null && (entry.lastCreatedAtMs === null || createdAtMs > entry.lastCreatedAtMs)) {
        entry.lastCreatedAtMs = createdAtMs;
      }
    }
    entry.enrolled = true;
    cache.users[uid] = entry;
  }
  for (const uid of Object.keys(cache.users)) {
    if (!seen.has(uid)) delete cache.users[uid];
  }

  const swipesSnapshot = await db.collection('swipes').get();
  const matchesSnapshot = await db.collection('matches').get();
  reads += swipesSnapshot.size + matchesSnapshot.size;

  writeFile(cachePath, JSON.stringify(cache));
  console.log(`Firestore: ~${reads} leituras nesta exportação.`);

  return {
    users: Object.fromEntries(
      Object.entries(cache.users).map(([uid, entry]) => [
        uid,
        { enrolled: entry.enrolled, batches: Object.entries(entry.batches).map(([id, batch]) => ({ id, ...batch })) },
      ]),
    ),
    swipes: swipesSnapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        from: data.from,
        to: data.to,
        decision: data.decision,
        source: data.source,
        score: data.score,
        createdAtMs: data.createdAt?.toMillis?.() ?? null,
      };
    }),
    matches: matchesSnapshot.docs.map((doc) => ({ users: doc.data().users ?? [] })),
  };
}

async function main() {
  const options = {};
  if (args.window) options.windowMs = Number(args.window) * 60 * 1000;

  let dataset;
  if (args.dataset) {
    dataset = readJson(args.dataset, null);
    if (!dataset) throw new Error(`Arquivo não encontrado: ${args.dataset}`);
  } else {
    const since = args.since ? new Date(args.since + 'T00:00:00-03:00') : null;
    if (since && Number.isNaN(since.getTime())) throw new Error('Use --since AAAA-MM-DD.');
    dataset = buildDataset(await fetchRaw(args.project), { since });
    writeFile(join(outDir, 'dataset.json'), JSON.stringify(dataset, null, 1));
  }

  const summary = analyze(dataset, options);
  const { columns, rows } = eventRows(dataset.events);
  writeFile(join(outDir, 'events.csv'), toCsv(rows, columns));
  writeFile(
    join(outDir, 'swipes.csv'),
    toCsv(
      dataset.swipes.map((s) => ({ ...s, time: localTime(s.t) })),
      ['from', 'to', 'decision', 'source', 'score', 'reciprocated', 'time'],
    ),
  );
  writeFile(
    join(outDir, 'participants.csv'),
    toCsv(dataset.participants, ['code', 'firstEvent', 'lastEvent', 'events', 'platform', 'model', 'os']),
  );
  writeFile(
    join(outDir, 'battery.csv'),
    toCsv(summary.h4_battery, ['participant', 'appState', 'hours', 'intervals', 'percentPerHour']),
  );
  writeFile(
    join(outDir, 'frames.csv'),
    toCsv(summary.h4_frames, [
      'participant',
      'screen',
      'device',
      'windows',
      'frames',
      'avgBuildMs',
      'avgRasterMs',
      'medianP90FrameMs',
      'jankRatio',
      'smoothFramesRate',
    ]),
  );
  writeFile(
    join(outDir, 'geofence.csv'),
    toCsv(
      summary.h1_geofence.perParticipant.flatMap((row) =>
        ['arrival', 'enter', 'exit'].map((transition) => ({
          participant: row.participant,
          transition,
          ...row[transition],
        })),
      ),
      ['participant', 'transition', 'marked', 'detected', 'detectionRate', 'unconfirmed', 'medianLatencySec', 'p90LatencySec'],
    ),
  );
  writeFile(join(outDir, 'summary.json'), JSON.stringify(summary, null, 2));
  writeFile(join(outDir, 'summary.md'), summaryMarkdown(summary));

  console.log(
    `${summary.participants} participantes, ${summary.events} eventos, ${dataset.swipes.length} decisões de match.`,
  );
  console.log(`Acerto das geocercas: ${summary.h1_geofence.transitionAccuracy ?? '—'} · arquivos em ${outDir}/`);
}

main().catch((error) => {
  console.error(error.message ?? error);
  process.exitCode = 1;
});
