# App Store readiness — wordsword — 2026-08-23

## Verdict

**Not submittable today. 4 blockers, 3 likely-rejection items, 5 polish items.**

One blocker closed since the last run (the privacy-manifest reason code, fixed this run), and one
substantial feature landed — hold-to-speak voice input, which is well built and brings its own
privacy surface. The remaining four blockers are the same four that were open on 2026-08-18, and
they have not moved in five days.

**The reason they have not moved is decision 1, which is still unanswered: does v1 ship with
accounts?** Three of the four blockers (B1, B2, and half of B3's scope) exist only because the app
supports account creation, and the auth behind it is still a local stub that prints the
verification code on screen. Answer that question and the remaining work is small. Leave it
unanswered and nothing else can be sequenced.

Approval is never guaranteed — reviewers exercise judgment, and this audit covers what is
checkable from the repo plus the guidelines as published today.

## Requirements freshness

| Source | Status | Apple's last-updated | Fetched |
|---|---|---|---|
| App Store Review Guidelines | fetched | not printed on page | 2026-08-23 |
| Upcoming requirements | fetched | — | 2026-08-23 |
| Privacy manifest structure | fetched (JSON endpoint) | — | 2026-08-23 |
| **Required-reason API reason codes** | **partially fetched — TN3183 confirms `CA92.1`; the full per-category table is still unreachable** | — | 2026-08-23 |
| Third-party SDK manifest list | fetched | — | 2026-08-23 |
| Screenshot specifications | fetched | — | 2026-08-23 |

Full extracts in [requirements-snapshot-2026-08-23.md](requirements-snapshot-2026-08-23.md).

**Build check:** `xcodebuild -configuration Release -destination 'generic/platform=iOS'` →
**BUILD SUCCEEDED**, unsigned, linking `iPhoneOS26.5.sdk` under Xcode 26.6. Re-verified after this
run's fix. This proves the code compiles for device; it does **not** prove archivability, which is
still blocked by B4 (signing).

---

## Since last run (2026-08-18)

**Closed (1)**

- **B4 — privacy manifest had no reason code for UserDefaults.** Closed this run. Apple's docs
  still render client-side, but the reason code was recovered from Apple's **JSON documentation
  endpoints** — TN3183 documents `CA92.1` for `NSPrivacyAccessedAPICategoryUserDefaults`. Verified
  the value ships in the built bundle. See "Fixed automatically".

**Still open (4) — all five days old, unchanged**

- **B1** verification code printed on screen (`AccountFlow.swift:356`) — *confirmed still in the
  Release binary this run by `strings` on the compiled executable, not just by reading source.*
- **B2** no in-app account deletion (`SettingsView.swift:34`)
- **B3** no privacy policy link in the app (`SettingsView.swift:66`)
- **B5 → now B4** code signing disabled (`project.yml:35`)

**New (3) — all from new code, not from changed Apple requirements**

Diffing this run's snapshot against 2026-08-18's: **no Apple requirement changed in the interim.**
Everything new below comes from the voice feature added in commit `59eda73`.

- **L3 (new)** — speech audio may leave the device to Apple's servers on devices without on-device
  recognition (`Voice.swift:229`). Changes the App Privacy labels and the privacy policy's required
  contents.
- **P (new)** — the privacy manifest's `NSPrivacyCollectedDataTypes` is still empty, which was
  correct on 2026-08-18 and is now worth a second look given audio and search terms leave the
  device.
- **Closed polish** — `HomeView.swift:87`'s fixed font size is gone; the header now uses
  `@ScaledMetric`. Three fixed sizes remain (see Polish).

---

## Blockers — will be rejected, or cannot upload at all

### B1. The verification code is printed on screen in the shipping build · Guideline 2.1(a) · `Wordsword/AccountFlow.swift:356`

**What:** `Auth.sendCode` invents a six-digit code locally and returns it via `auth.pendingCode`
([Auth.swift:118-121](../Wordsword/Auth.swift:118)). `AccountFlow` renders it verbatim:

```swift
Label("No server yet — your code is \(pending)", systemImage: "wrench.and.screwdriver")
```

This is **not** inside `#if DEBUG`. Confirmed this run by running `strings` on the compiled Release
executable — `No server yet` is present in the shipping binary. This is stronger evidence than a
source read: the string survives the optimizer and reaches the reviewer's device.

**Why it blocks:** 2.1(a), fetched today — "placeholder text, empty websites, and other temporary
content should be scrubbed before submission … include demo account info **(and turn on your
back-end service!)** if your app includes a login." A login screen that hands you your own code is
the canonical description of a back-end that is not turned on.

**Fix:** one of — (a) ship v1 with no account flow, (b) stand up real code delivery before
submitting, or (c) keep the entire flow behind `#if DEBUG` and hide it from Release. (a) is the
smallest diff and also closes B2. See decision 1.

### B2. No in-app account deletion · Guideline 5.1.1(v) · `Wordsword/SettingsView.swift:34`

**What:** the only account actions in Settings are "Sign out"
([SettingsView.swift:34](../Wordsword/SettingsView.swift:34)) and "Clear all my words"
([SettingsView.swift:60](../Wordsword/SettingsView.swift:60)). `signOut()` sets `isSignedIn = false`
and deliberately **keeps** the stored identifier ([Auth.swift:149-153](../Wordsword/Auth.swift:149)).
"Clear all my words" deletes SwiftData content, not the account. I searched all 23 Swift files for
`deleteAccount`, `delete account`, and `removeAccount` — no match.

**Why it blocks:** 5.1.1(v), verbatim from today's fetch — "If your app supports account creation,
you must also offer account deletion within the app." The app supports account creation
([AccountFlow.swift:161](../Wordsword/AccountFlow.swift:161)), so the requirement is triggered.
Note the requirement is that a *person can find and complete it*, not that the function exists.

**Fix:** a "Delete account" row in the Settings "You" section with a confirmation, clearing
`Key.identifier`, `Key.username`, and `Key.signedIn`. **Not auto-fixed:** what deletion does to the
user's saved words is a product decision, and guessing it wrong destroys data irreversibly. Decide
that first — my read is that words should survive, since they are local and not account-derived,
but it is your call.

### B3. No privacy policy link inside the app · Guideline 5.1.1(i) · `Wordsword/SettingsView.swift:66`

**What:** the About section ([SettingsView.swift:66-72](../Wordsword/SettingsView.swift:66)) credits
dictionaryapi.dev and Datamuse and shows the version. There is no privacy policy link. No policy URL
exists anywhere in the repo.

**Why it blocks:** 5.1.1(i), verbatim — a link is required in App Store Connect metadata **"and
within the app in an easily accessible manner."** Both, not either.

**This got wider since the last audit.** The policy must now cover three outbound flows, not two:

| Recipient | What is sent | Where |
|---|---|---|
| `api.dictionaryapi.dev` | the word being looked up | [Dictionary.swift:131](../Wordsword/Dictionary.swift:131) |
| `api.datamuse.com` | the word being looked up | [Dictionary.swift:121](../Wordsword/Dictionary.swift:121) |
| dictionaryapi.dev-hosted audio | the pronunciation file URL | [Pronounce.swift:154](../Wordsword/Pronounce.swift:154) |
| **Apple speech recognition** | **recorded audio, on devices without on-device support** | **[Voice.swift:229](../Wordsword/Voice.swift:229)** |

**Fix:** publish a policy at a real, live URL, then add a row in Settings → About linking to it. It
must name each recipient above, state what is sent, state retention, and describe how to request
deletion. **Not auto-fixed** — there is no URL to link to, and inventing one is worse than the gap.
This has a real turnaround time; start it today (see the App Store Connect list).

### B4. Code signing is disabled — `Product > Archive` cannot succeed · cannot upload · `project.yml:35`

**What:** `CODE_SIGN_IDENTITY: ""` and `CODE_SIGNING_REQUIRED: "NO"`
([project.yml:35-36](../project.yml:35)), with no `DEVELOPMENT_TEAM` anywhere in `project.yml` or
the generated pbxproj. Correct for simulator work, fatal for archiving.

**Why it blocks:** an unsigned archive cannot be uploaded to App Store Connect. The successful
Release build above proves compilation only.

**Fix — yours, not mine (signing is on the never-touch list):** enroll in the Apple Developer
Program if you have not, then set `DEVELOPMENT_TEAM` in **`project.yml`** and let Xcode manage
signing. Put it in `project.yml`, not Xcode's UI — see the note under "Fixed automatically".

---

## Likely rejection — reviewer discretion

### L1. Unfiltered third-party dictionary content and the age rating · age rating / 2.3.8 · `Wordsword/Dictionary.swift:131`

Definitions come straight from dictionaryapi.dev with no filtering. A dictionary defines profanity
and sexual terms, and a reviewer who types one gets that content back. Not automatically a rejection
— dictionaries are a legitimate category — but it must be answered honestly on the age-rating
questionnaire. **Note the questionnaire changed:** the updated age-rating system has been mandatory
since 2026-01-31, so you will answer the new question set. Under-rating is both a rejection and a
removal risk. My read: answer honestly, expect a 12+ or 17+ outcome, and you are fine.

### L2. Core content depends on two free public APIs with no SLA · Guideline 2.1 · `Wordsword/Dictionary.swift:121,131`

If dictionaryapi.dev is down during review, the reviewer sees an app that cannot define words. Your
error handling is genuinely good — `.offline` and `.missing` are distinct user-visible states
([DefineView.swift:303-305](../Wordsword/DefineView.swift:303)) and saved words work offline — so
this degrades rather than crashes. Worth a line in the review notes naming the dependency, so an
outage reads as an outage.

### L3. Speech audio leaves the device on some hardware · Guideline 5.1.2(i) · `Wordsword/Voice.swift:229` · **new this run**

```swift
req.requiresOnDeviceRecognition = r.supportsOnDeviceRecognition
```

This is the right call — on-device whenever the device can, Apple's servers otherwise — and the
comment on that line says exactly that. But on a device without on-device support, **recorded audio
is transmitted to Apple.**

Two things follow, and neither is a code change:

1. **5.1.2(i)** requires disclosing where personal data is shared with third parties. Your purpose
   string is already honest — "It runs on your iPhone whenever your device supports it"
   ([project.yml:22](../project.yml:22)) — which is better than most apps manage and satisfies
   5.1.1(ii). The privacy policy (B3) must carry the same disclosure.
2. The **App Privacy labels** must account for it. See the ASC section for the draft.

I would not bet on a rejection here — Apple's own speech framework doing Apple's own recognition is
well-trodden — but it is a disclosure obligation you now have and did not have five days ago.

---

## Polish

- **Dynamic Type**: three fixed `.font(.system(size:))` call sites will not scale —
  [AccountFlow.swift:418](../Wordsword/AccountFlow.swift:418),
  [StoryView.swift:188](../Wordsword/StoryView.swift:188) and `:192`. Down from four:
  `HomeView.swift:87` now uses `@ScaledMetric`. Test at AX5.
- **Dark mode**: unchanged and still the most visible item. The paper metaphor hardcodes `.white`
  and fixed RGB ([Doodles.swift:21-23](../Wordsword/Doodles.swift:21),
  [Theme.swift:18](../Wordsword/Theme.swift:18)). Nothing adapts, and `UIUserInterfaceStyle` is
  still not declared — I checked. See decision 4.
- **`NSPrivacyCollectedDataTypes` is empty** ([PrivacyInfo.xcprivacy:10](../Wordsword/PrivacyInfo.xcprivacy:10)).
  Defensible today: the account identifier never leaves the device, and search terms sent to a
  third-party API are arguably not "collected" by you. Revisit alongside B3 and the labels — and
  it becomes definitively wrong the day a real backend ships.
- **`project.yml:6` says `xcodeVersion: "16.2"`** while you build with Xcode 26.6. Compatibility
  metadata only — it does **not** violate the 2026-04-28 SDK requirement, since the binary links
  `iPhoneOS26.5.sdk`. Not auto-fixed: the change is cosmetic and applying it requires regenerating
  the pbxproj, which is churn for zero functional gain. Fix it next time you regenerate anyway.
- **`CFBundleURLTypes` declares `wordsword://`** for a widget that does not exist yet
  ([WordswordApp.swift:30](../Wordsword/WordswordApp.swift:30)). Harmless — the handler works and
  the scheme resolves — but it is undocumented surface area. If a reviewer finds it, 2.3.1(a) asks
  that functionality be documented; one line in the review notes covers it.
- **No localization** — English only, which is fine. Set primary language accordingly.

## Unverified

- **Required-reason API table.** `CA92.1` is confirmed from Apple's TN3183 and is correct for this
  app's usage (`UserDefaults.standard` only, no App Group, no entitlements file — verified). The
  *complete* per-category reason table remains unreachable. This matters only if you add another
  required-reason category later.
- **Needs a real device — the simulator cannot tell you:**
  - **Microphone and speech, on real hardware.** New and highest-value: the simulator's mic path,
    audio-session interruptions, `.duckOthers` behaviour against real playback, and — critically —
    whether the device supports on-device recognition at all (L3).
  - Cold start on a fresh install with no network.
  - The `dictionaryapi.dev` timeout path on cellular.
  - SwiftData migration from the legacy `onboarded` key
    ([Auth.swift:101](../Wordsword/Auth.swift:101)) on a device with real old data.
  - Dynamic Type at AX5 on the smallest supported iPhone.
  - Safe-area behaviour around the Dynamic Island.

  One TestFlight build to your own phone covers all of it.

## N/A — checked, does not apply

- **3.1.1 / 3.1.2 purchases and subscriptions**: no `import StoreKit` in any of the 23 Swift files,
  no product identifiers, no paywall, no purchase UI. The inventory's StoreKit scan returned one
  hit and it is the word "Restore" in an unrelated comment
  ([DefineView.swift:50](../Wordsword/DefineView.swift:50)). Nothing to audit.
- **Third-party SDK privacy manifests and signatures**: zero third-party dependencies. No
  `Package.resolved`, no `Podfile`, no SPM package refs in the pbxproj, no vendored `.xcframework`.
  None of the ~90 SDKs on Apple's list is present.
- **Hardcoded secrets**: none. Both APIs are keyless. The secret scan returned no candidates.
- **Force unwraps / crash-prone patterns**: none in first-party code. Every hit in the scan is an
  `assert` inside a `#if DEBUG` self-check block ([Voice.swift:87-99](../Wordsword/Voice.swift:87),
  [Pronounce.swift:96-114](../Wordsword/Pronounce.swift:96)) — excluded from Release.
- **Usage descriptions**: both requested permissions are declared and both declared permissions are
  requested. `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`
  ([project.yml:21-22](../project.yml:21)) ↔ `SFSpeechRecognizer.requestAuthorization` and
  `AVAudioApplication.requestRecordPermission` ([Voice.swift:301-319](../Wordsword/Voice.swift:301)).
  No orphans in either direction, and both strings state specifically what the data is used for.
- **5.1.1(iv) alternative for users who decline**: satisfied. Voice is a hold gesture on an input
  that is primarily typed; denial produces a specific message and a Settings deep link rather than a
  dead end ([Voice.swift:8-23](../Wordsword/Voice.swift:8)).
- **Push notifications, ATT, location, camera, photos, contacts, HealthKit**: none used, none
  declared.

---

## Fixed automatically

### `Wordsword/PrivacyInfo.xcprivacy` — the UserDefaults reason code, filled in

**Why:** closes B4 from the 2026-08-18 report. Since 2024-05-01 every required-reason API needs a
declared reason that is a valid code for its category; an empty array is ITMS-91053.

```diff
 			<key>NSPrivacyAccessedAPIType</key>
 			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
-			<!-- INCOMPLETE — see the readiness report. Apple's reason-code list could not be
-			     fetched this run, and guessing a code is an ITMS-91055 rejection. Fill this
-			     array from developer.apple.com before uploading. -->
+			<!-- CA92.1: defaults readable and writable only by this app. Verified against
+			     Apple's TN3183, fetched 2026-08-23. The app uses UserDefaults.standard only
+			     (Auth.swift:95, LastSearch.swift:13) — no App Group, no extension, so the
+			     App Group code 1C8F.1 does not apply. -->
 			<key>NSPrivacyAccessedAPITypeReasons</key>
-			<array/>
+			<array>
+				<string>CA92.1</string>
+			</array>
```

**Why this was safe to apply, having refused to guess it last run:**

1. The value came from Apple, fetched this run — TN3183's own sample implementation uses `CA92.1`
   for this exact category. Not recalled.
2. The app's usage matches the code's scope exactly. `CA92.1` covers defaults accessible only to the
   app itself. All four `UserDefaults` call sites use `UserDefaults.standard`
   ([Auth.swift:95,97](../Wordsword/Auth.swift:95),
   [LastSearch.swift:13-14](../Wordsword/LastSearch.swift:13)); there is no `suiteName`, no
   `.entitlements` file anywhere in the repo, and no extension target — so the App Group code
   `1C8F.1` provably does not apply.

**Verified, not assumed:** `plutil -lint` passes, the Release build succeeds, and `plutil -p` on
`Wordsword.app/PrivacyInfo.xcprivacy` **inside the built bundle** shows `CA92.1`. A manifest that is
not in the bundle does nothing, so the bundle is where it was checked.

### A note about the generated project

`project.yml` is the source of truth; `Wordsword.xcodeproj` and `Wordsword/Info.plist` are XcodeGen
output. This run's fix touched only `Wordsword/PrivacyInfo.xcprivacy`, which is a source resource
already wired into Copy Bundle Resources — **no regeneration is needed.** But any fix you make in
Xcode's UI, including signing for B4, vanishes at the next `xcodegen generate`. Put it in
`project.yml`.

---

## Needs your decision

1. **Does v1 ship with accounts?** *(unanswered from the last run — everything else waits on this)*
   Today the account flow gates flashcards only, and the app is fully usable signed out, which is
   exactly what 5.1.1(v) asks for. But accounts are what create B1 and B2, and the auth behind them
   is a stub that prints the code on screen. **Cutting the flow from v1 closes two of four
   blockers.** Keeping it means building real code delivery *and* account deletion before you
   submit. Which?

2. **Guideline 4.2 — is wordsword enough of an app?** My honest read: **yes, and not marginally.**
   It is not a repackaged website — local SwiftData storage, wordlists, spaced-repetition
   flashcards, word of the day, an offline path for saved words, and now hold-to-speak voice input
   with on-device recognition. The voice feature helps this argument materially; it is precisely the
   kind of thing a website cannot do. The residual risk is that the definitions themselves are a
   thin wrapper over a public API, so the case rests on what you built around them. Lead your
   screenshots with the library, lists, flashcards, and voice, and the argument makes itself. Your
   call, not mine — I will not "fix" it either way.

3. **iPhone-only, confirm?** `TARGETED_DEVICE_FAMILY = 1` ([project.yml:32](../project.yml:32))
   means an iPhone-only listing and no iPad screenshots. iPad users can still install in
   compatibility mode. Fine as a decision, worth being a decision.

4. **Light-only or dark mode?** Unchanged from last run. The paper design is fundamentally light.
   Declaring `UIUserInterfaceStyle = Light` in `project.yml` is honest and costs one key; building a
   dark palette is real work. Either is acceptable. **The current state — dark mode enabled, nothing
   adapting — is the one that looks broken.**

5. **App name availability.** "wordsword" must be unique across the App Store. Check before you
   build the listing around it.

6. **Do you want EU distribution?** If yes, the EU Digital Services Act **trader status** has been
   required since 2025-02-17, and apps without it are removed from the EU App Store. It is a form in
   App Store Connect asking for a real name, address, phone, and email that become **publicly
   visible on your listing**. For a solo developer publishing under a personal name, that is a
   privacy consideration worth deciding deliberately rather than discovering at submission.

---

## Next steps

### In the codebase

1. **Answer decision 1.** Everything below is faster once it is settled, and it has now been open
   for two audits.
2. **B1** — remove, gate behind `#if DEBUG`, or back the verification-code display with real
   delivery. Verify by re-running `strings` on the Release binary and confirming `No server yet` is
   gone.
3. **B2** — add "Delete account" to Settings, if accounts ship in v1.
4. **B3** — add the privacy policy link to Settings → About, once the URL exists (ASC step 2).
5. **B4** — set `DEVELOPMENT_TEAM` in `project.yml`, run `xcodegen generate`, and confirm
   `Product > Archive` actually succeeds. Requires ASC step 1 first.
6. Polish, in whatever order suits you. Decision 4 (dark mode) is the visible one; Dynamic Type at
   AX5 is the one a reviewer with accessibility settings on would hit.
7. Re-run this audit. It will diff against today's report and show what closed.

### In App Store Connect — the two with waiting periods are first

1. **Apple Developer Program enrollment.** Paid, annual, activation can take a day or more.
   Nothing downstream works without it and **B4 is blocked on it.** Start today if you have not.
2. **Publish a privacy policy at a live URL.** Needed in ASC metadata *and* in-app (B3). Must name
   dictionaryapi.dev, Datamuse, and **Apple speech recognition** (L3), state that the search term
   and — on some devices — recorded audio are sent, and describe retention and deletion. Also a
   waiting item if you need to stand up a page. Start today.
3. Register the bundle id **`com.alexschumacher.Wordsword`** exactly, with **no special
   capabilities** — the app has no entitlements file and needs none.
4. Create the app record: name (decision 5), primary language English, that bundle id, SKU.
5. **In-app purchases: none to configure.** Skip entirely.
6. **App Privacy labels.** Draft, from this audit's data-flow section — note this changed since
   2026-08-18:
   - *Data Not Linked to You → Search History* (or *Other Usage Data*): the word you look up is
     sent to dictionaryapi.dev and Datamuse.
   - *Data Not Linked to You → Audio Data*: **new.** On devices without on-device speech
     recognition, recorded audio goes to Apple for transcription (L3). Declare it rather than argue
     it is Apple's own framework.
   - Nothing else leaves the device: the account identifier is local-only. **If accounts get a real
     backend this becomes *Contact Info, linked to you*** and must be updated before that build
     ships.
7. **Age rating questionnaire** — the updated question set, mandatory since 2026-01-31. Answer
   honestly about unfiltered third-party dictionary content (L1).
8. **Screenshots** — iPhone only (decision 3). 1–10 images, **no alpha channel**. Supplying the
   **6.9" set at 1320 × 2868** is sufficient; Apple scales down. (6.5" at 1284 × 2778 is required
   only if you supply no 6.9" set.) Lead with library, wordlists, flashcards, and voice — that is
   your 4.2 argument.
9. **Review notes.** Draft, ready once decision 1 is settled:
   > wordsword is a dictionary and vocabulary app. No account is required — every feature except
   > flashcards works signed out, so no demo account is needed to review the app.
   > [If accounts ship: demo account <address> / code <code>.]
   > Definitions come from the public dictionaryapi.dev and Datamuse APIs. If a lookup shows
   > "unavailable", that is a third-party API outage, not an app defect; words already saved to the
   > library work offline.
   > Hold the input field on the Home screen to speak a word instead of typing it. This requires
   > microphone and speech-recognition permission; transcription runs on-device where the hardware
   > supports it.
   > The app registers a `wordsword://define` URL scheme for a planned widget; it focuses the
   > search input.
10. **EU trader status** — only if distributing in the EU (decision 6).
11. Pricing: free, territories per decision 6, **manual release** so you control the launch moment.
12. Archive, validate, upload. Export compliance is already answered by
    `ITSAppUsesNonExemptEncryption = false` in the plist — a declaration you should confirm you are
    comfortable making. The evidence still holds: no CryptoKit, no CommonCrypto, no Keychain, no
    custom crypto; ATS on with `NSAllowsArbitraryLoads: false`; HTTPS only.
13. **TestFlight to your own phone first.** Everything in "Unverified" resolves in one install, and
    the voice feature makes this materially more valuable than it was five days ago — none of the
    microphone path has run on real hardware. For a solo developer with no QA this is the cheapest
    insurance available.
14. Submit. Expect the possibility of a rejection and treat it as a conversation, not a verdict.
