# Design

Platform: iOS (SwiftUI). Follows system light/dark. Liquid Glass (`.glassEffect`) when built with the iOS 26 SDK; `.ultraThinMaterial` otherwise.

**The metaphor:** a sheet of college-ruled paper is the ground of every screen. Content lives on white sheets that lie on top of it (Natural-AI style stacked surfaces). Ink and pen do the talking; the knight shows up at moments, never as an avatar.

## Color (OKLCH → sRGB in `Theme.swift`)

| Token | Light | Dark | Role |
|---|---|---|---|
| page | #FFFFFF | #0B0D12 | The paper |
| paper-rule | #E4E7EC | #1B2536 | College-rule lines, 28pt apart and scaled with Dynamic Type (under everything — but on Home they are a grid, see Layout) |
| margin | #F0837A | #6E3A38 | The one red margin line, in the gutter (x = 14) — never written over |
| sheet | #FFFFFF | #151922 | A sheet lying on the paper: define chat, home pull-up sheet, list rows, flashcards |
| ink | #151B24 | #E9EBEF | Primary text |
| ink-2 | #575E69 | #A1A5AB | Secondary text (≥4.5:1 on page/sheet) |
| pen | #000000 | #FFFFFF | Primary: actions, selection, current token, focus |
| on-pen | #FFFFFF | #0B1220 | Text on a pen-filled control |
| pen-wash | pen @ 10% | | Tinted surfaces: earlier tokens, follow-up chips |
| highlighter | #FFE244 | #D6B529 | Unused — the headword swipe was removed (it fought the word for legibility) |
| rule | #DADEE5 | #1C1F24 | Hairline dividers, and the edge on sheets and cards |
| edge | #C3C8D1 | #343B48 | The outline on list cards (Library, wordlists, Settings): a step darker than `rule` so white rows read off the white paper |
| shadow | black @ 10% | | Sheet lift (radius 24) |
| right / wrong | system green / red | | Flashcard results (always paired with icon+label) |

Strategy: Restrained, monochrome. Pen ≤10% of surface. The paper rules and margin are the only decoration and they are the same on every screen. Every container carries a 1pt `rule` edge — white-on-white has no edge of its own, and the outline is what separates a sheet from the page under it.

## Typography (system fonts, Dynamic Type)

- Search field: system `.body` (17pt regular), the system search bar's size and weight — placeholder in ink-2 @ 80%. The headword's rounded bold belongs to the word once it's looked up, not to the field you type it into.
- Headword & wordmark: SF Rounded, bold, `.largeTitle`.
- Definition: New York serif (`.fontDesign(.serif)`), `.title3`. It's a book.
- Pronunciation: SF Rounded semibold `.footnote` at ink-2 — `SANG-gwin`, quiet enough to skip.
- Tokens / chips: SF Rounded semibold `.subheadline`; current token = pen fill + on-pen text, earlier tokens = pen-wash + pen text.
- Everything else: SF Pro default. One weight step between hierarchy levels.

## Layout (Natural-AI patterns, wordsword content)

