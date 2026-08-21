# Design

Platform: iOS (SwiftUI). Follows system light/dark. Liquid Glass (`.glassEffect`) when built with the iOS 26 SDK; `.ultraThinMaterial` otherwise.

**The metaphor:** a sheet of college-ruled paper is the ground of every screen. Content lives on white sheets that lie on top of it (Natural-AI style stacked surfaces). Ink and pen do the talking; the knight shows up at moments, never as an avatar.

## Color (OKLCH → sRGB in `Theme.swift`)

| Token | Light | Dark | Role |
|---|---|---|---|
| page | #FFFFFF | #0B0D12 | The paper |
| paper-rule | #E4E7EC | #1B2536 | College-rule lines, 28pt apart (decorative, under everything) |
| margin | #F0837A | #6E3A38 | The one red margin line, in the gutter (x = 14) — never written over |
| sheet | #FFFFFF | #151922 | A sheet lying on the paper: define chat, home pull-up sheet, list rows, flashcards |
| ink | #151B24 | #E9EBEF | Primary text |
| ink-2 | #575E69 | #A1A5AB | Secondary text (≥4.5:1 on page/sheet) |
| pen | #000000 | #FFFFFF | Primary: actions, selection, current token, focus |
| on-pen | #FFFFFF | #0B1220 | Text on a pen-filled control |
| pen-wash | pen @ 10% | | Tinted surfaces: earlier tokens, WOTD card, follow-up chips |
| highlighter | #FFE244 | #D6B529 | Unused — the headword swipe was removed (it fought the word for legibility) |
| rule | #DADEE5 | #1C1F24 | Hairline dividers, and the edge on every container: sheets, cards, grouped-list sections |
| shadow | black @ 10% | | Sheet lift (radius 24) |
| right / wrong | system green / red | | Flashcard results (always paired with icon+label) |

Strategy: Restrained, monochrome. Pen ≤10% of surface. The paper rules and margin are the only decoration and they are the same on every screen. Every container carries a 1pt `rule` edge — white-on-white has no edge of its own, and the outline is what separates a sheet from the page under it.

## Typography (system fonts, Dynamic Type)

- Home input ("ghost"): SF Rounded bold 38pt, no box — placeholder in ink-2 @ 80% (large text, ≥3:1).
- Headword & wordmark: SF Rounded, bold, `.largeTitle`.
- Definition: New York serif (`.fontDesign(.serif)`), `.title3`. It's a book.
- Tokens / chips: SF Rounded semibold `.subheadline`; current token = pen fill + on-pen text, earlier tokens = pen-wash + pen text.
- Everything else: SF Pro default. One weight step between hierarchy levels.

## Layout (Natural-AI patterns, wordsword content)

