import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  analyze,
  batteryDrain,
  eventRows,
  frameSummary,
  geofenceAccuracy,
  gpsQuality,
  localTime,
  mapTiming,
  pseudonymize,
  quantile,
  summaryMarkdown,
  swipeSummary,
  toCsv,
} from './analysis.js';
import { buildDataset } from './dataset.js';

const MIN = 60 * 1000;
const T0 = Date.UTC(2026, 9, 24, 22, 0); // sábado, 19h em Colatina

const at = (minutes) => T0 + minutes * MIN;
const ev = (participant, minutes, type, data = {}) => ({ participant, t: at(minutes), type, ...data });

describe('utilidades', () => {
  test('quantil com interpolação, como nas planilhas', () => {
    assert.equal(quantile([1, 2, 3, 4], 0.5), 2.5);
    assert.equal(quantile([10], 0.9), 10);
    assert.equal(quantile([], 0.5), null);
  });

  test('códigos na ordem de entrada no experimento', () => {
    const codes = pseudonymize(new Map([['uid-b', 20], ['uid-a', 10], ['uid-c', 30]]));
    assert.deepEqual([...codes], [['uid-a', 'P01'], ['uid-b', 'P02'], ['uid-c', 'P03']]);
  });

  test('CSV escapa vírgulas, aspas e quebras de linha', () => {
    const csv = toCsv([{ a: 'x,y', b: 'diz "oi"', c: null }], ['a', 'b', 'c']);
    assert.equal(csv, 'a,b,c\n"x,y","diz ""oi""",\n');
  });

  test('CSV para o Excel em português', () => {
    const csv = toCsv([{ a: 12.5, b: 'texto' }], ['a', 'b'], { excelBr: true });
    assert.equal(csv, 'a;b\n12,5;texto\n');
  });

  test('horário de Colatina (UTC-3)', () => {
    assert.equal(localTime(T0), '2026-10-24 19:00:00');
  });

  test('eventos viram linhas com uma coluna por campo', () => {
    const { columns, rows } = eventRows([ev('P02', 1, 'battery', { level: 80 }), ev('P01', 2, 'check_in', { venueId: 'v1' })]);
    assert.deepEqual(columns, ['participant', 'time', 't', 'type', 'level', 'venueId']);
    assert.equal(rows[0].participant, 'P01');
    assert.equal(rows[0].time, '2026-10-24 19:02:00');
  });
});

describe('H1: geocercas x diário', () => {
  const events = [
    // P01 chega ao boteco; o app faz check-in 2,5 min depois (permanência).
    ev('P01', 0, 'ground_truth', { action: 'arrived', venueId: 'boteco' }),
    ev('P01', 0.5, 'geofence', { transition: 'enter', venueId: 'boteco' }),
    ev('P01', 2.5, 'check_in', { venueId: 'boteco' }),
    // Sai 1 h depois; o check-out vem 1,5 min depois.
    ev('P01', 60, 'ground_truth', { action: 'left', venueId: 'boteco' }),
    ev('P01', 61.5, 'check_out', { venueId: 'boteco' }),
    // Chegada na praça que o app não detectou.
    ev('P01', 90, 'ground_truth', { action: 'arrived', venueId: 'praca' }),
    // Check-in sem marcação no diário.
    ev('P01', 200, 'check_in', { venueId: 'lounge' }),
    // Simulado não conta.
    ev('P01', 300, 'check_in', { venueId: 'praca', simulated: true }),
    // P02 não usou o diário: fica fora da conta.
    ev('P02', 5, 'check_in', { venueId: 'boteco' }),
  ];

  test('casa o diário com check-in, entrada e check-out', () => {
    const result = geofenceAccuracy(events);
    assert.equal(result.perParticipant.length, 1);
    assert.deepEqual(
      {
        marked: result.arrival.marked,
        detected: result.arrival.detected,
        unconfirmed: result.arrival.unconfirmed,
        latency: result.arrival.medianLatencySec,
      },
      { marked: 2, detected: 1, unconfirmed: 1, latency: 150 },
    );
    assert.equal(result.enter.medianLatencySec, 30);
    assert.equal(result.exit.detectionRate, 1);
    assert.equal(result.exit.medianLatencySec, 90);
    // 2 de 3 marcações (2 chegadas + 1 saída) confirmadas.
    assert.equal(result.transitionAccuracy, 0.6667);
  });

  test('evento fora da janela não casa', () => {
    const late = [
      ev('P01', 0, 'ground_truth', { action: 'arrived', venueId: 'boteco' }),
      ev('P01', 12, 'check_in', { venueId: 'boteco' }),
    ];
    assert.equal(geofenceAccuracy(late).arrival.detected, 0);
    assert.equal(geofenceAccuracy(late, { windowMs: 15 * MIN }).arrival.detected, 1);
  });

  test('cada check-in casa com uma marcação só', () => {
    const twice = [
      ev('P01', 0, 'ground_truth', { action: 'arrived', venueId: 'boteco' }),
      ev('P01', 1, 'ground_truth', { action: 'arrived', venueId: 'boteco' }),
      ev('P01', 2, 'check_in', { venueId: 'boteco' }),
    ];
    const result = geofenceAccuracy(twice);
    assert.equal(result.arrival.marked, 2);
    assert.equal(result.arrival.detected, 1);
  });

  test('qualidade do GPS pondera a precisão pelo número de leituras', () => {
    const gps = gpsQuality([
      ev('P01', 1, 'gps', { fixes: 10, rejected: 1, avgAccuracy: 10 }),
      ev('P01', 6, 'gps', { fixes: 30, rejected: 1, avgAccuracy: 20 }),
    ]);
    assert.deepEqual(gps, [{ participant: 'P01', fixes: 40, rejectedRate: 0.05, avgAccuracyMeters: 17.5 }]);
  });
});

