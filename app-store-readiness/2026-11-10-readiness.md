# App Store readiness — wordsword — 2026-11-10

Previous report: [2026-11-02-readiness.md](2026-11-02-readiness.md). Requirements fetched today: [requirements-snapshot-2026-11-10.md](requirements-snapshot-2026-11-10.md). Listing copy: [app-store-listing.md](app-store-listing.md).

## Verdict
**Not submittable today. One blocker remains: B2, code signing. It now waits only on your paid Team ID.**

Everything else that could be done from the repo is done:
- The model-quality items from 11-01 (Q1–Q3) are fixed.
- The privacy policy matches what the code sends.
- The listing covers all four games.
- The screenshots were retaken with Haikuzy and Plexicon.

Your name choice is 2 characters over Apple's limit, so it needs one more decision (D1 below).

**Do first:** send me the paid Team ID, and refresh Xcode → Settings → Apple Accounts until the paid team appears. Xcode on this Mac still lists only your free Personal Team (`DJKZQ223JK`) and Upstory LLC (`RPH46L7S8Z`).

Approval is never guaranteed. Reviewers use their own judgment, and this audit covers what the repo shows plus the guidelines as published today.

## Requirements freshness
| Source | Status | Apple's last-updated | Fetched |
|---|---|---|---|
| App Store Review Guidelines | Fetched, full page | October 16, 2026 (before the 11-02 fetch, so no change since then) | 2026-11-10 |
| Upcoming requirements | Fetched | Newest item 2026-09-09 (unchanged) | 2026-11-10 |
| Screenshot specifications | Fetched. **New: iPhone Duo row** | Not shown | 2026-11-10 |
| Digital Goods and Services questionnaire | Fetched (first time) | Not shown | 2026-11-10 |
| Required-reason API reason codes (JSON endpoint) | Fetched. CA92.1 still listed | Not shown | 2026-11-10 |
| Third-party SDK list | Fetched. N/A: there are no third-party SDKs | — | 2026-11-10 |

