# App Store readiness — wordsword — 2026-10-22

Previous report: [2026-10-17-readiness.md](2026-10-17-readiness.md). Requirements fetched today: [requirements-snapshot-2026-10-22.md](requirements-snapshot-2026-10-22.md).

## Verdict
**Not submittable today.** 2 blockers, 2 likely-rejection items.

The blockers are the same two that have been open since August: there's no privacy policy link in the app, and code signing is off. Both need your Apple Developer account and a hosted policy URL first. Start there.

Approval is never guaranteed. Reviewers use their own judgment, and this audit only covers what can be checked from the repo plus the guidelines as published today.

## Requirements freshness
| Source | Status | Apple's last-updated | Fetched |
|---|---|---|---|
| App Store Review Guidelines | fetched (read through 5.2.5) | not shown | 2026-10-22 |
| Upcoming requirements | fetched | newest item 2026-09-09 | 2026-10-22 |
| Screenshot specifications | fetched | not shown | 2026-10-22 |
| Third-party SDK list | fetched (86 SDKs) | not shown | 2026-10-22 |
| Required-reason API list | **FAILED**: client-rendered, empty body (doc page and TN3183) | — | — |
| Privacy manifest docs | not attempted (same renderer); manifest structure unchanged since 08-23 | — | — |

**Build check:** Release, `generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`. **BUILD SUCCEEDED** after today's fixes. That proves the code compiles. It doesn't prove an archive works, because signing is off (B2). `strings` on the Release binary finds 0 matches for "No server yet" or debug-snapshot symbols.

## Since last run (2026-10-17)
**Closed (2):**
- *Sign-in codes stubbed and shown on screen (2.1(a)).* Sign in with Apple replaced them in `3d6536d`, and the Release binary has no "No server yet" string.
- *Account-deletion work uncommitted (5.1.1(v)).* It's committed in `3d6536d`, and the tree was clean at the start of this run.

**Still open (2):**
- B1 privacy policy link: open since the first report on 2026-08-18. This is the 5th run.
- B2 code signing: open since 2026-08-18. This is the 5th run.

Both have waited this long on the same two outside steps: enrolling in the Developer Program and hosting the policy. Nothing in the code is blocking them.

**New (4), all from new code. Apple's rules haven't changed since 10-17:**
- The microphone permission text still described hold-to-speak after `1e0dd9e` replaced it with a tap mic. **Fixed today.**
- The account sheet advertises backup, sync and "word games later". Backup and sync don't exist, and the games already shipped without an account. (L1)
- A local-only account gates flashcards. This got sharper now that the account has no server side at all. (L2)
- The Word Wheel word lists aren't credited. **Fixed today.**

## Blockers
### B1. No privacy policy link inside the app  ·  5.1.1(i)  ·  `Wordsword/SettingsView.swift:79`
**What:** The About section (lines 79–87) shows API credits and the version, and that's it. A search of `Wordsword/` for "privacy" or "policy" finds nothing in any Swift file.
**Why it blocks:** "All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner."
**Fix:**
1. Fill in `[EFFECTIVE DATE]` and `[CONTACT EMAIL]` in [privacy-policy-draft.md](privacy-policy-draft.md) and host it at a public URL. GitHub Pages or a Notion public page both work.
2. Add `Link("Privacy policy", destination: URL(string: "<your URL>")!)` as a `.sheetRow(.middle)` row in the About section.

I won't add the row until the URL exists. A link to a placeholder is worse than no link.

### B2. Code signing is disabled  ·  can't archive or upload  ·  `project.yml:41-42`
**What:** `CODE_SIGN_IDENTITY: ""` and `CODE_SIGNING_REQUIRED: "NO"`, with no `DEVELOPMENT_TEAM`. Sign in with Apple also can't work without signing.
**Why it blocks:** An unsigned build can't be archived for distribution. This one is on the never-touch list, so I haven't changed it.
**Fix:**
1. Remove those two lines.
2. Add `DEVELOPMENT_TEAM: <your team ID>`.
3. Run `xcodegen generate`.
4. Run Product → Archive.

## Likely rejection: reviewer discretion
### L1. The account screen sells features that don't exist  ·  2.1(a)  ·  `Wordsword/AccountFlow.swift:99-108`
**What:** The perks list reads "Flashcards, and word games later", "Your words, backed up" and "The same words on every device". The footnote under it takes backup and sync back ("land in a later update"). The account is local-only, and Word Wheel already ships without one.
**Why it's a risk:** 2.1(a) says "other temporary content should be scrubbed before submission." A reviewer who signs in and finds no backup has an easy rejection. I'd bet this gets flagged about half the time.
**Fix:** Cut the list to what's true today, something like "Flashcards that space out your reviews" and "A username that's yours", and drop the footnote. I didn't edit this, because the pitch is tied to decision 1 below.

