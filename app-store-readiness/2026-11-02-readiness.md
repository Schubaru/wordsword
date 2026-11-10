# App Store readiness — wordsword — 2026-11-02

Previous report: [2026-11-01-readiness.md](2026-11-01-readiness.md). Requirements fetched today: [requirements-snapshot-2026-11-02.md](requirements-snapshot-2026-11-02.md). Listing copy: [app-store-listing.md](app-store-listing.md).

## Verdict
**Not submittable today. One blocker left, B2 (code signing), and you can now clear it.**

Your enrollment was accepted, but Xcode on this Mac doesn't see a paid team yet. It lists only "Alex Schumacher (Personal Team)" (`DJKZQ223JK`, free) and "Upstory LLC" (`RPH46L7S8Z`). The first move is to get the new paid team ID into Xcode (see "Launch plan", step 1). After that, signing is a few lines in `project.yml` and I can do it.

This run also found and fixed an upload blocker that the previous six runs missed: the app icon carried an alpha channel.

Approval is never guaranteed. Reviewers use their own judgment, and this audit covers what the repo shows plus the guidelines as published today.

## Requirements freshness
| Source | Status | Fetched |
|---|---|---|
| App Store Review Guidelines | Fetched (through 5.2.5) | 2026-11-02 |
| Upcoming requirements | Fetched. Newest item is still 2026-09-09 | 2026-11-02 |
| Screenshot specifications | Fetched | 2026-11-02 |
| Required-reason API reason codes | **Fetched**, through the JSON docs endpoint. This is the first successful read in 6 runs | 2026-11-02 |
| App icon alpha rule | No official page. Forum threads quote the upload validator | 2026-11-02 |
| Third-party SDK list | N/A. The app has no third-party SDKs | — |

Nothing on Apple's side changed since 11-01.

**Toolchain:** Xcode 26.6 with the iOS 26.5 SDK meets "Xcode 26 or later… SDK for iOS 26". The deployment target, iOS 17, meets "iOS 13 or later".

**Build check:** a Release build for `generic/platform=iOS` with `CODE_SIGNING_ALLOWED=NO` **succeeded**, both before and after the icon fix. I haven't run an archive, because signing is off.

## Since last run (2026-11-01)
**Closed (2):**
- **U1. Required-reason code.** Apple's text for `CA92.1` reads "read and write information that is only accessible to the app itself". Every `UserDefaults` call site stores the app's own data. `Auth.swift:139` uses a named suite only inside the DEBUG self-check, and there's no App Group. The manifest is correct as it stands.
- **Icon alpha (new and fixed this run).** See "What I changed".

**Still open (4):**
- **B2. Signing.** This is the 7th run it's been open. It's now unblocked, pending the team ID.
- **Q1–Q3. Model and fallback quality** in `Simplifier.swift`. This is the 2nd run, and the code is unchanged since 11-01.

**New (1):**
- **N2. Stray folders** from another project are untracked in this repo. It's not an App Store issue, but it's a risk.

## Blockers
### B2. Code signing is disabled  ·  can't archive or upload  ·  `project.yml:41-42`, `:46-54`
**What:** the target's base settings have `CODE_SIGN_IDENTITY: ""` and `CODE_SIGNING_REQUIRED: "NO"`. Debug device builds sign with the free Personal Team under `com.alexschumacher.Wordsword.dev`, with the Sign in with Apple entitlement stripped.
**Why it blocks:** an unsigned build can't be archived for distribution. Sign in with Apple (`Wordsword.entitlements`) needs a paid team that has the capability.
**Fix:** this is on the never-touch list, so it waits for your OK and your team ID:
1. Remove the two base lines.
2. Set `DEVELOPMENT_TEAM: <paid team ID>` and `CODE_SIGN_STYLE: Automatic` at the base level.
3. Delete the Debug `[sdk=iphoneos*]` overrides, so the device build uses the real bundle ID and keeps Sign in with Apple.
4. Run `xcodegen generate`.
5. Archive with `-allowProvisioningUpdates`. Xcode registers `com.alexschumacher.Wordsword` and its Sign in with Apple capability on the paid team by itself.

**Never pick `RPH46L7S8Z` (Upstory LLC).** The app would be published under that company's name, and moving it later means an app transfer.

## Fix before review (quality, not a rule)
2.1(a): "We will reject … binaries that crash or exhibit obvious technical problems." None of these is clearly that, but a reviewer would see all three within a minute. They're unchanged since 11-01, and the full evidence is in that report.

- **Q1. Model replies echo their own prompt** (`Simplifier.swift:27-35`, `:97`). For example: *"here's a different way to explain 'sanguine'…"* and *"Sure! Here's a sentence using…"*. The `firstSentences` filler regex at `:68` doesn't catch either. **Fix:** strip a leading "here's…:" preamble in one place, `ask()`, and drop any reply that doesn't contain the word, so the existing fallbacks take over.
- **Q2. No timeout on the model call** (`Simplifier.swift:134`). **Fix:** race `session.respond` against 8 seconds. On timeout, return `nil` so the fallbacks run.
- **Q3. Canned sentence templates misuse words** (`Simplifier.swift:100-104`). For example: *"It was so sanguine that everyone in the room noticed."* **Fix:** when there's no dictionary example, say so plainly instead of inventing a sentence.

## Polish
- **N2. Stray folders: `.github/workflows/` (`review-shots.yml`, `triage-reply.yml`) and `review/` (a Vite/TS review board).** They reference Vercel, Supabase secrets and an MCP, and none of that is wordsword's. The app target only compiles `Wordsword/`, so they don't affect the binary. But if `.github/` is ever committed and pushed, those workflows will run on every push to `schubaru/wordsword` and fail for lack of secrets. **Fix:** move them back to the project they belong to. I haven't touched them.

