// Plexicon on the web: Plexicon.swift's game, today's word from the app's own answer list.
import { plexScore, plexAnswer, ABSENT, PRESENT, CORRECT } from './logic.js';
import { $, wait, reduced, text, today, store, caption, sheet, rules, shareButton, countdown, onNewDay, meaning, stats, shake } from './play.js';

const LEN = 5, MAX = 6, STAGGER = 0.22;
const N = today('plexicon');
const st = store('plexicon', () => ({ number: 0, guesses: [], streak: 0, bestStreak: 0, lastSolved: 0, rulesSeen: false, played: 0, won: 0, lastCounted: 0, distribution: [0, 0, 0, 0, 0, 0] }));
const save = st.load();
const persist = () => st.save(save);

const [answers, guessList] = await Promise.all(['plexicon-answers.txt', 'plexicon-guesses.txt'].map(async f => (await text(f)).trim().split('\n')));
const answer = plexAnswer(answers, N);
const valid = new Set(guessList);
if (save.number !== N) { Object.assign(save, { number: N, guesses: [] }); persist(); }

let typed = '', phase = 'playing', revealing = false, fresh = -1;
const finished = () => phase !== 'playing';
const streak = () => (save.lastSolved >= N - 1 ? save.streak : 0);
const SPOKEN = ['not in the word', 'in the word, wrong spot', 'right spot'];

const cap = caption($('#caption'), () =>
  phase === 'lost' ? `It was ${answer.toUpperCase()}` : phase === 'won' ? 'Next word at midnight' : "Find today's five-letter word");

// ---------- The pen ----------
/// A ring drawn in one loop that starts up on the left and runs a little past where it began;
/// an underline a hair off level. Two shapes and no colour (PenRing / PenUnderline).
const RING = (() => {
  const pts = [];
  for (let i = 0; i <= 64; i++) {
    const t = i / 64, a = -2.3 + (2 * Math.PI + 0.45) * t, g = 0.95 + 0.1 * t;
    pts.push(`${(50 + Math.cos(a) * g * 40).toFixed(2)} ${(50 + Math.sin(a) * g * 40).toFixed(2)}`);
  }
  return 'M' + pts.join('L');
})();
const UNDERLINE = 'M20 80Q50 85 82 77';
const pen = m => m === CORRECT || m === PRESENT
  ? `<svg viewBox="0 0 100 100" aria-hidden="true"><path pathLength="1" d="${m === CORRECT ? RING : UNDERLINE}"/></svg>` : '';

function tile(letter, mark, cls = '', d = 0) {
  const k = mark === ABSENT ? 'absent' : '';
  return `<div class="tile ${k} ${cls}" style="--d:${d}s">${mark != null ? pen(mark) : ''}<span>${letter || ''}</span></div>`;
}

// ---------- Drawing ----------
function render() {
  const rows = [];
  for (let r = 0; r < MAX; r++) {
    const g = save.guesses[r], current = r === save.guesses.length && phase === 'playing';
    const letters = g || (current ? typed : '');
    const marks = g ? plexScore(g, answer) : null;
    let label = `Guess ${r + 1}, empty`;
    if (g) label = `Guess ${r + 1}, ${g.toUpperCase()}: ` + [...g].map((c, i) => `${c.toUpperCase()} ${SPOKEN[marks[i]]}`).join(', ');
    else if (current && typed) label = `Guess ${r + 1}, typing ${typed.toUpperCase()}, ${LEN - typed.length} to go`;
    const cells = Array.from({ length: LEN }, (_, c) => {
      const cursor = current && !revealing && c === letters.length;
      return tile(letters[c], marks ? marks[c] : null, cursor ? 'cursor' : letters[c] && !marks ? 'typed' : '', c * STAGGER);
    }).join('');
    rows.push(`<div class="row ${r === fresh ? 'fresh' : ''}" role="img" aria-label="${label}">${cells}</div>`);
  }
  $('#board').innerHTML = rows.join('');
  renderKeys();
  $('#keys').hidden = finished();
  $('#done').hidden = !finished();
}

function keyMarks() {
  const out = {};
  for (const g of save.guesses.slice(0, revealing ? -1 : undefined)) {
    plexScore(g, answer).forEach((m, i) => { out[g[i]] = Math.max(out[g[i]] ?? ABSENT, m); });
  }
  return out;
}

const ENTER = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M19 6v5a3 3 0 0 1-3 3H6M10 10l-4 4 4 4"/></svg>';
const DELETE = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8.5 6H19a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H8.5L3.5 12z"/><path d="M11.5 9.5l5 5M16.5 9.5l-5 5"/></svg>';
function renderKeys() {
  const marks = keyMarks();
  const key = c => {
    const m = marks[c];
    const svg = m === CORRECT || m === PRESENT ? `<svg class="m" viewBox="0 0 100 100" aria-hidden="true"><path d="${m === CORRECT ? RING : UNDERLINE}"/></svg>` : '';
    const said = m == null ? '' : `, ${SPOKEN[m]}`;
    return `<button class="key ${m === ABSENT ? 'absent' : ''}" type="button" data-k="${c}" aria-label="${c.toUpperCase()}${said}">${svg}<span>${c}</span></button>`;
  };
  const ready = typed.length === LEN ? 'ready' : '';
  $('#keys').innerHTML =
    `<div>${[...'qwertyuiop'].map(key).join('')}</div>` +
    `<div>${[...'asdfghjkl'].map(key).join('')}</div>` +
    `<div><button class="key wide ${ready}" type="button" data-k="enter" aria-label="Enter">${ENTER}</button>${[...'zxcvbnm'].map(key).join('')}` +
    `<button class="key wide" type="button" data-k="delete" aria-label="Delete">${DELETE}</button></div>`;
}

