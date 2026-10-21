// Do que veio do Firestore ao conjunto de dados do TCC: só quem consentiu,
// sem ids do Firebase (P01, P02... para participantes; N01, N02... para
// pessoas fora do experimento que aparecem nas curtidas).

import { pseudonymize } from './analysis.js';

/// raw = {
///   users:   { [uid]: { enrolled: bool, batches: [{ id, events: [...] }] } },
///   swipes:  [{ from, to, decision, source, score, createdAtMs }],
///   matches: [{ users: [a, b] }],
/// }
export function buildDataset(raw, { since = null, exportedAt = new Date() } = {}) {
  const sinceMs = since === null ? -Infinity : since.getTime();

  const eventsByUid = new Map();
  for (const [uid, user] of Object.entries(raw.users ?? {})) {
    // Quem saiu do experimento não entra, mesmo que algo tenha sobrado.
    if (user.enrolled !== true) continue;
    const events = (user.batches ?? [])
      .flatMap((batch) => batch.events ?? [])
      .filter((event) => typeof event.t === 'number' && event.t >= sinceMs);
    if (events.length > 0) eventsByUid.set(uid, events);
  }

  const codes = pseudonymize(new Map([...eventsByUid].map(([uid, events]) => [uid, Math.min(...events.map((e) => e.t))])));

  const events = [];
  for (const [uid, own] of eventsByUid) {
    for (const event of own) events.push({ ...event, participant: codes.get(uid) });
  }
  events.sort((a, b) => a.participant.localeCompare(b.participant) || a.t - b.t);

  // Curtidas de todo mundo servem para saber se houve reciprocidade, mas só
  // as decisões de participantes entram no conjunto.
  const allSwipes = (raw.swipes ?? []).filter((s) => (s.createdAtMs ?? 0) >= sinceMs);
  const likes = new Set(allSwipes.filter((s) => s.decision === 'like').map((s) => s.from + '>' + s.to));
  const others = new Map();
  const codeOf = (uid) => {
    if (codes.has(uid)) return codes.get(uid);
    if (!others.has(uid)) others.set(uid, 'N' + String(others.size + 1).padStart(2, '0'));
    return others.get(uid);
  };
  const swipes = allSwipes
    .filter((s) => codes.has(s.from))
    .sort((a, b) => (a.createdAtMs ?? 0) - (b.createdAtMs ?? 0))
    .map((s) => ({
      from: codeOf(s.from),
      to: codeOf(s.to),
      decision: s.decision,
      source: s.source,
      score: s.score,
      t: s.createdAtMs ?? null,
      reciprocated: s.decision === 'like' ? likes.has(s.to + '>' + s.from) : null,
    }));

  const matches = (raw.matches ?? []).filter((m) => (m.users ?? []).some((uid) => codes.has(uid))).length;

  const participants = [...codes.entries()]
    .map(([uid, code]) => {
      const own = eventsByUid.get(uid);
      const session = [...own].reverse().find((event) => event.type === 'session');
      return {
        code,
        firstEvent: new Date(Math.min(...own.map((e) => e.t))).toISOString(),
        lastEvent: new Date(Math.max(...own.map((e) => e.t))).toISOString(),
        events: own.length,
        platform: session?.platform ?? null,
        model: session?.model ?? null,
        os: session?.os ?? null,
      };
    })
    .sort((a, b) => a.code.localeCompare(b.code));

  return {
    exportedAt: exportedAt.toISOString(),
    since: since === null ? null : since.toISOString(),
    participants,
    events,
    swipes,
    matches,
  };
}
