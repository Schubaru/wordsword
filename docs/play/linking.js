// Linking words on the web: LinkingWords.swift's game, the same board the app deals today.
import { parseBank, bankByTier, makePuzzle } from './logic.js';
import { $, wait, reduced, text, today, store, caption, sheet, rules, shareButton, countdown, onNewDay, meaning, stats, shake, esc } from './play.js';

const MAX_MISTAKES = 4;
const INKS = ['--hl-yellow', '--hl-green', '--hl-blue', '--hl-pink'];
const INK_NAMES = ['Yellow', 'Green', 'Blue', 'Pink'];
const SYMBOLS = ['●', '▲', '■', '◆'];
const SHAPES = ['M12 3.5a8.5 8.5 0 1 0 0 17a8.5 8.5 0 1 0 0-17z', 'M12 3.5L21 19.5H3z', 'M4 4h16v16H4z', 'M12 2.5L21.5 12L12 21.5L2.5 12z'];

const N = today('linking');
const st = store('linkingWords', () => ({ number: 0, order: [], guesses: [], streak: 0, bestStreak: 0, lastSolved: 0, rulesSeen: false, stats: { played: 0, won: 0, last: 0 } }));
const save = st.load();
const persist = () => st.save(save);

const puzzle = makePuzzle(bankByTier(parseBank(await text('linking-words.txt'))), N);
const same = (a, b) => a.length === b.length && a.every(w => b.includes(w));
const groupOf = w => puzzle.groups.find(g => g.words.includes(w));
const matching = guess => puzzle.groups.find(g => same(g.words, guess));
const oneAway = guess => puzzle.groups.some(g => g.words.filter(w => guess.includes(w)).length === 3);

if (save.number !== N || !same(save.order, puzzle.order)) {
  Object.assign(save, { number: N, order: puzzle.order, guesses: [] });
  persist();
}

let selected = [], solved = [], mistakes = 0, phase = 'playing', busy = false, justFinished = false;
const drawn = new Set();
const streak = () => (save.lastSolved >= N - 1 ? save.streak : 0);
const finished = () => phase !== 'playing';
const gone = () => new Set(solved.flatMap(g => g.words));
const remaining = () => { const g = gone(); return save.order.filter(w => !g.has(w)); };

const cap = caption($('#caption'), () => (finished() ? 'Next puzzle at midnight' : 'Four groups of four words that mean the same thing'));

// ---------- Replaying today ----------
for (const g of save.guesses) { const m = matching(g); if (m) solved.push(m); else mistakes++; }
solved.forEach(g => drawn.add(g.headword));
if (solved.length === 4) { phase = 'won'; tally(true); }
else if (mistakes >= MAX_MISTAKES) { solved.push(...puzzle.groups.filter(g => !solved.includes(g))); solved.forEach(g => drawn.add(g.headword)); phase = 'lost'; tally(false); }

/// Counts today once: a win extends the streak, a loss ends it.
function tally(won) {
  const r = save.stats;
  if (r.last === save.number) return;
  r.played++; r.last = save.number;
  if (won) {
    r.won++;
    save.streak = save.lastSolved === save.number - 1 ? save.streak + 1 : 1;
    save.bestStreak = Math.max(save.bestStreak, save.streak);
    save.lastSolved = save.number;
  } else save.streak = 0;
  persist();
}

// ---------- Drawing ----------
function strip(g) {
  const el = document.createElement('section');
  el.className = 'strip hl-swipe';
  el.style.setProperty('--ink-color', `var(${INKS[g.ink]})`);
  el.setAttribute('aria-label', `${g.headword}: ${g.words.join(', ')}`);
  el.innerHTML = `<h3>${esc(g.headword)}</h3><p class="words">${g.words.map(esc).join(', ')}</p><p class="m"></p>`;
  if (!drawn.has(g.headword)) { el.classList.add('new', 'draw'); drawn.add(g.headword); }
  meaning(g.headword.toLowerCase()).then(m => { if (m) el.querySelector('.m').textContent = m; });
  return el;
}

function render() {
  const strips = $('#strips'), have = strips.children.length;
  solved.slice(have).forEach(g => strips.append(strip(g)));
  $('#grid').innerHTML = remaining().map(w =>
    `<button class="tile" type="button" style="--len:${w.length}" aria-pressed="${selected.includes(w)}" data-w="${esc(w)}"><span>${esc(w)}</span></button>`).join('');
  $('#mistakes .tally').innerHTML = Array.from({ length: MAX_MISTAKES }, (_, i) =>
    `<svg viewBox="0 0 14 22" class="${i < mistakes ? 'struck' : ''}"><line class="bar" x1="7.7" y1="1.1" x2="6.3" y2="20.9"/><line class="x" pathLength="1" x1="-2" y1="17.2" x2="16" y2="4.8"/></svg>`).join('');
  $('#mistakes').setAttribute('aria-label', `${MAX_MISTAKES - mistakes} of ${MAX_MISTAKES} mistakes left`);
  $('#mistakes').hidden = finished();
  $('#controls').hidden = finished();
  $('#done').hidden = !finished();
  $('#deselect').disabled = !selected.length;
  $('#board').classList.toggle('busy', busy);
}