### L2. A login that does nothing server-side gates flashcards  ·  5.1.1(v)  ·  `Wordsword/FlashcardsView.swift:23`
**What:** Flashcards ask you to sign in, but the Apple ID, username and review history all stay on the device. Nothing about flashcards needs an account.
**Why it's a risk:** "If your app doesn't include significant account-based features, let people use it without a login." Reviewers regularly reject "registration required for non-account features." Everything else in the app works signed out, which helps.
**Fix:** This is a product decision (decision 1).

## Polish
- **Dark mode is now live but unchecked.** `preferredColorScheme` is gone, so the app follows the system. `Doodles.swift:21` (`page: Color = .white`), `FlashcardsView.swift:148,159` and the Theme shadows are hard-coded. Look at every screen in Dark before you take screenshots.
- **Fixed font sizes:** `StoryView.swift:188,192` use `.system(size: 26)`. Game tiles scale with the board, which is fine. Check the story at the largest accessibility size.

## Unverified
- **The `CA92.1` reason code for UserDefaults:** Apple's doc pages wouldn't render today. It was verified on 2026-08-23. All UserDefaults use is still the app's own data (`LastSearch`, `Auth`, `WordOfTheDay`, `WordWheelSave`). To confirm it yourself, open TN3183 in a browser, find "User defaults APIs" and check that CA92.1 is still listed.
- **A real Sign in with Apple:** this needs signing (B2) and the capability on the bundle ID. Test it on a device through TestFlight, including revoking it in iOS Settings, which should sign the app out (`WordswordApp.swift:32`).
- **Device-only checks:** mic and speech prompts, on-device speech on your model, pronunciation audio over cellular, offline launch with saved words, and the Word Wheel save surviving a relaunch.
- **Token revocation on delete:** carried from 10-17. There's no server to call Apple's revoke endpoint, so the delete dialog tells people how to remove wordsword from their Apple ID (`SettingsView.swift:15`). That's acceptable as far as I can tell, but a reviewer could ask about it.

## N/A: checked, doesn't apply
- **3.1.1 / 3.1.2 purchases:** no StoreKit import, no product IDs, no paywall. The only "restore" match (`DefineView.swift:50`) is about navigation history. Word Wheel coins are earned in the game and can't be bought.
- **4.8 login services:** the only login is Sign in with Apple. No third-party or social login.
- **Third-party SDKs:** no SPM packages and no vendored frameworks. The network calls go to dictionaryapi.dev, api.datamuse.com and the pronunciation audio URLs those return, all through plain `URLSession`.
- **Secrets:** none found.
- **Toolchain:** Xcode 26.6 with the iOS 26.5 SDK meets "Xcode 26 or later … iOS 26". The iOS 17.0 target meets "iOS 13 or later".
- **iPad:** the app target is `TARGETED_DEVICE_FAMILY: 1`, so no iPad screenshots are needed. The `1,2` in the pbxproj is the UI-test bundle only.
- **4.2 minimum functionality:** this app is well past the bar. It has a dictionary with voice input, a library, wordlists, spaced-repetition flashcards, a word of the day, and now Word Wheel. Unchanged from earlier runs.

## Fixed automatically
### `project.yml` / `Wordsword/Info.plist`: the microphone permission text matches the tap mic
**Why:** 5.1.1(ii): "Ensure your purpose strings clearly and completely describe your use of the data." The old text told people to hold the input, which the app no longer does (`HomeView.swift:415`).
```diff
-        # Hold-to-speak on the home input. Speech runs on-device when the device supports it.
-        NSMicrophoneUsageDescription: wordsword listens while you hold the input, so you can say a word instead of typing it.
+        # The mic button in Home's search field. Speech runs on-device when the device supports it.
+        NSMicrophoneUsageDescription: wordsword listens after you tap the mic, until you stop talking or tap it again, so you can say a word instead of typing it.
```
I ran `xcodegen generate`. Only `Info.plist` changed, and the pbxproj is identical.

