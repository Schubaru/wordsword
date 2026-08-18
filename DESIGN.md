# Design

Platform: iOS (SwiftUI). Follows system light/dark. Liquid Glass (`.glassEffect`) when built with the iOS 26 SDK; `.ultraThinMaterial` otherwise.

**The metaphor:** a sheet of college-ruled paper is the ground of every screen. Content lives on white sheets that lie on top of it (Natural-AI style stacked surfaces). Ink and pen do the talking; the knight shows up at moments, never as an avatar.

## Color (OKLCH → sRGB in `Theme.swift`)

| Token | Light | Dark | Role |
|---|---|---|---|
| page | #FFFFFF | #0B0D12 | The paper |
| paper-rule | #C9D9EE | #1B2536 | College-rule blue lines, 28pt apart (decorative, under everything) |
| margin | #F0837A | #6E3A38 | The one red margin line, in the gutter (x = 14) — never written over |
| sheet | #FFFFFF | #151922 | A sheet lying on the paper: define chat, home pull-up sheet, list rows, flashcards |
| ink | #151B24 | #E9EBEF | Primary text |
| ink-2 | #575E69 | #A1A5AB | Secondary text (≥4.5:1 on page/sheet) |
| pen | #0A46A2 | #73A5F6 | Primary: actions, selection, current token, focus |
| on-pen | #FFFFFF | #0B1220 | Text on a pen-filled control |
| pen-wash | pen @ 10% | | Tinted surfaces: earlier tokens, WOTD card, follow-up chips |
| highlighter | #FFE244 | #D6B529 | ONE meaning: the word being defined |
| rule | #DADEE5 | #1C1F24 | Hairline dividers, sheet edge |
| shadow | black @ 10% | | Sheet lift (radius 24) |
| right / wrong | system green / red | | Flashcard results (always paired with icon+label) |

Strategy: Restrained. Pen ≤10% of surface. Highlighter only behind the headword. The paper rules and margin are the only decoration and they are the same on every screen.

## Typography (system fonts, Dynamic Type)

- Home input ("ghost"): SF Rounded bold 38pt, no box — placeholder in ink-2 @ 80% (large text, ≥3:1).
- Headword & wordmark: SF Rounded, bold, `.largeTitle`.
- Definition: New York serif (`.fontDesign(.serif)`), `.title3`. It's a book.
- Tokens / chips: SF Rounded semibold `.subheadline`; current token = pen fill + on-pen text, earlier tokens = pen-wash + pen text.
- Everything else: SF Pro default. One weight step between hierarchy levels.

## Layout (Natural-AI patterns, wordsword content)

- **Home:** wordmark + 2 glass icon buttons; giant ghost input on the paper; a draggable **bottom sheet** (peek 316pt, 236pt when the keyboard is up) holding Word of the day + Recent. Drag/tap the grabber to expand; the peek edge fades to hint there's more.
- **Define:** custom header — glass back pill + the **chain as tokens** (`sanguine › optimistic`), tap an earlier token to cut back to it; "Save chain" appears at 2+ tokens. The chat sits on a white **sheet** (top radius 28) sliding up over the paper. Bottom dock = **follow-up carousel** (Explain · Sentence · More synonyms) + one primary "Add to wordlist" capsule + a glass "+" (new word).
- **Lists (Library, wordlists, settings, add-to-wordlist):** inset-grouped rows on `sheet` (`.sheetRow()`), paper behind.
- **Flashcards:** the card is a sheet; a 44pt knight beside the counter reacts to each answer.
- **Onboarding / account flow (splash → story → account → home):** `SplashView` (sword + slashReveal on the wordmark), `StoryView` miniatures built from the same tokens, `AccountFlow`. `CTAStyle` (filled / outlined / quiet) is the one full-width button for onboarding, the account flow and the flashcards signed-out gate — text on a pen fill is always `on-pen`.
- **First run:** splash → 3 story screens → account. Splash (~900ms) slashes the wordmark onto the paper under the sword and auto-advances. The story screens carry **miniatures built from the real components** — a book page with the word underlined in pen, the ghost input above the highlighter swipe and follow-up chips, the ruled list with a flashcard lying on it — so the promise can't drift from the app. Account comes last, never before the story: it's the highest-friction ask in the app. Skip and "Maybe later" are always visible.
- **Account flow (`AccountFlow`)** is one implementation used in three places — end of onboarding, Settings, and the flashcards gate. Choice → one smart email-or-phone field → 6 code boxes over a single `.oneTimeCode` field (autofill intact) → username. The code screen restates the exact address it sent to, keeps "Change it" one tap away, and counts down the resend.
- Radius: sheets 28 (top corners), cards 18–22, chips/tokens 999. No cards inside cards.

## Doodles (`Doodles.swift`)

- Stroke = round caps + a faint 35% offset overdraw (a pencil that went twice) — the "grungy doodle" look, applied via `Shape.doodle(color:width:)`.
- **Sword** (`SwordDoodle`, app icon on ruled paper with a highlighter swipe under the blade). **Knight** (`KnightDoodle`) poses: idle ↗ · jab → (loading) · cheer ↑ (right / done) · slump ↘ (wrong / not found). Only the sword arm and head move, so poses tween with plain transforms.
- Where the knight appears: loading (jab loop, 420ms), empty states, flashcard reactions + Done, onboarding, "not found". Never in the chat as an avatar.

## Motion (`Motion` in Theme.swift)

- Feedback 120ms · state 220ms · reveal 350ms. `.smooth` springs, no bounce. Sheet settle: spring(0.42, damping 0.9). Slash: ease-out-expo 420ms.
- **Hero — the slash reveal:** the headword bubble is cut into the sheet by a diagonal wipe (`slashReveal`, mask + a 2pt pen line on the edge that fades), then the highlighter draws behind the word (+140ms), definition fades up (+80ms), tags stagger 40ms each (cap 8).
- Define arrival: sheet slides up 420pt (350ms) while the knight jabs.
- Bottom sheet: follows the finger, settles by projected velocity (±60pt).
- Onboarding: the splash slash (420ms), then per-story-page marks that draw when the page becomes current — the pen underline in the book, the highlighter swipe, the list filling top-down. The marked-up content is always visible at rest; only the mark animates, so a page that never gets its animation still reads correctly.
- Reduced motion: every animation collapses to a crossfade / instant; the knight holds idle.

## Buttons

`CTAStyle` is the one full-width action, in three weights: **filled** (pen fill, on-pen text), **outlined** (rule border, pen text), **quiet** (ink-2, no fill). Used across onboarding, the account flow and the account prompts, so "this is the button that moves me forward" is learned once. `PressStyle` is the chip/pill press (0.96 scale, 120ms).
