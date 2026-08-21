# App Store readiness — wordsword — 2026-08-18

## Verdict

**Not submittable today. 5 blockers, 3 likely-rejection items, 6 polish items.**

The build itself is in good shape — a Release build for real iOS hardware compiles clean, there
are no third-party SDKs to chase manifests for, no hardcoded secrets, no force unwraps, and the
network layer already distinguishes offline from unavailable from not-found. What blocks you is
not code quality. It is that the account system is a local stand-in that prints the verification
code on screen, and that three required disclosures (account deletion, in-app privacy policy, one
privacy-manifest value) do not exist yet.

**Do first:** decide whether v1 ships with accounts at all. Three of the five blockers exist only
because the app supports account creation. Shipping v1 without the account flow closes them all
and is a smaller change than building a real auth backend.

One correction to the brief this audit was run under: **this app has no in-app purchases,
no StoreKit code, and no paywall.** Nothing in `Wordsword/` imports StoreKit or references a
product identifier. Guidelines 3.1.1 and 3.1.2 therefore do not apply to this binary, and every
3.1.x check below is marked N/A rather than passed.

Approval is never guaranteed — reviewers exercise judgment, and this audit covers what is
checkable from the repo plus the guidelines as published today.

## Requirements freshness

| Source | Status | Fetched |
|---|---|---|
| App Store Review Guidelines | fetched | 2026-08-18 |
| Upcoming requirements | fetched | 2026-08-18 |
| Privacy manifest structure | fetched | 2026-08-18 |
| **Required-reason API reason codes** | **FAILED — Apple's docs render client-side; 4 URLs tried, all returned empty** | — |
| Third-party SDK manifest list | fetched | 2026-08-18 |

Full extracts in [requirements-snapshot-2026-08-18.md](requirements-snapshot-2026-08-18.md).

**Build check:** `xcodebuild -configuration Release -destination 'generic/platform=iOS'` →
**BUILD SUCCEEDED**, unsigned. Re-verified after the automatic fixes. Archiving will still fail
until signing is configured — see B5.

---

## Blockers — will be rejected, or cannot upload at all

### B1. The verification code is printed on screen in the shipping build · Guideline 2.1(a) · `Wordsword/AccountFlow.swift:354`

**What:** `Auth.sendCode` invents a six-digit code locally and hands it back through
`auth.pendingCode` ([Auth.swift:118](../Wordsword/Auth.swift:118)). `AccountFlow` then renders it:
`Label("No server yet — your code is \(pending)", …)`. This is **not** inside `#if DEBUG` — the
`#if DEBUG` block in that file is at line 73 and covers snapshot automation only. It is in the
Release binary I just built.

**Why it blocks:** 2.1(a) — "placeholder text, empty websites, and other temporary content should
be scrubbed before submission … include demo account info (and turn on your back-end service!) if
your app includes a login." A login screen that tells you your own code is the canonical example of
a back-end that is not turned on.

**Fix:** one of — (a) ship v1 with no account flow, (b) stand up real code delivery before
submitting, or (c) keep the flow behind `#if DEBUG` and hide it from Release. (a) is the smallest
diff and also closes B2 and B4.

### B2. No in-app account deletion · Guideline 5.1.1(v) · `Wordsword/SettingsView.swift:34`

**What:** the only account action in Settings is "Sign out"
([SettingsView.swift:34-37](../Wordsword/SettingsView.swift:34)), which sets `isSignedIn = false`
and keeps the stored identifier ([Auth.swift:149](../Wordsword/Auth.swift:149)). "Clear all my
words" deletes SwiftData content, not the account. I searched every Swift file for `deleteAccount`,
`delete account`, and `remove account` — no match.

**Why it blocks:** 5.1.1(v), verbatim — "If your app supports account creation, you must also offer
account deletion within the app." The app supports account creation
([AccountFlow.swift:161](../Wordsword/AccountFlow.swift:161)), so the requirement is triggered.

**Fix:** add a "Delete account" row in the Settings "You" section with a confirmation, clearing the
identifier, username, and signed-in flag. Not auto-fixed: what deletion should do to the user's
saved words is a product decision, and getting it wrong destroys data.

### B3. No privacy policy link inside the app · Guideline 5.1.1(i) · `Wordsword/SettingsView.swift:66`

**What:** the About section credits dictionaryapi.dev and Datamuse but contains no privacy policy
link. No URL to a policy exists anywhere in the repo.