### `Wordsword/SettingsView.swift`: removed the promise of a future feature, and credited the word lists
**Why:** 2.1(a) temporary content. The 12dicts author also asks for acknowledgment.
```diff
-  : "No account yet — your words are saved on this phone. An account adds flashcards, and backup once sync ships.")
+  : "No account yet — your words are saved on this phone. An account adds flashcards.")
-  Text("Definitions from the Free Dictionary API (dictionaryapi.dev). Spelling help and extra synonyms from Datamuse.")
+  Text("Definitions from the Free Dictionary API (dictionaryapi.dev). Spelling help and extra synonyms from Datamuse. Word Wheel's words from ENABLE and Alan Beale's 12dicts.")
```

### `app-store-readiness/privacy-policy-draft.md` §4: describes the tap mic instead of hold-to-speak
The policy has to describe what the app actually does (5.1.1(i): "how it collects that data").

## Needs your decision
1. **Do flashcards need an account?** (L1, L2)
   - **Ungate them (my recommendation).** Accounts then only hold a username until sync exists. Or drop accounts from v1 entirely. That removes the risk under 5.1.1(v), the token-revocation question, a capability on the bundle ID, and review-note explanations.
   - **Keep the gate.** Then rewrite the perks to what's true (L1). Have one sentence ready for review notes: "Sign in with Apple; any Apple ID works. The account unlocks flashcards." Expect some chance of a 5.1.1(v) back-and-forth.

## Next steps
### In the codebase
1. Decide decision 1, then trim `AccountFlow.swift:99-108` either way.
2. Once the policy URL is live, add the Privacy policy row (B1).
3. Once your team ID exists, turn signing on and confirm Archive works (B2).
4. Check dark mode on every screen, then take screenshots.
5. Commit, then run `/app-store` again.

### In App Store Connect (start the slow ones first)
1. **Enroll in the Apple Developer Program.** It can take a day or more to activate, and it gates B2 and Sign in with Apple. *Start today.*
2. **Host the privacy policy** and keep the URL. It gates B1 and the metadata field. *Start today.*
3. Register the bundle ID `com.alexschumacher.Wordsword`. Turn on Sign in with Apple, unless decision 1 drops accounts.
4. Create the app record: name, primary language, SKU. Free, no in-app purchases.
5. App Privacy labels: **Data Not Collected** is accurate for first-party code. Lookups send only the word to dictionaryapi.dev and Datamuse, nothing is tied to a user, and there's no tracking. The privacy policy covers voice going to Apple on devices that can't do on-device recognition.
6. Age rating: answer honestly. The definitions come unfiltered from a third-party API, and the Word Wheel lists have a slur blocklist.
7. Screenshots: at least one **1206×2622 or 1179×2556** portrait, no alpha. Show the library, a definition, flashcards and Word Wheel.
8. Review notes:
   > No login is needed for most of the app. Sign in with Apple (any Apple ID) unlocks flashcards [omit if ungated]. Delete account: Settings → You → Delete account. Voice: tap the mic in the search field. Definitions come from dictionaryapi.dev; synonyms from Datamuse.
9. Set your EU trader (DSA) status if you distribute in the EU.
10. Archive → Validate → Upload, then **install from TestFlight on your own iPhone** and run the device-only checks in "Unverified" before you submit.

## Update, later on 2026-10-22: L1 and L2 fixed in code

You chose to ungate flashcards and keep accounts.
- **L2 closed:** `FlashcardsView` no longer checks `auth`. The account gate view and its sheet are gone. The Library row no longer says "needs an account".
- **L1 closed:** the account screen is a headline ("Make it yours.") plus one line: "Sign in with Apple and pick a username. Everything works without an account, and your words stay on this phone either way." The four perks (backup, sync, "word games later") and the footnote that took them back are gone. The username step no longer says the app "says hi". It doesn't, because the name only shows in Settings.
- **Related copy:** the Settings footer when signed out reads "No account yet. Everything works without one…". The sign-out dialog no longer says flashcards lock.
- **Verified:**
  - Release build succeeds.
  - Snapshot tour on the iPhone 17 Pro simulator: `05-account-choice` shows the new copy, and `11-flashcards-signed-out` opens a deck ("1 of 13") with no account.
- **Review notes, simplified:** no login is needed for anything. Sign in with Apple is optional and only sets a username. Delete account: Settings → You → Delete account.
- **What's left:** B1 (privacy policy link) and B2 (signing). The account now holds nothing but a username. That's fine under 5.1.1(v) because it's optional. A reviewer might still ask why it exists, so the review-notes line above answers that up front.
