# wordsword

Dictionary + thesaurus that keeps your words. Type a word → plain-English definition in a tap-only chat → it's saved to **All** → file it into **wordlists** → review with spaced-repetition **flashcards**.

## Run it

```bash
xcodegen generate        # only after adding/removing files (brew install xcodegen)
open Wordsword.xcodeproj # then ⌘R on any iPhone simulator
```

Or from the CLI:

```bash
xcodebuild -project Wordsword.xcodeproj -scheme Wordsword \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -derivedDataPath build build
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Wordsword.app
xcrun simctl launch booted com.alexschumacher.Wordsword
```

## How it's put together

| File | What it owns |
|---|---|
| `Wordsword/Models.swift` | SwiftData: `Word`, `Tag` (open `kind` strings — pos, synonym, anything later), `Wordlist`; SM-2-lite spaced repetition |
| `Wordsword/Dictionary.swift` | Datamuse (frequency-ordered senses, spelling suggestions, synonyms) + dictionaryapi.dev (examples, fallback). Both free & keyless |
| `Wordsword/Simplifier.swift` | The wordsword voice. Apple Foundation Models on-device when available (iOS 26+), honest heuristics otherwise |
| `Wordsword/DefineView.swift` | The contained chat on a white sheet over the paper: chain-as-tokens header, slash-reveal headword + highlighter, follow-up carousel + Add to wordlist, synonym chips, Save chain |
| `Wordsword/HomeView.swift` | Wordmark/library/settings · giant ghost input on ruled paper · pull-up `BottomSheet` with word of the day + recent words |
| `Wordsword/Doodles.swift` | Hand-drawn things: `Paper` (college rule), `SwordDoodle` (icon/mark), `KnightDoodle` (mascot poses), `slashReveal` |
| `Wordsword/FlashcardsView.swift` | Flip cards, Knew it / Didn't know, missed cards return in-session |
| `Wordsword/LibraryView.swift` | All words, wordlists, add-to-wordlist sheet (Spotify-style) |
| `Wordsword/OnboardingView.swift` + `SplashView` / `StoryView` / `AccountFlow` / `Auth.swift` | Splash → 3 story pages → sign in / create account (email or phone + code, username; local stub) |
| `Wordsword/Theme.swift` | DESIGN.md tokens, motion constants, `PaperBackground`, `sheetSurface`, `Wordmark`, `DoodleStroke`, glass helper |
| `Wordsword/DebugSnapshots.swift` | DEBUG-only: `SHOTS_DIR=… ` launch walks every screen and saves PNGs |

Deep links: `wordsword://define` focuses the input; `wordsword://define?word=x` opens the chat — this is the future widget's entry point.

Design language: PRODUCT.md + DESIGN.md. Every screen is a sheet of college-ruled paper; content sits on white sheets on top (Natural-AI-style layout). Ballpoint-blue pen for actions, one yellow highlighter meaning (the word being defined), serif definitions, SF Rounded headwords, a doodle knight at moments (loading, empty, flashcard results). App icon = a doodle sword. Regenerate the icon / preview the doodles with the macOS script in `scratch/render` (see DESIGN.md → Doodles).

## Deliberate v1 ceilings

- Foundation Models needs the iOS 26 SDK/device; on older setups the sentence/explain replies use templates (`Simplifier.swift`).
- Onboarding stores contact/username in `UserDefaults` — no server. Wire Supabase when accounts matter.
- Word of the day is a curated list in `WordOfTheDay.swift` — edit freely, order = schedule.
