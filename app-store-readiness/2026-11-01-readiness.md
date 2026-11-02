# App Store readiness — wordsword — 2026-11-01

Previous report: [2026-10-22-readiness.md](2026-10-22-readiness.md). Requirements fetched today: [requirements-snapshot-2026-11-01.md](requirements-snapshot-2026-11-01.md). Listing copy: [app-store-listing.md](app-store-listing.md). Screenshots: [screenshots/](screenshots/).

## Verdict
**One blocker left, and it's waiting on Apple.** Code signing (B2) is the only blocker, and it clears when your Developer Program enrollment does. The privacy-policy link (B1), open since August, is closed today.

Fix the three quality items (Q1–Q3) in "Explain it differently" and "Use it in a sentence" before review. None is a rule violation, but a reviewer who taps those buttons sees them right away.

Approval is never guaranteed. Reviewers use their own judgment, and this audit covers only what the repo shows plus the guidelines as published today.

## Requirements freshness
| Source | Status | Fetched |
|---|---|---|
| App Store Review Guidelines | Fetched (read through 5.2.5) | 2026-11-01 |
| Upcoming requirements | Fetched. Newest item is still 2026-09-09 | 2026-11-01 |
| Screenshot specifications | Fetched | 2026-11-01 |
| Metadata field limits (version info, app info) | Fetched | 2026-11-01 |
| App Store search guidance | Fetched | 2026-11-01 |
| Required-reason API list | **FAILED**: client-rendered, empty body | — |

Nothing on Apple's side changed since 10-22.

**Toolchain:** Xcode 26.6 meets "Xcode 26 or later… SDK for iOS 26". A deployment target of iOS 17 meets "iOS 13 or later".

## Since last run (2026-10-22)
**Closed (1):**
- **B1, no privacy policy link (5.1.1(i)).** This was open for 5 runs. The policy is live at https://schubaru.github.io/wordsword/privacy.html (HTTP 200). Settings → About now has a **Privacy policy** row (`Wordsword/SettingsView.swift:82`).

**Still open (1):**
- **B2, code signing.** This is the 6th run it's been open. It's waiting on enrollment and nothing in the code blocks it.

**New (4), all from features shipped since 10-22:**
- Q1–Q3 are quality issues in the on-device model replies.
- N1: Linking words resembles a well-known puzzle, which matters for the metadata only. It's handled in the copy.

## Blockers
### B2. Code signing is disabled  ·  can't archive or upload  ·  `project.yml:41-42`
**What:** Release still has `CODE_SIGN_IDENTITY: ""` and `CODE_SIGNING_REQUIRED: "NO"`. Debug device builds sign with the free Personal Team, `DJKZQ223JK`, under `com.alexschumacher.Wordsword.dev`, and without Sign in with Apple.
**Why it blocks:** an unsigned build can't be archived for distribution, and Sign in with Apple needs the paid team. Signing is on the never-touch list, so I haven't changed it.
**Fix:** once enrollment clears:
1. Remove the two lines.
2. Set `DEVELOPMENT_TEAM` to the paid team ID, and drop the `[sdk=iphoneos*]` overrides in Debug.
3. Run `xcodegen generate`.
4. Run Product → Archive.

## Fix before review (quality, not a rule)
2.1(a) says "We will reject … binaries that … exhibit obvious technical problems". None of these is clearly that, but a reviewer would see all three within a minute of using the app.

### Q1. Model replies can echo their own prompt  ·  `Wordsword/Simplifier.swift:27-35`, `:97`
**What:** two examples from today's simulator runs.
- "Explain it differently" for "sanguine" began: *here's a different way to explain "sanguine" (adjective) for someone who didn't understand the original definition: Imagine you're going on a trip to a new city for the first time.* That's the model restating the instructions, plus an analogy that `firstSentences(s, 3)` cut off before it got to the meaning.
- "Use it in a sentence" began *Sure! Here's a sentence using the word "sanguine" as an adjective:*, even though the prompt says "Reply with only the sentence."

The fix below goes in `ask()`, so it covers both buttons.
**Fix:**
- Strip a leading preamble: anything up to the first colon when it contains "explain", or "here's".
- Fall back to the next non-model angle when what's left doesn't contain the word.
- Check this on a real Apple Intelligence iPhone. The simulator model may behave differently.

### Q2. A model call can hang with no fallback  ·  `Wordsword/Simplifier.swift:134`
**What:** `session.respond(to:)` has no timeout. With two simulators sharing the host's model, "Use it in a sentence" and "Explain it differently" showed nothing for more than 20 seconds. On a single simulator the reply took about 10 seconds. While it waits, the chat shows only the user's tap.
**Fix:** race the call against an 8-second timer. If the timer wins, return `nil`, so the existing fallbacks (dictionary example, then templates) take over.

### Q3. The fallback sentence templates misuse words  ·  `Wordsword/Simplifier.swift:100-104`
**What:** on iPhones without Apple Intelligence, a word with no dictionary example gets a canned line. Today the 6.9" simulator gave *"It was so sanguine that everyone in the room noticed."* That's grammatical but wrong for the word, and it's presented as a real example.
**Fix:** when there's no dictionary example, reply with a plain "No example sentence for this one yet", or offer synonyms instead. Don't make up a sentence.