const tilesFor = words => words.map(w => $(`.tile[data-w="${CSS.escape(w)}"]`)).filter(Boolean);

// ---------- Playing ----------
$('#grid').addEventListener('click', e => {
  const t = e.target.closest('.tile');
  if (!t || finished() || busy) return;
  const w = t.dataset.w, i = selected.indexOf(w);
  if (i >= 0) selected.splice(i, 1);
  else if (selected.length < 4) selected.push(w);
  t.setAttribute('aria-pressed', selected.includes(w));
  $('#deselect').disabled = !selected.length;
  if (selected.length === 4) submit();
});

$('#deselect').addEventListener('click', () => { if (busy) return; selected = []; render(); });
$('#shuffle').addEventListener('click', () => {
  if (finished() || busy) return;
  const g = gone(), rest = save.order.filter(w => !g.has(w));
  if (rest.length < 2) return;
  let next;
  do { next = rest.slice().sort(() => Math.random() - 0.5); } while (next.every((w, i) => w === rest[i]));
  save.order = save.order.filter(w => g.has(w)).concat(next);
  persist(); render();
});

/// The tiles hop first, then the guess lands.
async function submit() {
  const guess = selected.slice();
  busy = true; render();
  if (!reduced()) tilesFor(guess).forEach((t, i) => { t.style.animationDelay = `${i * 80}ms`; t.classList.add('hop'); });
  await wait(reduced() ? 120 : 80 * 4 + 300);
  busy = false;
  land(guess);
}

async function land(guess) {
  if (save.guesses.some(g => same(g, guess))) {
    cap.show('Already guessed');
    tilesFor(guess).forEach(shake);
    render();
    return;
  }
  save.guesses.push(guess);
  const group = matching(guess);
  if (group) {
    // The four move up to the first open row; the strip takes their place a beat later.
    const g = gone();
    save.order = save.order.filter(w => g.has(w)).concat(guess, save.order.filter(w => !g.has(w) && !guess.includes(w)));
    selected = []; persist(); busy = true; render();
    await wait(reduced() ? 0 : 380);
    busy = false;
    solved.push(group);
    render();
    if (solved.length === 4) { phase = 'won'; justFinished = true; tally(true); render(); cap.reset(); await wait(1000); openResults(); }
  } else {
    mistakes++;
    persist();
    render();
    if (oneAway(guess)) cap.show('Three of those share a meaning');
    tilesFor(guess).forEach(shake);
    if (mistakes >= MAX_MISTAKES) lose();
  }
}

/// Four strikes: the rest of the groups come up one at a time, then the day is over.
async function lose() {
  tally(false);
  selected = []; busy = true;
  cap.show('Next time');
  render();
  for (const g of puzzle.groups.filter(g => !solved.includes(g))) {
    await wait(reduced() ? 150 : 700);
    const done = gone();
    save.order = save.order.filter(w => done.has(w)).concat(g.words, save.order.filter(w => !done.has(w) && !g.words.includes(w)));
    render();
    await wait(reduced() ? 0 : 380);
    solved.push(g);
    render();
  }
  busy = false; phase = 'lost'; justFinished = true;
  render();
  await wait(600);
  openResults();
}

// ---------- Results ----------
const resultsSheet = sheet($('#results'));
const shareRows = () => save.guesses.map(g => g.map(w => groupOf(w).ink));
const verdict = () => phase === 'lost' ? 'Not today' : ['Clean sweep', 'Nicely done', 'Solid'][mistakes] || 'Close one';

function openResults() {
  $('#verdict').textContent = verdict();
  stats($('#stats'), [[save.stats.played, 'Days'], [save.stats.won, 'Solved'], [streak(), 'Streak'], [save.bestStreak, 'Best']]);
  const rows = shareRows();
  $('#share-grid').innerHTML = rows.map(r => `<div>${r.map(i =>
    `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="${SHAPES[i]}" fill="var(${INKS[i]})"/></svg>`).join('')}</div>`).join('');
  $('#share-grid').setAttribute('aria-label', rows.map((r, i) => `Guess ${i + 1}: ${r.map(k => INK_NAMES[k]).join(', ')}`).join('. '));
  resultsSheet.open();
}
$('#see-results').addEventListener('click', openResults);
// `data-share-url` on <body> (the standalone Linking words site) adds that link on its own line.
const shareUrl = document.body.dataset.shareUrl;
shareButton($('#share'), () => `Linking words #${N}\n` + shareRows().map(r => r.map(i => SYMBOLS[i]).join(' ')).join('\n') + (shareUrl ? `\n${shareUrl}` : ''));
countdown($('#countdown'), 'puzzle');

render();
rules(save, persist);
onNewDay('linking', N);
