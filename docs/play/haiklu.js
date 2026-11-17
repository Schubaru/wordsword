// Haiklu on the web: Haikuzy.swift's game, today's haiku and the app's own scores for it.
import { haikuIndex, clean, resolve, sameWord, parseScores, haikuScore, warmth } from './logic.js';
import { $, wait, reduced, text, data, today, store, caption, sheet, rules, shareButton, countdown, onNewDay, shake, esc } from './play.js';

const MAX = 4;
const N = today('haiklu');
const st = store('haiklu', () => ({ number: 0, guesses: [], lastSolved: 0, rulesSeen: false }));
const save = st.load();
const persist = () => st.save(save);

const bank = await (await fetch(data('haiklu-bank.json'))).json();
const index = haikuIndex(bank, N), haiku = bank[index], answer = haiku.answer;
const scores = parseScores(await text(`haiklu/${index}.txt`));
// The dictionary (for real words and typo fixes) is big: fetched now, awaited only by a guess.
const dictionary = Promise.all([text('haiku-words.txt'), text('haiku-common.txt')]).then(([w, c]) => {
  const rank = new Map();
  c.split('\n').forEach((x, i) => { if (!rank.has(x)) rank.set(x, i); });
  return { words: new Set(w.split('\n')), rank };
});

if (save.number !== N) { Object.assign(save, { number: N, guesses: [] }); persist(); }

let phase = 'playing', busy = false, fresh = -1, choicesFor = null;
const finished = () => phase !== 'playing';
const best = () => save.guesses.reduce((b, g) => (!b || g.score > b.score ? g : b), null);
// The day's total, as HaikuzySave.total: every score, plus 100 for each guess a solve didn't need.
const total = () => save.guesses.reduce((t, g) => t + g.score, 0) +
  (save.guesses.some(g => g.score === 100) ? (MAX - save.guesses.length) * 100 : 0);

const cap = caption($('#caption'), () => {
  if (phase === 'won') return 'Next haiku at midnight';
  if (phase === 'lost') return `It was “${answer}”`;
  const left = MAX - save.guesses.length;
  return !save.guesses.length ? 'Guess the missing word' : left === 1 ? 'Last guess' : `${left} guesses left`;
});

// ---------- The poem ----------
const BLANK = '<span class="blank" role="img" aria-label="blank"><svg viewBox="0 0 76 6" preserveAspectRatio="none" aria-hidden="true"><path d="M1 3.6Q20 2.2 38 3.2T75 2.6"/></svg></span>';
function poem(reveal, animate) {
  return haiku.lines.map(line => {
    const [before, after] = line.split('{}').map(esc);
    if (after === undefined) return `<p>${before}</p>`;
    const word = reveal
      ? `<span class="written hl-swipe ${reveal} ${animate ? 'cut' : ''}">${esc(answer)}</span>`
      : BLANK;
    return `<p>${before}${word}${after}</p>`;
  }).join('');
}

// ---------- Drawing ----------
function render(animatePoem = false) {
  const reveal = finished() ? (phase === 'won' ? 'found' : 'miss') : null;
  $('#poem').innerHTML = poem(reveal, animatePoem && !reduced());
  const top = best();
  $('#guesses').innerHTML = Array.from({ length: MAX }, (_, i) => {
    const g = save.guesses[i];
    if (!g) return `<li class="guess" aria-label="Guess ${i + 1}, not yet"></li>`;
    const isBest = top && g === top;
    let label = `Guess ${i + 1}, ${g.word}${g.typed ? `, fixed from ${g.typed}` : ''}, ${g.score} of 100${isBest && g.score < 100 ? ', best so far' : ''}`;
    const hl = g.score === 100 ? `hl-swipe ${i === fresh ? 'draw' : ''}` : '';
    return `<li class="guess ${isBest ? 'best' : ''} ${i === fresh ? 'fresh' : ''}" aria-label="${esc(label)}"><div class="line" aria-hidden="true">` +
      `<span class="w ${hl}">${esc(g.word)}</span>${g.typed ? `<s>${esc(g.typed)}</s>` : ''}<span class="score">${g.score}</span></div>` +
      `<div class="track" aria-hidden="true"><div class="fill" style="--s:${g.score}"></div></div></li>`;
  }).join('');
  $('#field').hidden = finished();
  $('#see-results').hidden = !finished();
  if (finished()) $('#choices').hidden = true;
  $('#input').placeholder = `Guess ${save.guesses.length + 1} of ${MAX}`;
}

