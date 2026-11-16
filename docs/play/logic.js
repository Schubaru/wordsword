// The three games' rules with no page in them, ported line for line from the app
// (Plexicon.swift, LinkingWordsPuzzles.swift, Haikuzy.swift). Scripts/check-web-games.mjs holds
// every function here to the app's own output.
import { SplitMix64, shuffled } from './rng.js';

// ---------- Days ----------
/// Day N since a game's epoch, counted in local calendar days, so it turns over at local midnight
/// like the app — and a daylight-saving change can't skip or repeat one.
export function dayNumber([y, m, d], date = new Date()) {
  const start = Date.UTC(y, m - 1, d), today = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
  return Math.max(1, Math.round((today - start) / 864e5) + 1);
}
export const EPOCH = { plexicon: [2026, 11, 10], linking: [2026, 10, 23], haiklu: [2026, 11, 10] };

// ---------- Plexicon ----------
export const ABSENT = 0, PRESENT = 1, CORRECT = 2;
/// Right spots first; then a letter counts as "elsewhere" only while the answer still has an
/// unclaimed copy of it, left to right.
export function plexScore(guess, answer) {
  const g = [...guess], a = [...answer], marks = g.map(() => ABSENT), left = {};
  g.forEach((ch, i) => { if (ch === a[i]) marks[i] = CORRECT; else if (i < a.length) left[a[i]] = (left[a[i]] || 0) + 1; });
  g.forEach((ch, i) => { if (marks[i] !== CORRECT && left[ch] > 0) { marks[i] = PRESENT; left[ch]--; } });
  return marks;
}
export const plexAnswer = (answers, n) => answers[(Math.max(1, n) - 1) % answers.length];

// ---------- Linking words ----------
/// `1 HAPPY: glad, cheerful, …` per line; `#` lines and blanks skipped.
export function parseBank(text) {
  const out = [];
  for (const raw of text.split('\n')) {
    const line = raw.trim(), colon = line.indexOf(':'), tier = Number(line[0]) - 1;
    if (!line || line.startsWith('#') || colon < 0 || !(tier >= 0 && tier <= 3)) continue;
    const headword = line.slice(1, colon).trim();
    const words = line.slice(colon + 1).split(',').map(s => s.trim()).filter(Boolean);
    if (headword && words.length) out.push({ tier, headword, words });
  }
  return out;
}

/// Each tier's clusters in their fixed seeded order (LinkBank.init).
export function bankByTier(clusters) {
  return [0, 1, 2, 3].map(t => shuffled(clusters.filter(c => c.tier === t), new SplitMix64(0x11AC0000n + BigInt(t))));
}

/// LinkingPuzzle.make(number:): one cluster per tier, four of its words, the day's inks, the board.
export function makePuzzle(byTier, n) {
  const rng = new SplitMix64(0x11AC5EEDn + BigInt(Math.max(0, n)));
  const inks = shuffled([0, 1, 2, 3], new SplitMix64(0x11AC1A4Cn + BigInt(Math.max(0, n))));
  const groups = [];
  for (const list of byTier) {
    if (!list.length) continue;
    const c = list[(Math.max(1, n) - 1) % list.length];
    groups.push({ tier: c.tier, ink: inks[groups.length], headword: c.headword, words: shuffled(c.words, rng).slice(0, 4) });
  }
  return { number: n, groups, order: shuffled(groups.flatMap(g => g.words), rng) };
}

// ---------- Haiklu ----------
const SEASONS = ['winter', 'winter', 'spring', 'spring', 'spring', 'summer', 'summer', 'summer', 'autumn', 'autumn', 'autumn', 'winter'];
/// The bank index of day N's poem: the k-th day of a season reads that season's k-th poem.
export function haikuIndex(bank, n) {
  const [y, m, d] = EPOCH.haiklu, season = i => SEASONS[new Date(Date.UTC(y, m - 1, d + i)).getUTCMonth()];
  const want = season(Math.max(1, n) - 1);
  let k = 0;
  for (let i = 0; i < Math.max(1, n) - 1; i++) if (season(i) === want) k++;
  let pool = bank.map((h, i) => i).filter(i => bank[i].season === want);
  if (!pool.length) pool = bank.map((h, i) => i); // a season with no poems yet borrows the whole bank
  return pool[k % pool.length];
}

