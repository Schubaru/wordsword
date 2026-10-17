#!/usr/bin/env python3
"""Builds Word Wheel's bundled word lists. Run from anywhere:  python3 Scripts/make-wordlists.py

Sources, fetched into a temp dir, all public domain:
  ENABLE word list                         -> wheel-words.txt   every playable word, 3-7 letters (the validator)
  12dicts 3esl + 2of12 (Alan Beale, who    -> wheel-common.txt  board-word ranking: 3esl first, then 2of12-only
     asks only for acknowledgment)         -> wheel-seeds.txt   3esl words a level can be built around (4-7 letters,
                                                                with enough familiar sub-words to fill a board)
Reproducible: same inputs, same bytes out.
"""
import io, itertools, pathlib, re, subprocess, zipfile
from collections import Counter

ENABLE = 'https://raw.githubusercontent.com/dolph/dictionary/master/enable1.txt'
TWELVE = 'https://downloads.sourceforge.net/wordlist/12dicts-6.0.2.zip'
OUT = pathlib.Path(__file__).resolve().parent.parent / 'Wordsword' / 'Games'
# Words a word game shouldn't hand out, even if a dictionary lists them.
BLOCK = {
    'nigger', 'niggers', 'nigga', 'niggas', 'negro', 'negroes', 'kike', 'kikes', 'spic', 'spics', 'spick',
    'wetback', 'chink', 'chinks', 'gook', 'gooks', 'jap', 'japs', 'raghead', 'towelhead', 'wop', 'wops',
    'dago', 'dagos', 'kraut', 'krauts', 'paki', 'pakis', 'coon', 'coons', 'darkie', 'darkies', 'darky',
    'fag', 'fags', 'faggot', 'faggots', 'dyke', 'dykes', 'tranny', 'retard', 'retards', 'spaz', 'spazz',
    'cunt', 'cunts', 'twat', 'twats', 'shemale', 'homo', 'homos', 'queers', 'gyp', 'gyps', 'gypped',
}
MIN_FAMILIAR = {4: 3, 5: 5, 6: 6, 7: 7}   # lower end of WordWheelRules.targetRange, by wheel size


def fetch(url): return subprocess.run(['curl', '-sSL', url], capture_output=True, check=True).stdout   # curl: python.org builds ship no CA bundle
def ok(w): return re.fullmatch(r'[a-z]{3,7}', w) is not None and w not in BLOCK
def lines(b): return [l.strip() for l in b.decode('latin-1').splitlines()]


enable = sorted({w for w in lines(fetch(ENABLE)) if ok(w)})
z = zipfile.ZipFile(io.BytesIO(fetch(TWELVE)))
playable = set(enable)
esl = [w for w in lines(z.read('American/3esl.txt')) if ok(w) and w in playable]
two = [w for w in lines(z.read('American/2of12.txt')) if ok(w) and w in playable and w not in set(esl)]

# A seed must spell enough familiar words (itself included) to fill its board.
familiar = set(esl) | set(two)
sig = lambda w: ''.join(sorted(w))
by_sig = Counter(sig(w) for w in familiar)
def familiar_subwords(w):
    seen, n = set(), 0
    for r in range(3, len(w) + 1):
        for comb in itertools.combinations(sorted(w), r):
            s = ''.join(comb)
            if s not in seen:
                seen.add(s); n += by_sig.get(s, 0)
    return n
seeds = [w for w in esl if 4 <= len(w) <= 7 and familiar_subwords(w) >= MIN_FAMILIAR[len(w)]]

OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'wheel-words.txt').write_text('\n'.join(enable) + '\n')
(OUT / 'wheel-common.txt').write_text('\n'.join(esl + two) + '\n')
(OUT / 'wheel-seeds.txt').write_text('\n'.join(seeds) + '\n')
print(f'words {len(enable)}  common {len(esl)}+{len(two)}  seeds', {n: sum(len(s) == n for s in seeds) for n in range(4, 8)})