- **Home:** wordmark + 2 glass icon buttons; giant ghost input on the paper; a draggable **bottom sheet** (peek 316pt, 236pt when the keyboard is up) holding Word of the day + Recent. The Word of the day card is a scrap of the same ruled paper (rules at 22pt, no margin line) with a `rule` edge, not a tinted block. Drag/tap the grabber to expand; the peek edge fades to hint there's more.
- **Define:** custom header — glass back pill + the **chain as tokens** (`sanguine › optimistic`), tap an earlier token to cut back to it; "Save chain" appears at 2+ tokens. The chat sits on a white **sheet** (top radius 28) sliding up over the paper. Bottom dock = **follow-up carousel** (Explain · Sentence · More synonyms) + one primary "Add to wordlist" capsule + a glass "+" (new word).
- **Lists (Library, wordlists, settings, add-to-wordlist):** inset-grouped rows on `sheet`, paper behind. Every row carries `.sheetRow(_:)` (or `.sheetRowButton(_:)` when it's tappable) with its place in the section — `.only` / `.first` / `.middle` / `.last` — so the section's 1pt `rule` outline runs down both sides and caps at the ends. Tappable rows zero their list insets and re-apply `SheetRowEdge.insets` inside the button, so the press wash (ink @ 5%, clipped to the row's corners) covers the whole row; SwiftUI drops the system highlight as soon as a row has a custom background.
- **Flashcards:** the card is a sheet; a 44pt knight beside the counter reacts to each answer.
- **Onboarding / account flow (splash → story → account → home):** `SplashView` (sword + slashReveal on the wordmark), `StoryView` miniatures built from the same tokens, `AccountFlow`. `CTAStyle` (filled / outlined / quiet) is the one full-width button for onboarding, the account flow and the flashcards signed-out gate — text on a pen fill is always `on-pen`.
- **First run:** splash → 3 story screens → account. Splash (~900ms) slashes the wordmark onto the paper under the sword and auto-advances. The story screens carry **miniatures built from the real components** — a book page with the word underlined in pen, the ghost input above the definition and follow-up chips, the ruled list with a flashcard lying on it — so the promise can't drift from the app. Account comes last, never before the story: it's the highest-friction ask in the app. Skip and "Maybe later" are always visible.
- **Account flow (`AccountFlow`)** is one implementation used in three places — end of onboarding, Settings, and the flashcards gate. Choice → one smart email-or-phone field → 6 code boxes over a single `.oneTimeCode` field (autofill intact) → username. The code screen restates the exact address it sent to, keeps "Change it" one tap away, and counts down the resend.
- Radius: sheets 28 (top corners), cards 18–22, chips/tokens 999. No cards inside cards.

## Voice — hold to speak (`Voice.swift`)

The home input does double duty: **tap to type, hold to speak**. `Hold to speak` sits under the ghost
input as its description line, and the hold target is an invisible catcher over the input + that line
(a long press on a live `UITextField` belongs to the loupe and paste menu; the catcher is only
hit-testable while the field is empty, so typing keeps every gesture it had).

- **The transition is one number.** `VoiceListener.hold` runs 0 → 1 across the press and *everything*
  reads it directly — header fade, sheet retreat, placeholder crossfade, the rule drawing in. So the
  change tracks the finger instead of snapping when a timer fires, and a hold released early rewinds
  from wherever it got to. The mic commits at `hold == 1` (600ms), with the engine starting at 200ms
  so no first syllable is clipped.
- **The signature move: the ruled line listens.** The hairline under the input is redrawn in `pen` as
  `ListeningRule` — a polyline over the last 56 mic samples, tapered at both ends. Silence is a
  dead-flat line, i.e. the same rule that was already there; speaking is the page coming alive. Same
  `.doodle()` stroke as every other hand-drawn mark. No mic glyph, no pulsing badge, no new metaphor.
- **Ink marks certainty.** The live hypothesis renders in the ghost type at `ink-2`; it firms to `ink`
  the moment the recogniser calls the transcript final.
- Placeholder crossfades `type a word` → `say a word` so the line never blinks empty. Header drops to
  15%, the bottom sheet slides down and fades out — voice gets the whole page.
- Long text (a phrase voice hands over, or a long typed word) steps the ghost type down 38 → 31 → 26pt
  rather than scrolling its own beginning out of view.

**Release:** one clean word → straight to the definition. Anything less certain → the text lands in
the input with the keyboard up and the candidates offered as `.primary` chips under
*"Not sure I caught that. Did you mean:"* — the same words and the same chips as the chat's
did-you-mean, so a mishearing and a misspelling resolve identically.

**Edge cases** all land in the caption row, in place of `Hold to speak`, for a few seconds: nothing
heard, permissions not yet asked, mic or speech recognition off (with `Open Settings` beside it,
stacking below via `ViewThatFits` at accessibility text sizes), recogniser unavailable. Released
before the mic commits = it was a tap, so the keyboard comes up and nothing else happens. A call or
a backgrounded app aborts the mic and navigates nowhere. A misheard-but-plausible word still routes
to `DefineView`, whose did-you-mean already handles it.

**Speech:** `SFSpeechRecognizer` with `requiresOnDeviceRecognition` wherever the device supports it,
Apple's server otherwise. The audio session is `.record` + `.duckOthers` and is only ever activated
(and handed back) when the mic actually ran — whatever they're listening to while reading ducks and
returns rather than stopping.

**Motion / haptics:** soft impact when the mic commits, rigid on a clean word, warning on a miss.
Reduced motion keeps the waveform — it *is* the "mic is live" signal — but skips the draw-in trim;
`Listening — release to define` carries the same signal as text, so motion is never the only cue.
VoiceOver can't long-press, so the input carries a **Speak a word** action that listens hands-free
until you stop talking.

## Doodles (`Doodles.swift`)

- Stroke = round caps + a faint 35% offset overdraw (a pencil that went twice) — the "grungy doodle" look, applied via `Shape.doodle(color:width:)`.
- **Sword** (`SwordDoodle`, app icon on ruled paper with a highlighter swipe under the blade). **Knight** (`KnightDoodle`) poses: idle ↗ · jab → (loading) · cheer ↑ (right / done) · slump ↘ (wrong / not found). Only the sword arm and head move, so poses tween with plain transforms.
- Where the knight appears: loading (jab loop, 420ms), empty states, flashcard reactions + Done, onboarding, "not found". Never in the chat as an avatar.

## Motion (`Motion` in Theme.swift)

- Feedback 120ms · state 220ms · reveal 350ms. `.smooth` springs, no bounce. Sheet settle: spring(0.42, damping 0.9). Slash: ease-out-expo 420ms.
- **Hero — the slash reveal:** the headword bubble is cut into the sheet by a diagonal wipe (`slashReveal`, mask + a 2pt pen line on the edge that fades), then the definition fades up (+220ms), tags stagger 40ms each (cap 8).
- Define arrival: sheet slides up 420pt (350ms) while the knight jabs.
- Bottom sheet: follows the finger, settles by projected velocity (±60pt).
- Onboarding: the splash slash (420ms), then per-story-page marks that draw when the page becomes current — the pen underline in the book, the list filling top-down. The marked-up content is always visible at rest; only the mark animates, so a page that never gets its animation still reads correctly.
- Reduced motion: every animation collapses to a crossfade / instant; the knight holds idle.

## Buttons

`CTAStyle` is the one full-width action, in three weights: **filled** (pen fill, on-pen text), **outlined** (sheet fill, 1pt rule border, ink text, ink @ 6% on press), **quiet** (ink-2, no fill). Used across onboarding, the account flow and the account prompts, so "this is the button that moves me forward" is learned once. `PressStyle` is the chip/pill press (0.96 scale, 120ms); `SurfacePressStyle` is the same beat for a tappable card (0.98 scale + ink @ 6% in the card's own shape); `SheetRowButtonStyle` is the grouped-list row press.
