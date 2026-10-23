---
version: 1
slug: "wordsword-games-linkingwordsview-swift"
primary_target: "Wordsword/Games/LinkingWordsView.swift"
related_targets: ["Wordsword/Games/GamesHubView.swift"]
---

# Linking words (Wordsword/Games/LinkingWordsView.swift)

Scope: one pushed screen (the game) + one GameCard on Home. Mode: Operate, with one Experience moment (a group solving). Code-led, native iOS, inherits DESIGN.md's paper/sheet/pen world. Nothing else in the app changes.

Audience / job: a reader with the book in one hand, two minutes to spare. Task: sort 16 words into four groups of four synonyms, once a day, same puzzle for everyone. Important states: fresh board · 1–4 selected · one away · already guessed · solved strip · four strikes reveal · results (won / lost) · finished board revisited · midnight rollover. Frequency: daily, so the solve must stay satisfying on the hundredth day. Constraints: Dynamic Type, Reduce Motion crossfades, VoiceOver, colour never the only signal, no streaks-as-guilt.

## Direction contract

THESIS: Finding the fourth word should feel like a highlighter finally finding its line in a textbook. The four tiers are the four highlighters of a 2010 pencil case — yellow, green, blue, pink — and the only colour on the screen is a solved group. Refused: NYT's flat coloured-block UI copied onto white, and the Duolingo confetti-celebration arrangement.

OWN-WORLD: College-ruled paper; 16 word tiles as small white sheets (sheet fill, 1pt rule edge, radius 12, SF Rounded semibold uppercase); a selected tile is the pen (pen fill, on-pen text); captions in `.pron` ink-2 written on a rule; four pen tally marks for mistakes, struck through with a diagonal pen stroke; a solved group is a strip with a highlighter stroke wiped across it (marker-shaped mask, 420ms, the slash curve) carrying the headword in rounded bold and its four words in ink; the knight at 44pt in the header reacting; the results card is a bottom sheet with the share grid drawn as highlighter squares. With all words removed it is still recognisably a notebook page with four highlighter strokes on it.

STORY: "Four groups of four words that mean the same thing." Tap four, Submit, watch the pen hop; a right answer gets highlighted and written up with its headword; a wrong one shakes and strikes a tally. Four strikes reveal the rest. Every solved word is a word you can look up. Come back tomorrow for the next one; the card remembers the streak.

FIRST VIEWPORT: Header row (back glass · knight · ? glass), title "Linking words" on its rule, the hint/caption line on the next rule, then the board: solved strips (none at start) over a 4×4 grid of tiles filling the width with 8pt gaps, "Mistakes left" + four tally marks under it, and a controls row of Shuffle · Deselect · Submit capsules directly under the tally marks — the NYT placement, kept with the board so Submit sits a thumb's reach from the tiles (pinning it to the screen bottom left two fifths of the paper empty between board and buttons on an iPhone 17 Pro; changed in the first inspection round). Primary action = Submit, pen-filled only when four are selected.

FORM: Highlighter set — chosen by Alex from three overdrive directions (Highlighter set / Pen lasso / Paper slips) through the structured question; no concept-seed roll was run because the direction was user-pinned. Signature interaction: the highlighter wipe on a solved strip; motion grammar: hop (feedback) → slide (reveal) → wipe (slash) → write-in (state).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.