**Why it blocks:** 5.1.1(i), verbatim — a link is required in App Store Connect metadata **"and
within the app in an easily accessible manner."** Both, not either. This applies even to a local-
first app: 5.1.2(i) requires disclosing where data goes, and every word you look up is sent to two
third-party APIs.

**Fix:** publish a privacy policy at a real URL, then add a row in Settings → About linking to it.
The policy must name dictionaryapi.dev and Datamuse as recipients, say what is sent (the search
term), state retention, and describe how to request deletion. Not auto-fixed — there is no URL to
link to, and inventing one is worse than the gap.

### B4. Privacy manifest has no reason code for UserDefaults · Privacy manifest requirement (since 1 May 2024) · `Wordsword/PrivacyInfo.xcprivacy:17`

**What:** the app reads and writes `UserDefaults.standard`
([Auth.swift:95](../Wordsword/Auth.swift:95)), which is a required-reason API. I created
`PrivacyInfo.xcprivacy` this run and wired it into Copy Bundle Resources, but left
`NSPrivacyAccessedAPITypeReasons` as an empty array.

**Why it blocks:** since 1 May 2024, reason values must be valid codes for the category. **The
reason-code list could not be fetched this run** — Apple's documentation renders client-side and
four URLs returned empty. Guessing gets you ITMS-91055 (invalid reason) instead of ITMS-91053
(missing entry): same rejection, slower.

**Fix — 2 minutes, you must do this by hand:** open
<https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api>
in a browser, find the entry for `NSPrivacyAccessedAPICategoryUserDefaults`, and paste its valid
code into the empty `<array/>` at line 17. There is exactly one value to add.

### B5. Code signing is disabled — `Product > Archive` cannot succeed · cannot upload · `project.yml:28`

**What:** `CODE_SIGN_IDENTITY: ""` and `CODE_SIGNING_REQUIRED: "NO"`, with no `DEVELOPMENT_TEAM`
anywhere. Correct for simulator work, fatal for archiving. The unsigned Release build I ran proves
the code compiles for device; it does not prove the app can be archived.

**Why it blocks:** an unsigned archive cannot be uploaded to App Store Connect.

**Fix — yours, not mine (signing is on the never-touch list):** enroll in the Apple Developer
Program if you have not, then set `DEVELOPMENT_TEAM` in `project.yml` and let Xcode manage signing
automatically. Do this in `project.yml`, not in Xcode's UI — see the note under "Fixed
automatically" about the generated project.

---

## Likely rejection — reviewer discretion

### L1. Unfiltered third-party dictionary content and the age rating · Guidelines 1.1.x / age rating · `Wordsword/Dictionary.swift:110`

Definitions come straight from dictionaryapi.dev with no filtering. A dictionary defines profanity
and sexual terms, and a reviewer who types one gets that content back. This is not automatically a
rejection — dictionaries are a legitimate category — but it must be answered honestly on the age
rating questionnaire (unrestricted web access / mature themes), and under-rating is both a
rejection and a removal risk. My read: answer honestly, expect 12+ or 17+, and you are fine.

### L2. The app's core content depends on two free public APIs with no SLA · Guideline 2.1 · `Wordsword/Dictionary.swift:100,110`

If dictionaryapi.dev is down during review, the reviewer sees an app that cannot define words. Your
error handling is genuinely good — `.network`, `.unavailable`, and `.missing` are distinct states
and `DefineView` surfaces them ([DefineView.swift:283](../Wordsword/DefineView.swift:283)) — so
this degrades gracefully rather than crashing. Still worth a line in the review notes naming the
dependency, so a reviewer who hits an outage reads it as an outage.

### L3. `TARGETED_DEVICE_FAMILY = 1` — iPhone only · not a defect, a decision · `project.yml:25`

The app is iPhone-only and portrait-only. That is a legitimate, common choice and needs no fix —
but it means the App Store listing shows "iPhone only", iPad users can still install it in
compatibility mode, and you supply iPhone screenshots only. Listed here so it is a decision you
made rather than a default you inherited. See "Needs your decision".

---

## Polish

- **Dynamic Type**: four fixed `.font(.system(size:))` call sites will not scale —
  [HomeView.swift:87](../Wordsword/HomeView.swift:87),
  [AccountFlow.swift:418](../Wordsword/AccountFlow.swift:418),
  [StoryView.swift:188](../Wordsword/StoryView.swift:188) and `:192`. Test at AX5.
- **Dark mode**: the paper metaphor hardcodes `.white` and fixed RGB
  ([Doodles.swift:21-23](../Wordsword/Doodles.swift:21), [Theme.swift:18](../Wordsword/Theme.swift:18)).
  Nothing adapts. Either add a dark palette or declare `UIUserInterfaceStyle = Light` in the plist
  so the app is deliberately light-only rather than accidentally broken-looking.