/// Lowercase, first word only, letters only: "  Globe! " → "globe".
export const clean = raw => (raw.trim().split(/\s+/)[0] || '').toLowerCase().replace(/[^a-z]/g, '');

const ALPHABET = 'abcdefghijklmnopqrstuvwxyz';
function transpositions(w) {
  const out = [];
  for (let i = 0; i < w.length - 1; i++) if (w[i] !== w[i + 1]) out.push(w.slice(0, i) + w[i + 1] + w[i] + w.slice(i + 2));
  return out;
}
function edits(w) {
  const out = transpositions(w);
  for (let i = 0; i < w.length; i++) {
    out.push(w.slice(0, i) + w.slice(i + 1));
    for (const a of ALPHABET) if (a !== w[i]) out.push(w.slice(0, i) + a + w.slice(i + 1));
  }
  for (let i = 0; i <= w.length; i++) for (const a of ALPHABET) out.push(w.slice(0, i) + a + w.slice(i));
  return out;
}

/// HaikuzyWords.resolve: a real word as typed; else an obvious typo fix; else up to three choices.
/// `words` is a Set, `rank` a Map (lower = more everyday).
export function resolve(typed, words, rank) {
  if (!typed) return { unknown: true };
  if (words.has(typed)) return { word: typed };
  const swaps = new Set(transpositions(typed).filter(w => words.has(w)));
  if (swaps.size === 1) return { corrected: [...swaps][0] };
  let near = new Set(edits(typed).filter(w => words.has(w))), reach = 1;
  if (!near.size && typed.length >= 6) {
    near = new Set(edits(typed).flatMap(edits).filter(w => words.has(w)));
    reach = 2;
  }
  if (!near.size) return { unknown: true };
  const r = w => rank.has(w) ? rank.get(w) : Infinity;
  const ranked = [...near].sort((a, b) => r(a) - r(b) || (a < b ? -1 : a > b ? 1 : 0));
  const everyday = ranked.filter(w => rank.has(w));
  if (everyday.length === 1) return { corrected: everyday[0] };
  if (!everyday.length && ranked.length === 1 && reach === 1) return { corrected: ranked[0] };
  return { choices: (everyday.length ? everyday : ranked).slice(0, 3) };
}

/// The same word, give or take a plural.
export function sameWord(a, b) {
  const plural = (x, y) => x === y + 's' || x === y + 'es' || (y.endsWith('y') && x === y.slice(0, -1) + 'ies');
  return a === b || plural(a, b) || plural(b, a);
}
/// The answer, or — only when the answer is a past form — its stem. "wicked" isn't "wick".
export const isAnswer = (guess, answer) =>
  sameWord(guess, answer) || (answer.endsWith('ed') && (guess === answer.slice(0, -1) || guess === answer.slice(0, -2)));

/// A poem's score file (`57: word word …`) as a Map.
export function parseScores(text) {
  const m = new Map();
  for (const line of text.split('\n')) {
    const [s, ws] = line.split(': ');
    if (ws) for (const w of ws.split(' ')) m.set(w, Number(s));
  }
  return m;
}
export const haikuScore = (guess, answer, scores) => isAnswer(guess, answer) ? 100 : Math.min(99, scores.get(guess) || 1);

/// The word for a score, said as it lands (HaikuzyRules.warmth).
export const warmth = s => s === 100 ? "That's the word" : s >= 90 ? 'So close' : s >= 70 ? 'Warm' : s >= 40 ? 'Lukewarm' : 'Cold';