## Unverified
These need a real iPhone signed with the paid team. The simulator hides them, and TestFlight (launch plan, step 8) is where to check them:
- Sign in with Apple, end to end: sign in, sign out, delete account, and revoking the credential in iOS Settings.
- The mic and speech permission prompts, and the denial path.
- Foundation Models replies on an Apple Intelligence iPhone (Q1, Q2).
- Behaviour on an iPhone without Apple Intelligence (Q3). Your phone qualifies: on 10-28 the model reported unavailable on it.

## N/A — checked, does not apply
- **3.1.1 / 3.1.2 purchases:** no `StoreKit` import, no product identifiers and no paywall. The inventory's only "restore" hit is a code comment at `DefineView.swift:50`.
- **4.8 login services:** the only login is Sign in with Apple. 4.8 applies to "third-party or social login service[s]".
- **Third-party SDKs and their manifests:** there are no SPM packages and no embedded frameworks.
- **iPad:** `TARGETED_DEVICE_FAMILY: "1"` makes this an iPhone-only app, so no iPad screenshots are needed.
- **Tracking / ATT:** `NSPrivacyTracking` is false, there are no tracking domains, and there's no ad or analytics SDK.

## What I changed this run
### `Wordsword/Assets.xcassets/AppIcon.appiconset/AppIcon.png`: removed the alpha channel
**Why:** upload validation rejects an App Store icon with an alpha channel. Apple's forums quote error ITMS-90717: "can't be transparent nor contain an alpha channel". The file was 1024×1024 RGBA with every pixel at alpha 255, so the channel carried no information.
**How:**
- Redrew it into an sRGB context with no alpha (`noneSkipLast`) and wrote it out as PNG.
- Compared the two RGBA pixel buffers: **max channel difference is 0**, so it looks identical.
- `sips` now reports `hasAlpha: no`. The Release build still succeeds.

The screenshots were already alpha-free: all 14 report `hasAlpha: no`.

## Needs your decision
1. **Which team?**
   - You need the **paid team ID** from developer.apple.com/account → Membership details.
   - Did you enrol as an **individual** (your legal name shows as the seller) or an **organization**?
   - Never Upstory LLC.
2. **Q1–Q3:** fix them before you submit (I recommend this; it's about an hour of work), or ship as is.
3. **App name**, carried over from 11-01. I recommend `wordsword: Dictionary & Words` (29 characters). App Store Connect confirms whether it's free when you create the record.
4. **Category**, carried over. I recommend Reference as primary and Education as secondary.

## Launch plan
Each step depends only on the steps above it. **[you]** means it's in your browser or account, and **[me]** means I do it here.

1. **[you] Get the paid team into Xcode.**
   - Confirm developer.apple.com/account shows the membership as **active**. "Accepted" can come before activation.
   - Copy the Team ID.
   - In Xcode → Settings → Apple Accounts, select your Apple ID and download or refresh the teams until a non-"Personal Team" entry appears. A stale login needs a sign-out and sign-in, which only you can do.
2. **[me] Signing (B2):** edit `project.yml`, run `xcodegen generate`, and run a signed Release **archive**. Xcode registers the bundle ID and the Sign in with Apple capability during this step.
3. **[me] Q1–Q3** in `Simplifier.swift`, if you say yes to decision 2. Then rebuild and check them in the simulator.
4. **[you] Create the app record** in App Store Connect:
   - New App → iOS
   - Name per decision 3
   - English (U.S.)
   - Bundle ID `com.alexschumacher.Wordsword`. It appears after step 2 and **can't be changed later**.
   - SKU `wordsword-ios`
5. **[you] Fill in the record** from [app-store-listing.md](app-store-listing.md):
   - **App Information:** subtitle, category, and Privacy Policy URL https://schubaru.github.io/wordsword/privacy.html (live, HTTP 200 today).
   - **Age rating:** the live questionnaire. Answer honestly about the AI-generated text and the unfiltered definitions; the draft answers are in the listing file.
   - **App Privacy:** Data Not Collected.
   - **Pricing:** free, all territories.
   - **DSA trader status:** set it if you'll distribute in the EU. App Store Connect shows which trader contact details it publishes. Read that before you choose, because excluding EU storefronts is the alternative.
6. **[you] Version page:**
   - Screenshots: `screenshots/6.9` (1320×2868) into the 6.9" slot. Per the spec fetched today, ASC scales down from the largest size. Also upload `screenshots/6.3` (1206×2622) if the medium slot asks for its own.
   - Description, keywords and promo text from the listing file.
   - Support URL https://schubaru.github.io/wordsword/support.html and marketing URL https://schubaru.github.io/wordsword/
   - Review notes: section 7 of the listing file. No demo account is needed, because sign-in is optional.
7. **[me, with your OK] Upload:** export the archive for App Store Connect and upload it, or do it yourself from Xcode → Organizer → Distribute App. There's no export questionnaire, because `ITSAppUsesNonExemptEncryption=false` is declared and the app only makes HTTPS calls to Datamuse, dictionaryapi.dev and audio URLs. Processing takes minutes to a couple of hours.
8. **[you] TestFlight on your iPhone.** Install it from internal testing and run every check in "Unverified". Sign in with Apple has never run end to end, so this matters.
9. **[me] Run `/app-store` again** against the signed build.
10. **[you] Submit for review** with **manual release**, so you pick launch day. A first rejection is normal: reply in the Resolution Center, and most are one fixable thing.