- **Home:** the knight (`KnightMark`, 44pt, VoiceOver "wordsword") + 2 glass icon buttons — he swings once when you come back from a word you typed or said (not a tapped one; skipped under Reduce Motion); the paper under him is the page's free space, and it opens on the games: a `Play with words` header (rounded `.title3` semibold, `ink`, two rules) and one `GameCard` per game (`paperContent` in `HomeView.swift`). **Word of the day** is a quiet banner, not writing on the page (`WordOfTheDayBanner` in `WordOfTheDay.swift`): it floats over the header on each open — a `sheet` card, the 1pt `rule` edge, radius 22, a two-layer shadow (tight contact + soft lift) — holding the word (rounded bold `.title3`), its respelling (`.pron`, `ink-2`) and its one-sentence meaning in Define's serif (`.subheadline`, `ink-2`, two lines). No date, no label. Two icon actions in its corner: the speaker (says it, `pen` while sounding) and an `xmark`. A tap anywhere else searches the word exactly like a typed one; the ✕, a flick up, or that tap puts it away until the next day's word (`wotd.dismissedOn`). While it shows, the header is hidden under it and both the paper and the expanded sheet start below it, so the search field is never covered. The meaning is the banner's own cached sentence (fetched once and `Simplifier`-ed, UserDefaults `wotd.meaning.<word>`), falling back to the library's one-liner; offline it reads "Tap to find out what it means." Below, a draggable **bottom sheet** that *is* the search. The **search field is pinned at the top of the sheet** (system body type, 44pt tall, `sheet` fill, the 1pt `rule` edge every container wears, turning `pen` while focused; magnifier in `ink-2`; trailing is the mic while the field is empty and the clear button once it isn't, like the system search bar; no submit button — the keyboard's "go" does it), then the recent words newest first with no dividers between them — whitespace separates rows, the sheet draws no rules — ending in a quiet "All N words" line. The **previous word is the first row**, no special treatment — the same row as every other word, plus a `from sanguine › optimistic` footnote when it ends a chain; tapping it resumes that chain. Home opens expanded with the field focused; focusing the field (a tap, a deep link, a voice miss) opens the sheet to just under the header, losing focus leaves it where it is — a scroll that dismissed the keyboard mid-list must not snap the list away — and the handle is how it goes down. The sheet rides above the keyboard by itself (its container shrinks with it), so nothing is choreographed out of the keyboard's way any more.
- **The rules are a baseline grid, not wallpaper (Home).** Every line written on the paper — the games header, anything else in `paperContent` — is a whole number of college rules tall with its baseline sitting on the rule that closes it, so text is written *on* the paper instead of floating over it. The rules are phased to the top of that block (measured, since the safe area differs per device) rather than the block being nudged onto them, and the rule spacing scales with Dynamic Type so the alignment survives every text size. `.onRule(_:spacing:)` in `Theme.swift` is the whole mechanism. The sheet draws no rules of its own; the one line it writes on (the hint under the search field) draws its own hairline at the footnote's baseline, measured from the font, so the descenders stay inside the row. The top-bar buttons sit above the grid — they're chrome — but the title is writing and lands on a rule (see Headers).
- **Pronunciation:** the respelling sits on its own line directly under the headword (2pt gap — it
  belongs to the word, not to the answer, so it rides the slash in rather than fading with the
  definition). Tapping the speaker beside it says the word. Shown on Define and on the flashcard
  front; hidden entirely when the respelling matches the spelling, since "sit" → "sit" teaches
  nothing. On the flashcard the speaker sits in the card's top-trailing corner, *outside* the flip
  button — a card's one tap is "flip" and stays that way.