// ---------- Playing ----------
const canType = () => phase === 'playing' && !revealing;
function type(c) {
  if (!canType() || typed.length >= LEN) return;
  typed += c;
  fresh = -1; render();
  if (!reduced()) $(`#board .row:nth-child(${save.guesses.length + 1}) .tile:nth-child(${typed.length})`)?.classList.add('pop');
}
function del() { if (!canType() || !typed) return; typed = typed.slice(0, -1); fresh = -1; render(); }

async function enter() {
  if (!canType()) return;
  const row = () => $(`#board .row:nth-child(${save.guesses.length + 1})`);
  if (typed.length !== LEN) { cap.show('Five letters'); shake(row()); return; }
  if (!valid.has(typed)) { cap.show('Not a word I know'); shake(row()); return; }
  save.guesses.push(typed);
  const guess = typed;
  typed = ''; persist();
  revealing = true; fresh = save.guesses.length - 1;
  render();
  // The last tile starts four staggers in and takes a slash to draw.
  await wait(reduced() ? 50 : (STAGGER * 4 + 0.45) * 1000);
  revealing = false;
  renderKeys();
  $('#said').textContent = [...guess].map((c, i) => `${c.toUpperCase()} ${SPOKEN[plexScore(guess, answer)[i]]}`).join(', ');
  if (guess === answer) finish(true);
  else if (save.guesses.length >= MAX) finish(false);
}

async function finish(won) {
  tally(won);
  phase = won ? 'won' : 'lost';
  fresh = -1; render(); cap.reset();
  if (won && !reduced()) {
    const r = $(`#board .row:nth-child(${save.guesses.length})`);
    r.querySelectorAll('.tile').forEach((t, i) => t.style.setProperty('--h', `${i * 80}ms`));
    r.classList.add('win');
  }
  await wait(won ? 1200 : 1000);
  openResults();
}

/// Counts today once: a finished day is played; a win extends the streak, a loss ends it.
function tally(won) {
  if (save.lastCounted === save.number) return;
  save.played++; save.lastCounted = save.number;
  if (won) {
    save.won++;
    save.distribution[Math.min(Math.max(save.guesses.length, 1), MAX) - 1]++;
    save.streak = save.lastSolved === save.number - 1 ? save.streak + 1 : 1;
    save.bestStreak = Math.max(save.bestStreak, save.streak);
    save.lastSolved = save.number;
  } else save.streak = 0;
  persist();
}

$('#keys').addEventListener('click', e => {
  const k = e.target.closest('.key')?.dataset.k;
  if (k === 'enter') enter(); else if (k === 'delete') del(); else if (k) type(k);
});
document.addEventListener('keydown', e => {
  if (e.metaKey || e.ctrlKey || e.altKey || document.querySelector('dialog[open]')) return;
  // Enter on a focused header control is that control's; on the board or an on-screen key it's the guess.
  if (e.key === 'Enter') { if (e.target.closest?.('a, button:not(.key)')) return; e.preventDefault(); enter(); }
  else if (e.key === 'Backspace' || e.key === 'Delete') { e.preventDefault(); del(); }
  else if (/^[a-z]$/i.test(e.key)) { e.preventDefault(); type(e.key.toLowerCase()); }
});

// ---------- Results ----------
const resultsSheet = sheet($('#results'));
const verdict = () => phase !== 'won' ? 'Not today' : ['First guess', 'Sharp', 'Nicely done', 'Solid', 'Close one', 'Just in time'][save.guesses.length - 1];
// `data-share-url` on <body> (the standalone Plexicon site) adds that link on its own line.
const shareUrl = document.body.dataset.shareUrl;
const shareText = () => `Plexicon #${N} · ${phase === 'won' ? `got it on guess ${save.guesses.length}` : 'not today'}\n` +
  save.guesses.map(g => plexScore(g, answer).map(m => ['·', '○', '◉'][m]).join(' ')).join('\n') + (shareUrl ? `\n${shareUrl}` : '');

function openResults() {
  $('#verdict').textContent = verdict();
  $('#answer').textContent = answer;
  meaning(answer).then(m => { $('#meaning').textContent = m || ''; });
  stats($('#stats'), [[save.played, 'Days'], [save.won, 'Solved'], [streak(), 'Streak'], [save.bestStreak, 'Best']]);
  const d = save.distribution, top = Math.max(1, ...d), mine = phase === 'won' ? save.guesses.length : 0;
  $('#bars').innerHTML = '<span>Guesses it took</span>' + d.map((n, i) =>
    `<div><i>${i + 1}</i><b class="${mine === i + 1 ? 'mine' : ''}" style="width:max(26px, ${(n / top) * 100}%)">${n}</b></div>`).join('');
  $('#bars').setAttribute('aria-label', 'Guesses it took: ' + d.map((n, i) => `${i + 1}: ${n}`).join(', '));
  resultsSheet.open();
}
$('#see-results').addEventListener('click', openResults);
shareButton($('#share'), shareText);
countdown($('#countdown'), 'word');

$('#legend').innerHTML = [['s', CORRECT, 'Circled: in the word, in the right spot'], ['a', PRESENT, 'Underlined: in the word, in another spot'], ['l', ABSENT, 'Faded: not in the word']]
  .map(([l, m, t]) => `<div class="legend">${tile(l, m)}<span>${t}</span></div>`).join('');

// ---------- Today ----------
if (save.guesses.at(-1) === answer) { phase = 'won'; tally(true); }
else if (save.guesses.length >= MAX) { phase = 'lost'; tally(false); }
cap.reset();
render();
rules(save, persist);
onNewDay('plexicon', N);