- **Accessibility labels**: 15 annotations across 5 files; icon-only controls elsewhere have none.
- **`project.yml:6` says `xcodeVersion: "16.2"`** while you build with Xcode 26.6. This only sets
  project compatibility metadata, so it does not violate the 28 April 2026 SDK requirement — the
  binary is built against iOS 26.5. Worth updating so the file stops lying.
- **`CFBundleURLTypes` declares the `wordsword://` scheme** for a widget that does not exist yet
  ([WordswordApp.swift:30](../Wordsword/WordswordApp.swift:30)). Harmless, and the handler works.
- **No localization** — English only, which is fine. Set the primary language accordingly.

## Unverified

- **Required-reason API reason code (B4)** — Apple's doc could not be fetched. Resolve by hand at
  the URL in B4.
- **Everything in this list needs a real device, and the simulator cannot tell you:** cold start on
  a fresh install with no network; the `dictionaryapi.dev` timeout path on cellular; SwiftData
  migration from the legacy `onboarded` key ([Auth.swift:101](../Wordsword/Auth.swift:101)) on a
  device that actually has old data; Dynamic Type at AX5 on the smallest supported iPhone; safe-area
  behaviour around the Dynamic Island. One TestFlight build to your own phone covers all of it.

## N/A — checked, does not apply

- **3.1.1 / 3.1.2 purchases and subscriptions**: no StoreKit import, no product identifiers, no
  paywall, no purchase UI anywhere in `Wordsword/`. Nothing to audit.
- **Third-party SDK privacy manifests and signatures**: zero third-party dependencies. No
  `Package.resolved`, no `Podfile`, no SPM refs in the pbxproj, no vendored `.xcframework`.
- **`NS*UsageDescription` strings**: the app requests no protected resources — no camera,
  microphone, location, photos, contacts, notifications, or tracking. Nothing to declare, and
  nothing declared. Correct on both sides.
- **Hardcoded secrets**: none. Both APIs are keyless.
- **Crash-prone force unwraps**: none in first-party code.

---

## Fixed automatically

### 1. `Wordsword/PrivacyInfo.xcprivacy` — created, and wired into the app bundle

**Why:** the app uses a required-reason API (`UserDefaults`) and had no manifest at all. Verified
after `xcodegen generate` that it landed in Copy Bundle Resources
(`project.pbxproj:204`) — a manifest that is not in the bundle does nothing.

```xml
<key>NSPrivacyTracking</key>            <false/>
<key>NSPrivacyTrackingDomains</key>     <array/>
<key>NSPrivacyCollectedDataTypes</key>  <array/>
<key>NSPrivacyAccessedAPITypes</key>
<array>
  <dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array/>   <!-- INCOMPLETE — see B4 -->
  </dict>
</array>
```

`NSPrivacyTracking` is `false` because there is no ATT prompt, no ad SDK, and no analytics.
`NSPrivacyCollectedDataTypes` is empty because nothing identifying leaves the device today — the
account identifier is stored in `UserDefaults` and never transmitted. **Both of those become false
the day a real backend ships**, so revisit this file alongside B1.

### 2. `ITSAppUsesNonExemptEncryption = false` — added to `project.yml` and `Wordsword/Info.plist`

**Why:** without it, App Store Connect asks the export-compliance question on every single upload.

```diff
+        # Export compliance: the app uses only HTTPS/ATS and no custom or non-exempt
+        # cryptography, so it qualifies for the exemption.
+        ITSAppUsesNonExemptEncryption: false
```

**Evidence I relied on:** no `import CryptoKit`, no `CommonCrypto`, no `Security`/Keychain usage,
no custom encryption; ATS on with `NSAllowsArbitraryLoads: false`; the only network traffic is
HTTPS to two public APIs. **This is a legal declaration you are making, so confirm it yourself** —
and revisit it if you ever add Keychain storage or encrypt anything locally.

### A note about the generated project

`project.yml` is the source of truth; `Wordsword.xcodeproj` and `Wordsword/Info.plist` are both
XcodeGen output. I made every change in `project.yml` and then ran `xcodegen generate` and rebuilt
to confirm it survives. **Any fix you make in Xcode's UI — including signing, for B5 — vanishes at
the next `xcodegen generate`.** Put it in `project.yml`.

---

## Needs your decision