- **Define:** custom header — glass back button + the **chain as tokens** (`sanguine › optimistic`), tap an earlier token to cut back to it; "Save chain" appears at 2+ tokens. The chat sits on a white **sheet** (top radius 28) sliding up over the paper. Bottom dock = **follow-up carousel** (Explain · Sentence · More synonyms) + one primary "Add to wordlist" capsule + a glass "+" (new word).
- **Lists (Library, wordlists, settings, add-to-wordlist):** each section is a floating card on the paper: `sheet` fill, the 1pt `edge` outline, a 26pt continuous corner (iOS 26's own section corner), and a two-layer shadow (contact: black 5%, radius 1, y 1; lift: black 8%, radius 8, y 4). No dividers between rows: whitespace separates them, as on Home. The lists are `.grouped`, not `.insetGrouped`, because the inset style clips each section to its rounded shape and would cut the shadow off, so `.sheetRow(_:)` / `.sheetRowButton(_:)` draw the card themselves, 16pt in from the screen edge. Every row passes its place in the section (`.only` / `.first` / `.middle` / `.last`), so the outline and shadow run down both sides and close at the ends. List cells clip to their bounds, so the first and last rows leave room for the shadow inside themselves (10pt above, 16pt below); `.listSectionSpacing(12)` takes that back out of the gap between sections. Section headers and footers wear `.sheetSectionLabel()` so they line up with the text inside the card. Tappable rows zero their list insets and re-apply the row's insets inside the button, so the press wash (ink @ 5%, clipped to the card's corners) covers the card; SwiftUI drops the system highlight as soon as a row has a custom background.
- **Flashcards:** the card is a sheet; a 44pt knight beside the counter reacts to each answer.
- **Onboarding / account flow (splash → story → account → home):** `SplashView` (sword + slashReveal on the wordmark), `StoryView` miniatures built from the same tokens, `AccountFlow`. `CTAStyle` (filled / outlined / quiet) is the one full-width button for onboarding, the account flow and the flashcards signed-out gate — text on a pen fill is always `on-pen`.
- **First run:** splash → 3 story screens → account. Splash (~900ms) slashes the wordmark onto the paper under the sword and auto-advances. The story screens carry **miniatures built from the real components** — a book page with the word underlined in pen, the ghost input above the definition and follow-up chips, the ruled list with a flashcard lying on it — so the promise can't drift from the app. Account comes last, never before the story: it's the highest-friction ask in the app. Skip and "Maybe later" are always visible.
- **Account flow (`AccountFlow`)** is one implementation used in three places — end of onboarding, Settings, and the flashcards gate. Choice → Sign in with Apple → username. One "Continue with Apple" button covers sign up and sign in (Apple doesn't distinguish them), clipped to the same capsule as `CTAStyle`; name scope only, no email. A cancelled Apple sheet says nothing; any other failure shows one red line under the button. The username step is skipped for a returning account that already has one, and prefilled from Apple's first name on a first sign-in.
- Radius: sheets 28 (top corners), cards 18–22, grouped-list sections 26, chips/tokens 999. No cards inside cards.

## Headers (`PaperScreen` in `Theme.swift`)

No screen uses the system navigation bar. It floats its title over the ruled grid with no way to put
it *on* one, and it can't hold the app's glass buttons — so every pushed screen wears the same
custom header instead, via `.paperScreen(_:trailing:)`.

- **A row of glass icons, then the title.** Back leads (`chevron.left`), actions trail. Nothing is a
  word: `Practice` on a wordlist is the flashcards glyph Library already uses for that row, and the
  add-to-wordlist sheet's `Done` is an `xmark` (nothing to commit — every toggle is already saved —
  so its one control just closes it). Icon-only means a VoiceOver label on every one.
- **The title is written on the paper**, two rules tall with its baseline on the rule that closes it
  — the same grid the home input writes on, so a screen title reads like a headword rather than
  chrome. It's static: no large-title collapse on scroll, because a title that slides off the rule
  it sits on is worse than one that stays. One rule of clearance follows it: the baseline *is* the
  row's bottom edge, so without it the descenders and the screen's first row (a list's section
  header, say) share a band and collide once the list scrolls.
- **The paper is phased to the title, not the title nudged onto the paper.** The gap between them is
  the top safe area (per device) plus the button row, so both ends are measured in the same global
  space and the difference sets `topInset`. That lands identically on a pushed screen (paper starts
  at the top of the screen) and in a sheet (paper starts at the top of the sheet), and it survives
  every Dynamic Type size because the rule spacing scales with the text.
- **Swipe-back comes back with it.** Hiding the nav bar takes the interactive pop gesture along, and
  that's the one navigation move people make without looking — `.swipeBack()` hands the same
  recogniser back, refusing to start at the root so the stack can't wedge.

## Pronunciation (`Pronounce.swift`)

Both halves ride on requests the app already makes, so saying a word costs no extra round trip.

- **The respelling is computed, not fetched.** Datamuse returns Arpabet (`S AE1 NG G W IH0 N`) on the
  same `md=` call that fetches the senses — `dp` → `dpr`. `Arpabet.respell` turns it into newspaper
  style: stressed syllable in caps, hyphens between, e.g. `SANG-gwin`. Near-total coverage, and it's
  the reliable source of the two (dictionaryapi.dev 502s; Datamuse doesn't).
- **Syllables break onset-maximal, with one correction.** The longest legal onset goes to the second
  syllable (`NG G W` → `ng` | `gw`), *except* that a stressed lax vowel keeps a coda — otherwise
  "dynamic" breaks `dy-NA-mik`, which reads as "nay". `Arpabet.selfCheck()` pins both rules.
- **Audio is a recording when there is one, the system voice when there isn't.** dictionaryapi.dev
  returns an mp3 URL in `phonetics[]` on the call already in flight; `Speaker` plays it, and falls
  back to `AVSpeechSynthesizer` otherwise — so the speaker is never a dead button. Same session
  discipline as `VoiceListener`: `.playback` + `.duckOthers`, activated only when something actually
  plays and handed straight back.
- **Only ever on a tap.** `DefineView` re-mounts its headword whenever a chain is resumed; playing on
  appear would speak at someone who didn't ask. Prefetch on appear is fine — it's silent.
- **Persisted as tags**, `kind: "pron"` / `"audio"` — the extensible metadata system in `Models.swift`,
  so no SwiftData migration. Words saved before this existed get filled in on their next lookup
  (capped at 2s, so an absent network can't delay a word meant to open instantly and offline) and
  as each flashcard comes up.

## Voice — the mic in the search field (`Voice.swift`)

**Tap the mic to speak.** It sits at the trailing end of the empty field, where the system search bar
keeps its dictation mic. Tap it and it listens hands-free (`listenHandsFree`) until you stop talking
(1.4s of quiet after the first word) or tap it again (`finish()`); it gives up after 8s. While it
listens the glyph is `mic.fill` in `pen` — pen marks the live thing — and its label reads "Stop
listening". (Hold-to-speak and its `Hold to speak` line are retired: a hidden gesture needed a
caption to be found, and the caption cost the sheet a row.)

- **The transition is one number.** `VoiceListener.hold` runs 0 → 1 over 600ms and *everything*
  reads it directly — header fade, the list under the field receding, placeholder crossfade, the
  line drawing in. The mic commits at `hold == 1`, with the engine starting at 200ms so no first
  syllable is clipped.
- **The signature move: a line that listens.** Under the field, a line is drawn in `pen` as
  `ListeningRule` — a polyline over the last 56 mic samples, tapered at both ends. Silence is a
  dead-flat line; speaking is the page coming alive. Same `.doodle()` stroke as every other
  hand-drawn mark. Under it, `Listening — tap the mic when you're done`, so motion is never the only
  signal. At rest the row isn't there at all.
- **Ink marks certainty.** The live hypothesis renders in the field's type at `ink-2`; it firms to
  `ink` the moment the recogniser calls the transcript final.
- Placeholder crossfades `type a word` → `say a word` so the line never blinks empty. Header and the
  paper drop to 15%, the list under the field fades out — voice gets the field and its line.

**Release:** one clean word → straight to the definition. Anything less certain → the text lands in
the input with the keyboard up and the candidates offered as `.primary` chips under
*"Not sure I caught that. Did you mean:"* — the same words and the same chips as the chat's
did-you-mean, so a mishearing and a misspelling resolve identically.

**Edge cases** all land in a caption row under the field, for a few seconds: nothing
heard, permissions not yet asked, mic or speech recognition off (with `Open Settings` beside it,
stacking below via `ViewThatFits` at accessibility text sizes), recogniser unavailable. Stopped
before the mic commits = nothing heard yet, so the keyboard comes up and nothing else happens. A call or
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
- **Word of the day, once a day:** the first time the paper is actually in view each day (the sheet covers it at launch, so it fires when the sheet goes down, or on returning to the app with the paper showing), the knight winds up and the word is slashed onto the page on his strike (`slashReveal`, `Motion.slash`) with a rigid tap, the pen underline draws in (+300ms), and the meaning comes up (+500ms, `Motion.reveal`). `wotd.writtenOn` remembers the day; every other visit it's already written. That swing replaces the come-back-from-a-word swing so he never swings twice. Reduce Motion: always written, no swing.
- Bottom sheet: follows the finger, settles by projected velocity (±60pt).
- Onboarding: the splash slash (420ms), then per-story-page marks that draw when the page becomes current — the pen underline in the book, the list filling top-down. The marked-up content is always visible at rest; only the mark animates, so a page that never gets its animation still reads correctly.
- Reduced motion: every animation collapses to a crossfade / instant; the knight holds idle.

## Buttons

`CTAStyle` is the one full-width action, in three weights: **filled** (pen fill, on-pen text), **outlined** (sheet fill, 1pt rule border, ink text, ink @ 6% on press), **quiet** (ink-2, no fill). Used across onboarding, the account flow and the account prompts, so "this is the button that moves me forward" is learned once. `PressStyle` is the chip/pill press (0.96 scale, 120ms); `SurfacePressStyle` is the same beat for a tappable card (0.98 scale + ink @ 6% in the card's own shape); `SheetRowButtonStyle` is the grouped-list row press.

`GlassIcon` is the one top-bar button — a 44pt circle of glass around an `ink` symbol, Liquid Glass on the iOS 26 SDK and `.ultraThinMaterial` below it. Home's library and settings, Define's back, and the back and actions on every pushed screen are all this button, so "the round glass thing is a top-bar action" is learned once. 44pt whatever the glyph: that's the tap target.

## Games (`Games/`)

Games are the first thing on the Home paper (`GamesEntry`): a `Play with words` header written on
a rule (the hub is hidden for now, so it's not a link), then **one `GameCard` per game**, full width, stacked. Every game wears the
same card — its own doodle (48pt, scaled), its name in rounded `.headline`, where you are in it
(`Level 5`) in `ink-2`, a chevron — and a tap goes straight into the game. The card is a sheet lying
on the paper: `sheet` fill, 1pt `rule` edge, radius 20, a soft lift (radius 16, y 6), three rules
tall with its bottom edge resting on a rule. Each game gets a doodle in `Doodles.swift` drawn in the
knight's stroke; Word Wheel's (`WheelDoodle`) is the wheel with five letters and the pen line
spelling a word across four of them. `GamesHubView` lists each game as a grouped row,
plus **Words found** — every word a game has turned up, newest first, each a button into Define.
That is the rule for every game here: *a word you find is a word you can look up.*

**Word Wheel** (`WordWheelView`, logic in `WordWheel`, levels in `WordWheelLevels`, numbers in
`WordWheelRules`, progress in `WordWheelSave`):

- **The wheel is a round sheet** lying on the paper (rule edge, shadow). Letters sit on its rim in
  SF Rounded bold; a connected letter takes the current-token treatment (pen fill, on-pen text,
  1.08 scale) and the line between letters is the `.doodle()` pen stroke, running on to the fingertip.
  Dragging back onto the previous letter undoes the last one. Release with three or more letters submits.
- **The capsule** above the wheel shows the word being spelled (pen fill, `.headword`, uppercase —
  these are game pieces, not headwords). A found word lifts 8pt and fades; an unknown one shakes
  ±6pt; an already-found one wobbles ±2pt. Captions ("Already found", "Not a word I know",
  "+15 — bonus word", "Find a few more words first") land on the rule under the board for ~2s.
- **The board** is tiles on the paper: sheet fill + 1pt rule edge, blank until found; letters write
  in 40ms apart (the tag stagger). A hint-revealed tile sits on pen-wash so it reads as "given".
  Hint = tap the lightbulb, then any blank tile (blanks get a pen-wash wash and a pen edge while picking).
- **Chips:** "N bonus" (leading, opens the bonus-word sheet) and "×2" (trailing, only while a streak
  tier is live). A broken streak just removes the chip — nothing turns red, no nagging.
- **Header:** back glass icon · 44pt knight (cheer on a word, slump on a miss, like flashcards) ·
  coin pill (a doodled coin + count on pen-wash). Level complete: knight cheer at 96pt on a sheet
  sliding up from the bottom with the coin tally and one `CTAStyle` "Next level".
- **Haptics:** `.selection` per letter, rigid on a board word, soft on a bonus or repeat, warning on
  a miss, success on level complete. Reduced motion collapses everything to crossfades; haptics stay.
- **VoiceOver:** the wheel is one element with a "Type a word" action (the typed word must still come
  from the wheel's letters); every tile and chip is labelled; captions are announced.
- **Levels are generated, not authored** — see `WordWheelLevels.swift`. Level N is the same on every
  phone forever; ten 4-letter levels, ten 5-letter, then 6 and 7 alternate; every level's seed word
  uses all its letters. Word lists are public domain (ENABLE, 12dicts) and rebuilt by
  `Scripts/make-wordlists.py`.