**Apple-side changes since 11-02.** Neither one blocks:
- **iPhone Duo screenshots:** "Starting in April 2027, screenshots will be required for any app using the iOS 27.1 SDK or later." This build uses the iOS 26.5 SDK, so they aren't needed now. They will be the first time you build with the iOS 27.1 SDK.
- **Digital Goods and Services questionnaire:** a new App Information section. If it appears, answer **No** to "Can customers consume digital goods and services in this app?" (Word Wheel coins can't be bought). Your EU answers "remain locked for 12 months."

**Toolchain:** Xcode 26.6 with the iOS 26.5 SDK meets "Xcode 26 or later… SDK for iOS 26". The deployment target, iOS 17, meets "iOS 13 or later".

**Build check:** a Release build for `generic/platform=iOS` with `CODE_SIGNING_ALLOWED=NO` **succeeded**, both before and after this run's changes. The only warning is a localization deprecation at `PlexiconView.swift:536`, which is harmless. There's no archive yet, because signing is off.

## Since last run (2026-11-02)
**Closed (4):**
- **Q1. Model replies echo their own prompt.** Every model reply now goes through `Simplifier.tidy` (`Simplifier.swift:148`), which strips "Sure!" and "Here's a sentence using…:" preambles and wrapping quotes. Explain and sentence replies must also contain the word (`uses`, `:140`), or the existing fallback answers instead.
- **Q2. No model timeout.** Fixed by the 11-10 synonyms session: an 8-second race in `ask()`. Confirmed in code.
- **Q3. Canned sentences misuse words.** The four made-up templates are gone. With no model and no dictionary example, the chat now says "The dictionary has no example sentence for *word*" (`DefineView.swift:350`).
- **N2. Stray folders.** Not closed by anything I did, but noted again: `.github/` and `review/` are still untracked. Leave them out of every commit.

**Still open (1):**
- **B2. Signing.** Open for 8 runs. Everything else is ready, so this is now the only thing between you and an upload.

**New (3), all from new code since 11-02 (Plexicon, Haikuzy, synonym ranking). All fixed this run:**
- **N3. The privacy policy undercounted what's sent.** Synonym ranking and "Explain it differently" also send words from the definition and its synonyms to Datamuse, and Datamuse now supplies definitions too. The policy said "only the word". 5.1.1(i) needs a policy, and a policy is only worth having if it's true. **Fixed in `docs/privacy.html`, but it isn't live until you push** (see next steps).
- **N4. The listing, review notes and web pages said two games.** There are four. Fixed.
- **N5. Screenshots predated Haikuzy and Plexicon.** The Home panel's headline, "Your word of the day", no longer matched its screen. The banner animates away and the games now lead Home. Retaken and fixed.

## Blockers
### B2. Code signing is disabled  ·  can't archive or upload  ·  `project.yml:41-42`, `:46-54`
**What:** the base settings have `CODE_SIGN_IDENTITY: ""` and `CODE_SIGNING_REQUIRED: "NO"`. Debug device builds sign with the free Personal Team as `com.alexschumacher.Wordsword.dev`, without Sign in with Apple.
**Why it blocks:** an unsigned build can't be archived for distribution. The `com.apple.developer.applesignin` entitlement needs a paid team.
**Fix (on the never-touch list, so it waits for your Team ID):**
1. Remove the two base lines.
2. Set `DEVELOPMENT_TEAM: <paid ID>` and `CODE_SIGN_STYLE: Automatic`.
3. Delete the Debug `[sdk=iphoneos*]` overrides.
4. Run `xcodegen generate`.
5. Archive with `-allowProvisioningUpdates`. Xcode registers `com.alexschumacher.Wordsword` and the Sign in with Apple capability on the paid team. **Never `RPH46L7S8Z` (Upstory LLC).**

## Likely rejection — reviewer discretion
None found.

## Polish
- **P1. Cold model vs. the 8s timeout** (`Simplifier.swift:177`). In the simulator, a cold model missed the 8s window on 2 of 3 runs, and "Use it in a sentence" fell back to the honest no-example line. A real Apple Intelligence iPhone should be faster. Check it in TestFlight (see Unverified). If the first tap often falls back on your phone, prewarming the session when Define opens is the fix.
- **P2. Haikuzy has 60 haiku.** They run from Nov 10 to Jan 8, and after that winter repeats. Not a review issue, but write more before January.
- **P3. The launch-day screenshots show solved puzzles** (CLEFT, ember). That's fine for review. Those answers are day #1's only.

## Unverified
These need a real iPhone signed with the paid team, through TestFlight:
- Sign in with Apple end to end: sign in, sign out, delete account, and revoking the credential in iOS Settings.
- The mic and speech prompts, and the path when you deny them.
- Model replies on an Apple Intelligence iPhone: whether they land inside 8s (P1), and whether any preamble slips past `tidy`.
- Behaviour without Apple Intelligence. Your phone qualifies, because the model reported unavailable on it on 10-28.
- Plexicon and Haikuzy across a real midnight.

## N/A — checked, does not apply
- **3.1.1 / 3.1.2 purchases:** no `StoreKit` import, no product IDs, no paywall. The inventory's only "restore" hit is a code comment at `DefineView.swift:50`.
- **4.8 login services:** Sign in with Apple is the only login.
- **5.1.2(i) third-party AI:** the model is Apple's on-device Foundation Models, so nothing goes to a third-party AI.
- **1.2 user-generated content:** nothing passes between users. Share buttons hand your own result to the iOS share sheet.
- **Required-reason APIs:** every new `UserDefaults` site (`Haikuzy.swift:362`, `Plexicon.swift:131`) stores the app's own data, so CA92.1 still fits. The inventory's "file timestamp" hits are a function named `stat` in the stats grids, not the C API.
- **Debug hooks in Release:** every new env var (`HAIKUZY_*`, `PLEXICON_*`, `MODEL_TIMEOUT`) is inside `#if DEBUG`.
- **Third-party SDKs and manifests:** there are none. `haiku-words.txt` and `haiku-common.txt` come from ENABLE (public domain) and 12dicts, the same licences cleared on 10-17.
- **iPad:** `TARGETED_DEVICE_FAMILY: "1"`, so the app is iPhone only.
- **Tracking / ATT:** `NSPrivacyTracking` is false, and there are no tracking domains and no SDKs.

## Fixed automatically
### `Wordsword/Simplifier.swift` + `DefineView.swift`: Q1 and Q3
**Why:** 2.1(a), "obvious technical problems". The fallback was showing invented sentences and prompt echoes.
- `tidy()` runs on every model reply in `ask()`.
- `uses()` gates the explain and sentence replies.
- `sentence()` returns `nil` instead of a template, and DefineView shows the plain no-example line.
- DEBUG `selfCheck` gains three asserts, which passed on the Mac with `-Onone`.
- A DEBUG-only `MODEL_TIMEOUT` override lets the screenshot tour wait for the simulator's slow model. Release always uses 8s.

### `docs/privacy.html`, `index.html`, `support.html`: N3, N4
- The policy now names definition and synonym words as sent to Datamuse, lists Datamuse as a source of definitions, and adds Plexicon and Haikuzy progress and sharing.
- The effective date is now Nov 10, 2026.
- The landing and support pages name all four games.
- **These go live only after you push `main`.** That's on your OK.

### `app-store-listing.md`: N4 and your picks
- Name section: your pick, plus two pairings that fit 30 characters (D1).
- Category: Reference + Games → Word.
- Promo text and description: Haikuzy and Plexicon.
- Review notes: all four games and the data sources.
- Age-rating draft: the Share buttons.
- All counts recomputed by script: promo 156/170, description 1928/4000, notes 1555, keywords 96/100 bytes.

### Screenshots: N5
- 9 panels at both sizes, in `screenshots/6.3` (1206×2622) and `screenshots/6.9` (1320×2868). All are `hasAlpha: no`.
- New panels: 02 Haikuzy and 06 Plexicon. The Home panel's headline is now "Four word games, one search away".
- The tour and compositor changes are in `DebugSnapshots.swift` and `Scripts/compose-screenshots.swift`.

## Needs your decision
1. **D1. App name.** `wordsword: AI Dictionary & Games` is **32 characters**, and 2.3.7 says "App names must be limited to 30 characters." Either pairing below keeps all three search terms between the name and the subtitle:
   - **A (recommended):** name `wordsword: AI Dictionary` (24) + subtitle `Thesaurus, flashcards & games` (29).
   - **B:** name `wordsword: Dictionary & Games` (29) + subtitle `Thesaurus, flashcards & AI` (26).

   "AI" is accurate only on Apple Intelligence iPhones. Keep the description's "On supported devices…" line so it doesn't read as a 2.3.1(a) over-promise.
2. **D2. Paid Team ID.** Paste it, and I'll do B2.
3. **D3. Push.** OK to commit this run's changes and push `main`? Pushing is what puts the corrected privacy policy live on GitHub Pages.

## Next steps
Each step depends only on the steps above it. **[you]** means it's in your browser or account, and **[me]** means I do it here.

### In the codebase
1. **[you]** Send me the Team ID. Refresh Xcode → Settings → Apple Accounts until a non-"Personal Team" entry appears. If the login is stale, sign out and back in.
2. **[me]** Commit this run and push `main`, on your OK (D3). Then confirm https://schubaru.github.io/wordsword/privacy.html shows "Effective November 10, 2026".
3. **[me]** B2: edit `project.yml`, run `xcodegen`, and do a signed Release **archive**.
4. **[me, with your OK]** Upload the archive, or do it yourself from Xcode → Organizer → Distribute App. No export questions come up, because `ITSAppUsesNonExemptEncryption=false` is set.

### In App Store Connect (create the record after step 3, so the bundle ID exists)
5. **[you] New App:**
   - iOS
   - Name per D1
   - English (U.S.)
   - Bundle ID `com.alexschumacher.Wordsword`. It **can't be changed later.**
   - SKU `wordsword-ios`
6. **[you] App Information:**
   - Subtitle per D1.
   - Category: Reference primary, Games → Word secondary.
   - Privacy Policy URL https://schubaru.github.io/wordsword/privacy.html
   - Age rating: the live questionnaire. Drafts are in listing §8. Answer **Yes** to AI-generated content if it's asked.
   - Digital Goods questionnaire: **No**, if it appears.
7. **[you] App Privacy:** Data Not Collected. **Pricing:** free, all territories. **DSA trader status:** decide before you pick EU storefronts.
8. **[you] Version page:**
   - Screenshots from `screenshots/6.9`. ASC scales them down. Add `6.3` if the medium slot asks for its own.
   - Description, keywords and promo text from the listing file.
   - Support URL https://schubaru.github.io/wordsword/support.html
   - Review notes from listing §7. No demo account is needed.
9. **[you] TestFlight** on your iPhone: run every "Unverified" check. Sign in with Apple has never run end to end.
10. **[me]** Run `/app-store` again against the signed build.
11. **[you] Submit for review** with **manual release**. A first rejection is normal: reply in the Resolution Center.
