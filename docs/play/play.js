// What every web game shares: today's number, the save, sheets, captions, sharing, the countdown,
// and a word's meaning. The rules themselves live in logic.js.
import { dayNumber, EPOCH } from './logic.js';

export const $ = (s, el = document) => el.querySelector(s);
export const wait = ms => new Promise(r => setTimeout(r, ms));
export const reduced = () => matchMedia('(prefers-reduced-motion: reduce)').matches;
export const data = name => new URL(`./data/${name}`, import.meta.url);
export const text = async name => { const r = await fetch(data(name)); if (!r.ok) throw new Error(name); return r.text(); };

const local = ['localhost', '127.0.0.1', '[::1]'].includes(location.hostname);
/// Today's puzzle number. On localhost, `?day=N` plays day N (for checking a day by hand).
export function today(game) {
  const forced = local && Number(new URLSearchParams(location.search).get('day'));
  return forced > 0 ? forced : dayNumber(EPOCH[game]);
}

/// One record per game, like the app's UserDefaults key. Blocked or cleared storage starts fresh.
export function store(key, fresh) {
  return {
    load() { try { return { ...fresh(), ...JSON.parse(localStorage.getItem(key) || '{}') }; } catch { return fresh(); } },
    save(v) { try { localStorage.setItem(key, JSON.stringify(v)); } catch {} },
  };
}

/// The caption row: says something for a moment, then goes back to what the game says by default.
export function caption(el, fallback) {
  let timer;
  const set = (t, flash) => { el.textContent = t; el.classList.toggle('flash', !!flash); };
  set(fallback());
  return {
    show(t, ms = 2200) { clearTimeout(timer); set(t, true); timer = setTimeout(() => set(fallback()), ms); },
    reset() { clearTimeout(timer); set(fallback()); },
  };
}

/// Sheets open with showModal (Escape and the backdrop close them) and hand focus back after.
export function sheet(dialog) {
  dialog.addEventListener('click', e => { if (e.target === dialog) dialog.close(); });
  dialog.querySelectorAll('[data-close]').forEach(b => b.addEventListener('click', () => dialog.close()));
  return { open: () => dialog.open || dialog.showModal(), close: () => dialog.close(), el: dialog };
}

/// How to play: from the `?`, and once on the first visit.
export function rules(save, persist) {
  const s = sheet($('#rules'));
  $('[data-rules]').addEventListener('click', s.open);
  if (!save.rulesSeen) { save.rulesSeen = true; persist(); s.open(); }
  return s;
}

/// The share sheet on a phone; the clipboard elsewhere, with the button saying so.
export function shareButton(button, getText) {
  button.addEventListener('click', async () => {
    const t = getText();
    if (navigator.share && matchMedia('(pointer: coarse)').matches) {
      try { await navigator.share({ text: t }); return; } catch (e) { if (e.name === 'AbortError') return; }
    }
    try { await navigator.clipboard.writeText(t); } catch { return; }
    const was = button.textContent;
    button.textContent = 'Copied';
    setTimeout(() => { button.textContent = was; }, 1800);
  });
}

/// "Next word in 3h 12m", to local midnight, like the app.
export function countdown(el, what) {
  const tick = () => {
    const now = new Date(), next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    const s = Math.max(0, Math.floor((next - now) / 1000)), h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    el.textContent = `Next ${what} in ${h > 0 ? `${h}h ${m}m` : `${m}m`}`;
  };
  tick();
  setInterval(tick, 30_000);
}

/// Midnight passed while the tab was away: coming back means the new day's puzzle.
export function onNewDay(game, number) {
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && today(game) !== number) location.reload();
  });
}

/// A word's meaning in one sentence: Datamuse's most common sense (dictionaryapi.dev when Datamuse
/// can't answer), kept once fetched. Offline it's simply left out.
export async function meaning(word) {
  const key = `meaning.${word}`;
  try { const kept = localStorage.getItem(key); if (kept) return kept; } catch {}
  const w = encodeURIComponent(word);
  const sources = [
    // Datamuse's CDN caches its CORS header with the response, so the URL carries our host: a
    // response cached for another origin would otherwise be refused here.
    async () => {
      const [hit] = await (await fetch(`https://api.datamuse.com/words?sp=${w}&md=d&max=1&o=${encodeURIComponent(location.host)}`)).json();
      return hit && hit.word === word && hit.defs && hit.defs[0].split('\t').pop();
    },
    async () => (await (await fetch(`https://api.dictionaryapi.dev/api/v2/entries/en/${w}`)).json())[0].meanings[0].definitions[0].definition,
  ];
  for (const source of sources) {
    try {
      // Usage labels like "(transitive)" lead some senses; the sentence starts after them.
      let m = (await source() || '').replace(/^(\s*\([^)]*\))+/, '').trim();
      if (!m) continue;
      m = m[0].toUpperCase() + m.slice(1) + (/[.!?]$/.test(m) ? '' : '.');
      try { localStorage.setItem(key, m); } catch {}
      return m;
    } catch {}
  }
  return null;
}

/// Days · Solved · Streak · Best.
export function stats(el, items) {
  el.innerHTML = items.map(([v, l]) => `<div><b>${v}</b><span>${l}</span></div>`).join('');
  el.setAttribute('aria-label', items.map(([v, l]) => `${l} ${v}`).join(', '));
}

/// Shakes an element once (a wrong move), unless motion is reduced.
export function shake(el) {
  if (reduced()) return;
  el.classList.remove('shake'); void el.offsetWidth; el.classList.add('shake');
}

export const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
