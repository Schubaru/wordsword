// The web games' one check: docs/play/logic.js must play exactly what the app plays.
// Scripts/web-games-golden.json is the app's own output, written by Scripts/make-web-games.swift.
//   node Scripts/check-web-games.mjs
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import * as L from '../docs/play/logic.js';

const root = new URL('..', import.meta.url);
const read = p => readFileSync(new URL(p, root), 'utf8');
const golden = JSON.parse(read('Scripts/web-games-golden.json'));
const answers = read('docs/play/data/plexicon-answers.txt').trim().split('\n');
const byTier = L.bankByTier(L.parseBank(read('docs/play/data/linking-words.txt')));
const bank = JSON.parse(read('docs/play/data/haiklu-bank.json'));

for (const d of golden.days) {
  assert.equal(L.plexAnswer(answers, d.n), d.plexicon, `Plexicon #${d.n}`);
  const p = L.makePuzzle(byTier, d.n);
  assert.deepEqual({ groups: p.groups, order: p.order }, d.linking, `Linking words #${d.n}`);
  assert.equal(L.haikuIndex(bank, d.n), d.haiklu, `Haiklu #${d.n}`);
}
for (const c of golden.plexicon) assert.deepEqual(L.plexScore(c.guess, c.answer), c.marks, `${c.guess} vs ${c.answer}`);

const words = new Set(read('docs/play/data/haiku-words.txt').split('\n'));
const rank = new Map();
read('docs/play/data/haiku-common.txt').split('\n').forEach((w, i) => { if (!rank.has(w)) rank.set(w, i); });
for (const c of golden.resolve) {
  const { typed, ...want } = c;
  assert.deepEqual(L.resolve(typed, words, rank), want, `resolve ${typed}`);
}
const fileFor = a => L.parseScores(read(`docs/play/data/haiklu/${bank.findIndex(h => h.answer === a)}.txt`));
for (const c of golden.scores) {
  if (!bank.some(h => h.answer === c.answer)) continue; // answer-form cases for words outside the bank
  assert.equal(L.haikuScore(c.guess, c.answer, fileFor(c.answer)), c.score, `${c.guess} → ${c.answer}`);
}
assert.equal(L.haikuScore('track', 'tracks', new Map()), 100);
assert.equal(L.haikuScore('muffle', 'muffled', new Map()), 100);
assert.ok(L.haikuScore('wicked', 'wick', new Map()) < 100);
assert.equal(L.dayNumber(L.EPOCH.linking, new Date(2026, 10, 2, 23, 59)), 11, 'across the DST change');
console.log(`web games match the app: ${golden.days.length} days, ${golden.resolve.length} typo fixes, ${golden.scores.length} scores`);