describe('H2: do mapa ao local', () => {
  test('mede até a primeira escolha e conta abandonos', () => {
    const result = mapTiming([
      ev('P01', 0, 'map_open'),
      ev('P01', 0.25, 'venue_select', { source: 'pin' }),
      ev('P01', 0.5, 'venue_select', { source: 'card' }), // segunda escolha: não conta
      ev('P01', 10, 'map_open'), // abandonada
      ev('P01', 20, 'map_open'),
      ev('P01', 20.75, 'venue_select', { source: 'search' }),
      ev('P02', 0, 'map_open'),
      ev('P02', 30, 'venue_select', { source: 'pin' }), // depois de 10 min: abandono
    ]);
    assert.equal(result.opens, 4);
    assert.equal(result.selections, 2);
    assert.equal(result.abandoned, 2);
    assert.equal(result.medianSeconds, 30);
    assert.deepEqual(result.bySource, { pin: 1, search: 1 });
  });
});

describe('H3: match geossocial', () => {
  const swipe = (from, to, decision, source, score = 0.5) => ({ from, to, decision, source, score });

  test('compara curtidas e reciprocidade por fonte', () => {
    const result = swipeSummary([
      swipe('P01', 'P02', 'like', 'afinidade', 0.8),
      swipe('P02', 'P01', 'like', 'afinidade', 0.8),
      swipe('P01', 'P03', 'like', 'controle', 0.1),
      swipe('P03', 'P01', 'pass', 'controle', 0.1),
      swipe('P02', 'P03', 'pass', 'controle', 0.2),
    ]);
    assert.deepEqual(result.afinidade, {
      shown: 2,
      likes: 2,
      likeRate: 1,
      reciprocal: 2,
      reciprocityRate: 1,
      avgScore: 0.8,
    });
    assert.equal(result.controle.likeRate, 0.3333);
    assert.equal(result.controle.reciprocityRate, 0);
    assert.equal(result.matches, 1);
  });

  test('usa a reciprocidade calculada na exportação quando existe', () => {
    const result = swipeSummary([{ ...swipe('P01', 'N01', 'like', 'controle'), reciprocated: true }]);
    assert.equal(result.controle.reciprocal, 1);
    assert.equal(result.matches, 1);
  });
});