### Minor: a generated definition is wrong
In the library, "ulnar" reads *"The word is a suffix that means 'related to the elbow.'"* The word isn't a suffix. The rewrite came from the definition simplifier. It's low priority, but it was nearly in a screenshot.

## Unverified
- **U1. Required-reason codes.** The page is client-rendered and came back empty for the 5th run in a row. The manifest declares `CA92.1` for UserDefaults, last verified 2026-08-23. All UserDefaults use is the app's own data, and there's no app group. **Two-minute check:** open https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api in a browser and confirm `CA92.1` still reads "only accessible to the app itself".
- **Device-only checks** (the simulator hides these):
  - Sign in with Apple, end to end, with the paid team
  - The mic plus speech permission prompts
  - Foundation Models replies on an Apple Intelligence iPhone (Q1, Q2)
  - Behavior on an iPhone *without* Apple Intelligence (Q3)

## What I changed this run
- **`docs/`**: `index.html`, `privacy.html`, `support.html` and `style.css`, live on GitHub Pages from `main:/docs`.
  - The policy is the 08-23 draft, updated for what has shipped since. Linking words and Word Wheel saves stay on the device. "Explain it differently" runs on the on-device model and sends nothing. Accounts are optional and only set a username. Sharing uses the share sheet. Contact: abschuzy@gmail.com, effective 2026-11-01.
  - Committed as `docs/` only and pushed, with your OK.
- **`Wordsword/SettingsView.swift`**: a Privacy policy row in About, between the credits and the version (B1).
- **`Wordsword/DebugSnapshots.swift`** (DEBUG only, not in Release): a `STORE_SHOTS=1` pass that walks the listing's frames with waits long enough for the model's replies.
- **`Scripts/compose-screenshots.swift`**: turns raw frames into captioned panels at both sizes. It writes opaque PNGs with no alpha.
- **Screenshots**: 7 panels × 2 sizes in `screenshots/6.3` (1206×2622) and `screenshots/6.9` (1320×2868). Every file was checked as `hasAlpha: no`.
  1. Any word, in plain English
  2. Every word you look up, kept
  3. Follow one word to the next
  4. Flashcards that make it stick
  5. Your word of the day
  6. Spell words, level after level
  7. A fresh puzzle every day

  2.3.3 allows the text overlays, and the screens are the real app. Raw frames are in `screenshots/raw/`.
- **`app-store-listing.md`**: the name, subtitle, keywords (96 of 100 bytes), promotional text, description (1,743 of 4,000), category reasoning, review notes, draft age-rating answers, App Privacy, and URLs. Every count was computed, not estimated, and it contains no competitor or trademark names.

## Needs your decision
1. **App name.** I recommend `wordsword: Dictionary & Words` (29 characters). The alternates and their search trade-offs are in the listing file. The name "wordsword" is also used by an itch.io game ([PocketGamer](https://www.pocketgamer.com/off-the-appstore/wordsword)). I found no App Store listing under it, but App Store Connect only confirms availability when you create the record.
2. **Category.** I recommend Reference as primary and Education as secondary. Games → Word is the alternate if the games end up driving installs.
3. **Q1–Q3.** Fix them before you submit (my recommendation), or ship as is.

## Next steps
### In the codebase
1. Fix Q1–Q3 in `Simplifier.swift`.
2. When enrollment clears, turn on signing (B2) and confirm Archive works.
3. Run `/app-store` again.

### In App Store Connect (start the slow ones first)
1. **Enrollment.** It's pending, and it gates everything below. Nothing to do but wait.
2. **Register the bundle ID** `com.alexschumacher.Wordsword` with the **Sign in with Apple** capability.
3. **Create the app record**:
   - Name: per decision 1
   - Primary language: English (U.S.)
   - SKU: for example `wordsword-ios`
   - Price: free, no in-app purchases
4. **App Information:**
   - Subtitle, category, and Privacy Policy URL https://schubaru.github.io/wordsword/privacy.html
   - Age rating: answer the live questionnaire yourself. There are draft answers in the listing file, and the AI-generated-text and unfiltered-definitions facts are the ones that matter.
5. **App Privacy:** Data Not Collected.
6. **Version page:**
   - Screenshots: upload `screenshots/6.9` to the 6.9" slot and `screenshots/6.3` to the 6.3" slot, in order 01–07.
   - Promotional text, description and keywords from the listing file.
   - Support URL https://schubaru.github.io/wordsword/support.html, marketing URL https://schubaru.github.io/wordsword/
7. **Review notes:** paste section 7 of the listing file. No demo account is needed.
8. **DSA trader status** if you distribute in the EU. It has been required since 2025-02-17.
9. **Archive → Validate → Upload.** `ITSAppUsesNonExemptEncryption=false` is already set, so no export questionnaire.
10. **TestFlight on your own iPhone first.** Run the device-only checks in "Unverified" before you submit.
11. **Submit**, with manual release, so you choose launch day.
