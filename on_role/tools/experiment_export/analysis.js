// Análise dos dados do experimento de campo do OnRolê (TCC). Funções puras,
// sem Firebase: recebem o conjunto já pseudonimizado (P01, P02...) e devolvem
// as métricas das hipóteses H1–H4. Testes em analysis.test.js.

const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;

/// Janela para casar uma marcação do diário com o evento do app.
export const DEFAULT_MATCH_WINDOW_MS = 10 * MINUTE;

/// Amostras de bateria mais distantes que isso não entram no consumo (o app
/// pode ter sido fechado no meio).
export const MAX_BATTERY_GAP_MS = 30 * MINUTE;

/// Depois disso, uma abertura do mapa sem escolher local é abandono.
export const MAX_SELECT_DELAY_MS = 10 * MINUTE;

// ---------------------------------------------------------------- utilidades

export function median(values) {
  return quantile(values, 0.5);
}

/// Quantil com interpolação linear (como o Excel/LibreOffice).
export function quantile(values, q) {
  if (values.length === 0) return null;
  const sorted = [...values].sort((a, b) => a - b);
  const position = (sorted.length - 1) * q;
  const lower = Math.floor(position);
  const upper = Math.ceil(position);
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
}

export function round(value, digits = 2) {
  if (value === null || value === undefined || Number.isNaN(value)) return null;
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

const ratio = (part, total) => (total === 0 ? null : part / total);

function groupBy(items, key) {
  const groups = new Map();
  for (const item of items) {
    const value = key(item);
    if (!groups.has(value)) groups.set(value, []);
    groups.get(value).push(item);
  }
  return groups;
}

/// Códigos P01, P02... na ordem de entrada no experimento (primeiro evento).
export function pseudonymize(firstSeenByUid) {
  const ordered = [...firstSeenByUid.entries()].sort((a, b) => a[1] - b[1] || a[0].localeCompare(b[0]));
  const width = Math.max(2, String(ordered.length).length);
  return new Map(ordered.map(([uid], index) => [uid, 'P' + String(index + 1).padStart(width, '0')]));
}

// ------------------------------------------------------------------- CSV

/// Data e hora de Colatina (UTC-3), no formato que as planilhas reconhecem.
export function localTime(ms) {
  if (ms === null || ms === undefined) return null;
  return new Date(ms).toLocaleString('sv-SE', { timeZone: 'America/Sao_Paulo' });
}

/// [excelBr]: ponto e vírgula entre colunas e vírgula decimal, como o Excel
/// em português espera.
export function toCsv(rows, columns, { excelBr = false } = {}) {
  const separator = excelBr ? ';' : ',';
  const needsQuotes = (text) => text.includes(separator) || /["\r\n]/.test(text);
  const escape = (value) => {
    if (value === null || value === undefined) return '';
    let text = typeof value === 'object' ? JSON.stringify(value) : String(value);
    if (excelBr && typeof value === 'number') text = text.replace('.', ',');
    return needsQuotes(text) ? '"' + text.replaceAll('"', '""') + '"' : text;
  };
  const header = columns.join(separator);
  const lines = rows.map((row) => columns.map((column) => escape(row[column])).join(separator));
  return [header, ...lines].join('\n') + '\n';
}

/// Eventos em linhas de planilha: uma coluna por campo que aparece.
export function eventRows(events) {
  const fixed = ['participant', 'time', 't', 'type'];
  const extra = new Set();
  for (const event of events) {
    for (const key of Object.keys(event)) if (!fixed.includes(key)) extra.add(key);
  }
  const columns = [...fixed, ...[...extra].sort()];
  const rows = [...events]
    .sort((a, b) => a.participant.localeCompare(b.participant) || a.t - b.t)
    .map((event) => ({ ...event, time: localTime(event.t) }));
  return { columns, rows };
}

// ------------------------------------------- H1: geocercas x diário de campo

/// Casa cada marcação do diário (chegada/saída) com o evento do app no mesmo
/// local mais próximo no tempo, dentro da janela. Cada evento do app só casa
/// uma vez. Eventos simulados ficam de fora.
function pairWithDiary(diary, appEvents, windowMs) {
  const used = new Set();
  const pairs = [];
  for (const mark of [...diary].sort((a, b) => a.t - b.t)) {
    let best = null;
    for (const event of appEvents) {
      if (used.has(event) || event.venueId !== mark.venueId) continue;
      const delta = event.t - mark.t;
      if (Math.abs(delta) > windowMs) continue;
      if (best === null || Math.abs(delta) < Math.abs(best.t - mark.t)) best = event;
    }
    if (best) used.add(best);
    pairs.push({ mark, event: best, latencyMs: best ? best.t - mark.t : null });
  }
  const unmatched = appEvents.filter((event) => !used.has(event));
  return { pairs, unmatched };
}

function transitionStats(pairs, unmatched) {
  const detected = pairs.filter((pair) => pair.event);
  const latencies = detected.map((pair) => pair.latencyMs / 1000);
  return {
    marked: pairs.length,
    detected: detected.length,
    detectionRate: round(ratio(detected.length, pairs.length), 4),
    unconfirmed: unmatched.length,
    medianLatencySec: round(median(latencies), 1),
    p90LatencySec: round(quantile(latencies, 0.9), 1),
  };
}

/// Acerto das transições de geocerca (meta do projeto: > 95%).
///  - chegada: diário "Cheguei" x check-in automático (após a permanência);
///  - entrada: diário "Cheguei" x primeira leitura dentro da cerca;
///  - saída: diário "Saí" x check-out automático.
/// Eventos do app sem marcação no diário contam como "não confirmados"
/// (podem ser falsos check-ins ou só uma marcação esquecida).
export function geofenceAccuracy(events, { windowMs = DEFAULT_MATCH_WINDOW_MS } = {}) {
  const real = events.filter((event) => event.simulated !== true);
  const perParticipant = [];
  const all = { arrival: { pairs: [], unmatched: [] }, enter: { pairs: [], unmatched: [] }, exit: { pairs: [], unmatched: [] } };

  for (const [participant, own] of groupBy(real, (event) => event.participant)) {
    const arrivals = own.filter((event) => event.type === 'ground_truth' && event.action === 'arrived');
    const departures = own.filter((event) => event.type === 'ground_truth' && event.action === 'left');
    // Sem diário, a pessoa não entra na conta de acerto.
    if (arrivals.length + departures.length === 0) continue;

    const checkIns = own.filter((event) => event.type === 'check_in');
    const enters = own.filter((event) => event.type === 'geofence' && event.transition === 'enter');
    const checkOuts = own.filter((event) => event.type === 'check_out');

    const arrival = pairWithDiary(arrivals, checkIns, windowMs);
    const enter = pairWithDiary(arrivals, enters, windowMs);
    const exit = pairWithDiary(departures, checkOuts, windowMs);
    for (const [name, result] of Object.entries({ arrival, enter, exit })) {
      all[name].pairs.push(...result.pairs);
      all[name].unmatched.push(...result.unmatched);
    }
    perParticipant.push({
      participant,
      arrival: transitionStats(arrival.pairs, arrival.unmatched),
      enter: transitionStats(enter.pairs, enter.unmatched),
      exit: transitionStats(exit.pairs, exit.unmatched),
    });
  }

  const marked = all.arrival.pairs.length + all.exit.pairs.length;
  const detected = all.arrival.pairs.filter((p) => p.event).length + all.exit.pairs.filter((p) => p.event).length;
  return {
    windowMinutes: windowMs / MINUTE,
    // Check-ins e check-outs confirmados sobre todas as marcações do diário.
    transitionAccuracy: round(ratio(detected, marked), 4),
    arrival: transitionStats(all.arrival.pairs, all.arrival.unmatched),
    enter: transitionStats(all.enter.pairs, all.enter.unmatched),
    exit: transitionStats(all.exit.pairs, all.exit.unmatched),
    perParticipant,
  };
}

/// Qualidade das leituras de GPS (agregadas pelo app a cada envio).
export function gpsQuality(events) {
  const result = [];
  for (const [participant, own] of groupBy(events.filter((e) => e.type === 'gps'), (e) => e.participant)) {
    const fixes = own.reduce((sum, e) => sum + e.fixes, 0);
    const rejected = own.reduce((sum, e) => sum + e.rejected, 0);
    const accuracy = own.reduce((sum, e) => sum + e.avgAccuracy * e.fixes, 0);
    result.push({
      participant,
      fixes,
      rejectedRate: round(ratio(rejected, fixes), 4),
      avgAccuracyMeters: round(ratio(accuracy, fixes), 1),
    });
  }
  return result.sort((a, b) => a.participant.localeCompare(b.participant));
}

// ---------------------------------------------- H4: bateria e desempenho

/// Consumo de bateria em %/h, separado por app em primeiro plano ou não.
/// Só conta intervalos entre duas amostras descarregando (fora da tomada).
export function batteryDrain(events, { maxGapMs = MAX_BATTERY_GAP_MS } = {}) {
  const buckets = new Map();
  const add = (participant, bucket, drop, ms) => {
    const key = participant + '|' + bucket;
    const current = buckets.get(key) ?? { participant, appState: bucket, drop: 0, ms: 0, intervals: 0 };
    current.drop += drop;
    current.ms += ms;
    current.intervals += 1;
    buckets.set(key, current);
  };

  const samples = events.filter((event) => event.type === 'battery');
  for (const [participant, own] of groupBy(samples, (event) => event.participant)) {
    const sorted = [...own].sort((a, b) => a.t - b.t);
    for (let i = 1; i < sorted.length; i++) {
      const before = sorted[i - 1];
      const after = sorted[i];
      const ms = after.t - before.t;
      if (ms <= 0 || ms > maxGapMs) continue;
      if (before.state !== 'discharging' || after.state !== 'discharging') continue;
      const drop = before.level - after.level;
      if (drop < 0) continue; // carregou no meio
      const bucket = before.appState === 'resumed' ? 'foreground' : 'background';
      add(participant, bucket, drop, ms);
      add('TODOS', bucket, drop, ms);
    }
  }

  return [...buckets.values()]
    .map((bucket) => ({
      participant: bucket.participant,
      appState: bucket.appState,
      hours: round(bucket.ms / HOUR, 2),
      intervals: bucket.intervals,
      percentPerHour: round(bucket.drop / (bucket.ms / HOUR), 2),
    }))
    .sort((a, b) => a.participant.localeCompare(b.participant) || a.appState.localeCompare(b.appState));
}

/// Desempenho do mapa de calor por aparelho: janelas de 30 s resumidas pelo
/// app, combinadas pelo número de quadros de cada janela.
export function frameSummary(events) {
  const devices = new Map();
  for (const event of events) {
    if (event.type === 'session' && event.model) devices.set(event.participant, event);
  }
  const result = [];
  const frames = events.filter((event) => event.type === 'frames');
  for (const [key, own] of groupBy(frames, (event) => event.participant + '|' + (event.screen ?? '?'))) {
    const [participant, screen] = key.split('|');
    const total = own.reduce((sum, e) => sum + e.frames, 0);
    const weighted = (field) => round(own.reduce((sum, e) => sum + e[field] * e.frames, 0) / total, 2);
    const device = devices.get(participant);
    result.push({
      participant,
      screen,
      device: device ? [device.model, device.os].filter(Boolean).join(' / ') : null,
      windows: own.length,
      frames: total,
      avgBuildMs: weighted('avgBuildMs'),
      avgRasterMs: weighted('avgRasterMs'),
      medianP90FrameMs: round(median(own.map((e) => e.p90FrameMs)), 2),
      jankRatio: weighted('jankRatio'),
      // Quadros dentro do orçamento de 60 FPS (16,7 ms).
      smoothFramesRate: round(1 - weighted('jankRatio'), 4),
    });
  }
  return result.sort((a, b) => a.participant.localeCompare(b.participant));
}

// ----------------------------------------------------- H2: tempo no mapa

/// Do abrir o mapa até escolher o primeiro local (pino, busca ou cartão).
export function mapTiming(events, { maxDelayMs = MAX_SELECT_DELAY_MS } = {}) {
  const delays = [];
  let opens = 0;
  let abandoned = 0;
  const bySource = new Map();
  const relevant = events.filter((event) => event.type === 'map_open' || event.type === 'venue_select');
  for (const own of groupBy(relevant, (event) => event.participant).values()) {
    const sorted = [...own].sort((a, b) => a.t - b.t);
    let openedAt = null;
    for (const event of sorted) {
      if (event.type === 'map_open') {
        if (openedAt !== null) abandoned++;
        opens++;
        openedAt = event.t;
      } else if (openedAt !== null) {
        const delay = event.t - openedAt;
        if (delay <= maxDelayMs) {
          delays.push(delay / 1000);
          bySource.set(event.source, (bySource.get(event.source) ?? 0) + 1);
        } else {
          abandoned++;
        }
        openedAt = null;
      }
    }
    if (openedAt !== null) abandoned++;
  }
  return {
    opens,
    selections: delays.length,
    abandoned,
    medianSeconds: round(median(delays), 1),
    p90Seconds: round(quantile(delays, 0.9), 1),
    bySource: Object.fromEntries(bySource),
  };
}

// ------------------------------------------------- H3: match geossocial

/// Compara as sugestões por afinidade com as sorteadas (controle): taxa de
/// curtidas e reciprocidade (a outra pessoa também curtiu). A exportação
/// grava `reciprocated` em cada curtida, porque a curtida de volta pode vir de
/// alguém fora do experimento (que não entra no conjunto de dados).
export function swipeSummary(swipes, { matches } = {}) {
  const likes = new Set(swipes.filter((s) => s.decision === 'like').map((s) => s.from + '>' + s.to));
  const isReciprocal = (s) => s.reciprocated ?? likes.has(s.to + '>' + s.from);
  const result = {};
  for (const source of ['afinidade', 'controle']) {
    const own = swipes.filter((s) => s.source === source);
    const liked = own.filter((s) => s.decision === 'like');
    const reciprocal = liked.filter(isReciprocal);
    result[source] = {
      shown: own.length,
      likes: liked.length,
      likeRate: round(ratio(liked.length, own.length), 4),
      reciprocal: reciprocal.length,
      // Das curtidas dadas a essas sugestões, quantas foram correspondidas.
      reciprocityRate: round(ratio(reciprocal.length, liked.length), 4),
      avgScore: round(ratio(own.reduce((sum, s) => sum + s.score, 0), own.length), 3),
    };
  }
  const pairs = new Set();
  for (const swipe of swipes) {
    if (swipe.decision === 'like' && isReciprocal(swipe)) pairs.add([swipe.from, swipe.to].sort().join('_'));
  }
  result.matches = matches ?? pairs.size;
  return result;
}

// ------------------------------------------------------------- relatório

export function analyze(dataset, options = {}) {
  const events = dataset.events;
  return {
    participants: new Set(events.map((event) => event.participant)).size,
    events: events.length,
    period: events.length === 0
      ? null
      : {
          from: localTime(Math.min(...events.map((e) => e.t))),
          to: localTime(Math.max(...events.map((e) => e.t))),
        },
    h1_geofence: geofenceAccuracy(events, options),
    h1_gps: gpsQuality(events),
    h2_map: mapTiming(events, options),
    h3_swipes: swipeSummary(dataset.swipes ?? [], { matches: dataset.matches }),
    h4_battery: batteryDrain(events, options),
    h4_frames: frameSummary(events),
  };
}

const percent = (value) => (value === null || value === undefined ? '—' : round(value * 100, 1) + '%');
const show = (value) => (value === null || value === undefined ? '—' : String(value));

function table(columns, rows) {
  const header = '| ' + columns.map(([title]) => title).join(' | ') + ' |';
  const divider = '|' + columns.map(() => ' --- |').join('');
  const lines = rows.map((row) => '| ' + columns.map(([, cell]) => cell(row)).join(' | ') + ' |');
  return [header, divider, ...lines].join('\n');
}

/// Resumo em Markdown para colar no capítulo de resultados.
export function summaryMarkdown(summary) {
  const g = summary.h1_geofence;
  const transitions = [
    ['Chegada → check-in', g.arrival],
    ['Chegada → entrada na cerca', g.enter],
    ['Saída → check-out', g.exit],
  ];
  const s = summary.h3_swipes;
  return [
    '# Experimento de campo — OnRolê',
    '',
    `Participantes: ${summary.participants} · eventos: ${summary.events}` +
      (summary.period ? ` · de ${summary.period.from} a ${summary.period.to}` : ''),
    '',
    '## H1 — Geocercas x diário de campo',
    '',
    `Acerto das transições (check-in e check-out confirmados pelo diário): **${percent(g.transitionAccuracy)}** ` +
      `(janela de ${g.windowMinutes} min).`,
    '',
    table(
      [
        ['Transição', (row) => row[0]],
        ['Marcações', (row) => show(row[1].marked)],
        ['Detectadas', (row) => show(row[1].detected)],
        ['Taxa', (row) => percent(row[1].detectionRate)],
        ['Latência mediana (s)', (row) => show(row[1].medianLatencySec)],
        ['Latência p90 (s)', (row) => show(row[1].p90LatencySec)],
        ['Sem marcação no diário', (row) => show(row[1].unconfirmed)],
      ],
      transitions,
    ),
    '',
    table(
      [
        ['Participante', (row) => row.participant],
        ['Leituras de GPS', (row) => show(row.fixes)],
        ['Precisão média (m)', (row) => show(row.avgAccuracyMeters)],
        ['Descartadas', (row) => percent(row.rejectedRate)],
      ],
      summary.h1_gps,
    ),
    '',
    '## H2 — Do mapa ao local',
    '',
    `Aberturas do mapa: ${summary.h2_map.opens} · locais escolhidos: ${summary.h2_map.selections} · ` +
      `sem escolha: ${summary.h2_map.abandoned}. Tempo mediano: ${show(summary.h2_map.medianSeconds)} s ` +
      `(p90 ${show(summary.h2_map.p90Seconds)} s).`,
    '',
    '## H3 — Match geossocial',
    '',
    table(
      [
        ['Sugestão', (row) => row[0]],
        ['Mostradas', (row) => show(row[1].shown)],
        ['Curtidas', (row) => `${row[1].likes} (${percent(row[1].likeRate)})`],
        ['Correspondidas', (row) => `${row[1].reciprocal} (${percent(row[1].reciprocityRate)})`],
        ['Afinidade média', (row) => show(row[1].avgScore)],
      ],
      [
        ['Por afinidade', s.afinidade],
        ['Sorteada (controle)', s.controle],
      ],
    ),
    '',
    `Matches: ${s.matches}.`,
    '',
    '## H4 — Bateria e desempenho',
    '',
    table(
      [
        ['Participante', (row) => row.participant],
        ['App', (row) => (row.appState === 'foreground' ? 'aberto' : 'em segundo plano')],
        ['Horas medidas', (row) => show(row.hours)],
        ['Consumo (%/h)', (row) => show(row.percentPerHour)],
      ],
      summary.h4_battery,
    ),
    '',
    table(
      [
        ['Participante', (row) => row.participant],
        ['Aparelho', (row) => show(row.device)],
        ['Quadros', (row) => show(row.frames)],
        ['Construção (ms)', (row) => show(row.avgBuildMs)],
        ['Rasterização (ms)', (row) => show(row.avgRasterMs)],
        ['p90 (ms)', (row) => show(row.medianP90FrameMs)],
        ['Quadros a 60 FPS', (row) => percent(row.smoothFramesRate)],
      ],
      summary.h4_frames,
    ),
    '',
  ].join('\n');
}