// ---------- Guessing ----------
const input = $('#input'), go = $('#go');
input.addEventListener('input', () => { go.hidden = !input.value.trim(); $('#choices').hidden = true; });
$('#field').addEventListener('submit', async e => {
  e.preventDefault();
  if (busy || finished()) return;
  const typed = clean(input.value);
  if (!typed) return;
  busy = true; go.disabled = true;
  const { words, rank } = await dictionary;
  const r = resolve(typed, words, rank);
  busy = false; go.disabled = false;
  if (r.unknown) { cap.show('Not a word I know'); shake($('#field')); return; }
  if (r.choices) {
    // A fix already guessed isn't a choice; one left over is simply the guess.
    const open = r.choices.filter(w => !save.guesses.some(g => sameWord(g.word, w)));
    if (open.length === 1) return commit(open[0], typed);
    if (!open.length) { cap.show('Already guessed'); shake($('#field')); return; }
    choicesFor = typed;
    $('#choices div').innerHTML = open.map(w => `<button type="button" data-w="${esc(w)}">${esc(w)}</button>`).join('');
    $('#choices').hidden = false;
    $('#choices button').focus();
    return;
  }
  commit(r.word || r.corrected, r.corrected ? typed : null);
});
$('#choices').addEventListener('click', e => {
  const w = e.target.closest('button')?.dataset.w;
  if (!w) return;
  $('#choices').hidden = true;
  commit(w, choicesFor);
});

async function commit(word, typed) {
  if (save.guesses.some(g => sameWord(g.word, word))) { cap.show('Already guessed'); shake($('#field')); return; }
  const score = haikuScore(word, answer, scores);
  save.guesses.push({ word, typed: typed || undefined, score });
  persist();
  input.value = ''; go.hidden = true;
  fresh = save.guesses.length - 1;
  render();
  cap.show(warmth(score), 2600);
  if (score === 100) return finish(true);
  if (save.guesses.length >= MAX) return finish(false);
  input.focus();
}

async function finish(won) {
  if (won) save.lastSolved = save.number;
  save.totals = { ...save.totals, [save.number]: total() };
  persist();
  phase = won ? 'won' : 'lost';
  input.blur();
  await wait(reduced() ? 300 : 700);
  fresh = -1;
  render(true);
  await wait(won ? 1600 : 1400);
  openResults();
}

// ---------- Results ----------
const resultsSheet = sheet($('#results'));
function verdict() {
  if (phase === 'won') return ['First guess', 'Sharp', 'Nicely done', 'Last guess'][save.guesses.length - 1];
  const b = best()?.score || 0;
  return b >= 90 ? 'So close' : b >= 70 ? 'Warm' : 'Not today';
}
function openResults() {
  $('#verdict').textContent = verdict();
  $('#poem-done').innerHTML = poem(phase === 'won' ? 'found' : 'miss', false);
  $('#scores').textContent = save.guesses.map(g => g.score).join(' · ');
  $('#scores').setAttribute('aria-label', 'Scores: ' + save.guesses.map(g => `${g.word} ${g.score}`).join(', '));
  $('#total').textContent = total();
  $('#total').setAttribute('aria-label', `Total ${total()}`);
  resultsSheet.open();
}
$('#see-results').addEventListener('click', openResults);
// The scores only: the word stays a secret for whoever you send it to. A page that names a
// `data-share-url` on <body> (the standalone Haiklu site) adds that link on its own line.
const shareUrl = document.body.dataset.shareUrl;
shareButton($('#share'), () => `Haiklu #${N} · ${total()}\n` + save.guesses.map(g => g.score).join(' · ') + (shareUrl ? `\n${shareUrl}` : ''));
countdown($('#countdown'), 'haiku');

// ---------- Today ----------
if (save.guesses.some(g => g.score === 100)) phase = 'won';
else if (save.guesses.length >= MAX) phase = 'lost';
cap.reset();
render();
const r = rules(save, persist);
r.el.addEventListener('close', () => { if (!finished()) input.focus(); });
if (!r.el.open && !finished()) input.focus();
onNewDay('haiklu', N);