describe('H4: bateria e quadros', () => {
  test('consumo por hora separado por app aberto ou em segundo plano', () => {
    const battery = (minutes, level, appState, state = 'discharging') =>
      ev('P01', minutes, 'battery', { level, state, appState });
    const result = batteryDrain([
      battery(0, 90, 'resumed'),
      battery(5, 89, 'resumed'),
      battery(10, 88, 'paused'),
      battery(25, 87, 'paused'),
      battery(30, 87, 'paused', 'charging'), // na tomada: fora
      battery(35, 95, 'paused'),
      battery(120, 80, 'paused'), // intervalo longo demais: fora
    ]);
    const p01 = result.filter((row) => row.participant === 'P01');
    assert.deepEqual(
      p01.map((row) => [row.appState, row.hours, row.percentPerHour]),
      [
        ['background', 0.25, 4],
        ['foreground', 0.17, 12],
      ],
    );
    assert.ok(result.some((row) => row.participant === 'TODOS'));
  });

  test('quadros combinados pelo número de quadros de cada janela', () => {
    const result = frameSummary([
      ev('P01', 0, 'session', { model: 'motorola g54', os: 'Android 14' }),
      ev('P01', 1, 'frames', { screen: 'map', frames: 300, avgBuildMs: 4, avgRasterMs: 6, p90FrameMs: 9, jankRatio: 0 }),
      ev('P01', 2, 'frames', { screen: 'map', frames: 100, avgBuildMs: 8, avgRasterMs: 10, p90FrameMs: 20, jankRatio: 0.2 }),
    ]);
    assert.deepEqual(result, [
      {
        participant: 'P01',
        screen: 'map',
        device: 'motorola g54 / Android 14',
        windows: 2,
        frames: 400,
        avgBuildMs: 5,
        avgRasterMs: 7,
        medianP90FrameMs: 14.5,
        jankRatio: 0.05,
        smoothFramesRate: 0.95,
      },
    ]);
  });
});

describe('conjunto de dados', () => {
  const raw = {
    users: {
      'uid-ana': {
        enrolled: true,
        batches: [{ id: 'b1', events: [{ t: at(5), type: 'session', model: 'Moto' }, { t: at(6), type: 'check_in', venueId: 'v' }] }],
      },
      'uid-bia': { enrolled: true, batches: [{ id: 'b2', events: [{ t: at(1), type: 'session' }] }] },
      'uid-saiu': { enrolled: false, batches: [{ id: 'b3', events: [{ t: at(0), type: 'session' }] }] },
    },
    swipes: [
      { from: 'uid-ana', to: 'uid-fora', decision: 'like', source: 'afinidade', score: 0.4, createdAtMs: at(10) },
      { from: 'uid-fora', to: 'uid-ana', decision: 'like', source: 'controle', score: 0.4, createdAtMs: at(11) },
      { from: 'uid-bia', to: 'uid-ana', decision: 'pass', source: 'controle', score: 0.1, createdAtMs: at(12) },
    ],
    matches: [{ users: ['uid-ana', 'uid-fora'] }],
  };

  test('só quem consentiu, sem ids do Firebase', () => {
    const dataset = buildDataset(raw);
    const text = JSON.stringify(dataset);
    assert.ok(!text.includes('uid-'));
    assert.deepEqual(dataset.participants.map((p) => p.code), ['P01', 'P02']);
    // Bia entrou antes (primeiro evento), então é P01.
    assert.equal(dataset.participants[1].model, 'Moto');
    assert.equal(dataset.events.length, 3);
  });

  test('decisões de quem está fora ficam de fora, mas contam na reciprocidade', () => {
    const dataset = buildDataset(raw);
    assert.deepEqual(
      dataset.swipes.map((s) => [s.from, s.to, s.decision, s.reciprocated]),
      [
        ['P02', 'N01', 'like', true],
        ['P01', 'P02', 'pass', null],
      ],
    );
    assert.equal(dataset.matches, 1);
  });

  test('--since descarta o que veio antes (ex.: piloto)', () => {
    const dataset = buildDataset(raw, { since: new Date(at(3)) });
    assert.deepEqual(dataset.participants.map((p) => p.code), ['P01']);
    assert.equal(dataset.events.length, 2);
  });

  test('o resumo sai com todas as hipóteses, mesmo com poucos dados', () => {
    const summary = analyze(buildDataset(raw));
    assert.equal(summary.participants, 2);
    const markdown = summaryMarkdown(summary);
    for (const heading of ['H1', 'H2', 'H3', 'H4']) assert.ok(markdown.includes('## ' + heading));
  });
});