1. **Does v1 ship with accounts?** Today the account flow gates flashcards only, and the app is
   fully usable signed out — which is exactly what 5.1.1(v) asks for. But accounts are what create
   B1, B2, and half of B4's future work, and the auth behind them is a stub. Cutting the flow from
   v1 removes three blockers. Keeping it means building real code delivery and account deletion
   before you submit. Which?

2. **Guideline 4.2 — is wordsword enough of an app?** My honest read: **yes, and not marginally.**
   It is not a repackaged website — it has local SwiftData storage, wordlists, spaced-repetition
   flashcards, a word of the day, and an offline path for saved words. The specific thing a
   reviewer could push back on is that the definitions themselves are a thin wrapper over a public
   API, so the case rests on what you built *around* them: the library, the lists, the flashcards.
   Keep those prominent in your screenshots and the argument makes itself. This is your call, not
   mine — I will not "fix" it either way.

3. **iPhone-only, confirm?** `TARGETED_DEVICE_FAMILY = 1` means no iPad screenshots and an
   iPhone-only listing. Fine as a decision, worth being a decision.

4. **Light-only or dark mode?** The paper design is fundamentally light. Declaring
   `UIUserInterfaceStyle = Light` is honest and costs one plist key; building a dark palette is real
   work. Either is acceptable; the current state (dark mode enabled, nothing adapting) is the one
   that looks broken.

5. **App name.** "wordsword" needs to be available across the App Store. Check before you build the
   listing around it.

---

## Next steps

### In the codebase

1. Answer decision 1 (accounts in v1). Everything else in this list is faster once that is settled.
2. **B4** — paste the UserDefaults reason code into `Wordsword/PrivacyInfo.xcprivacy:17`. Two
   minutes, and it is the only blocker with no dependencies.
3. **B1** — remove, gate, or back the verification-code display.
4. **B2** — add "Delete account" to Settings (only if accounts ship in v1).
5. **B3** — add the privacy policy link to Settings → About, once the URL exists (step 2 of the
   ASC list below).
6. **B5** — set `DEVELOPMENT_TEAM` in `project.yml`, regenerate, and confirm
   `Product > Archive` succeeds.
7. Polish items, in whatever order suits you. Decision 4 (dark mode) is the visible one.
8. Re-run this audit. It will diff against today's report and show what closed.

### In App Store Connect — and the two things with waiting periods, do them now

1. **Apple Developer Program enrollment** — paid, annual, and activation can take a day or more.
   Nothing downstream works without it, and B5 is blocked on it. Start today.
2. **Publish a privacy policy at a live URL** — needed both in ASC metadata and in-app (B3). It
   must name dictionaryapi.dev and Datamuse, state that the search term is sent to them, and
   describe retention and deletion. Also a waiting item if you need to stand up a page.
3. Register the bundle id **`com.alexschumacher.Wordsword`** exactly, with no special capabilities
   (the app has no entitlements file and needs none).
4. Create the app record: name, primary language English, that bundle id, SKU.
5. **In-app purchases: none to configure.** Skip this step entirely.
6. **App Privacy labels.** Draft, from what this audit found: *Data Not Linked to You → Search
   History* (or *Other Usage Data*) — the word you look up is sent to two third-party APIs.
   Nothing else leaves the device today: the account identifier is local-only. If accounts get a
   real backend, this becomes *Contact Info, linked to you* and must be updated before that build
   ships.
7. **Age rating questionnaire** — see L1. Answer honestly about unfiltered third-party dictionary
   content.
8. **Screenshots** — iPhone sizes only (L3). Check the current required dimensions at
   <https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/>;
   they change with each device generation, so do not trust a remembered number. Lead with the
   library, wordlists, and flashcards — that is your 4.2 argument (decision 2).
9. **Review notes.** Draft, ready to paste once you have settled decision 1:
   > wordsword is a dictionary and vocabulary app. No account is required — every feature except
   > flashcards works signed out, so no demo account is needed to review the app.
   > [If accounts ship: demo account <address> / code <code>.]
   > Definitions come from the public dictionaryapi.dev and Datamuse APIs. If a lookup shows
   > "unavailable", that is a third-party API outage, not an app defect; words already saved to
   > the library work offline.
10. Pricing: free, all territories, **manual release** so you control the launch moment.
11. Archive, validate, upload. Export compliance is already answered by the plist key.
12. **TestFlight to your own phone first.** Everything in "Unverified" above resolves in one
    install. For a solo developer with no QA, this is the cheapest insurance there is.
13. Submit. Expect the possibility of a rejection and treat it as a conversation, not a verdict.
