# Requirements snapshot — 2026-08-23

What was fetched from Apple this run, and the operative text the report cites. Diff this against
`requirements-snapshot-2026-08-18.md` to see whether Apple's rules moved, not just the code.

| # | Source | URL | Status |
|---|---|---|---|
| 1 | App Store Review Guidelines | `developer.apple.com/app-store/review/guidelines/` | fetched (no last-updated date printed on page) |
| 2 | Upcoming requirements | `developer.apple.com/news/upcoming-requirements/` | fetched |
| 3 | Privacy manifest structure | `.../documentation/BundleResources/privacy-manifest-files` (JSON endpoint) | fetched |
| 4 | Required-reason API reason codes | TN3183 (JSON endpoint) | **partially fetched — see note** |
| 5 | Third-party SDK manifest list | `developer.apple.com/support/third-party-SDK-requirements/` | fetched |
| 6 | Screenshot specifications | `developer.apple.com/help/app-store-connect/reference/screenshot-specifications/` | fetched |

## Note on source 4 — resolved this run, unlike last run

The canonical page (`describing-use-of-required-reason-api`) renders client-side and returns an
empty body to any plain fetch — the same failure as the 2026-08-18 run. Resolved this run by
fetching Apple's documentation **JSON data endpoints** instead of the rendered HTML:

```
https://developer.apple.com/tutorials/data/documentation/<path>.json
```

**TN3183 — "Adding required reason API entries to your privacy manifest"** confirms the five
categories and shows `CA92.1` as the reason code for `NSPrivacyAccessedAPICategoryUserDefaults`
in its own sample implementation.

Categories per TN3183:
`NSPrivacyAccessedAPICategoryActiveKeyboards`, `...DiskSpace`, `...FileTimestamp`,
`...SystemBootTime`, `...UserDefaults`.

**Still not obtained:** the full enumerated reason-code table with descriptions for every category.
Only the codes appearing in TN3183's examples were retrievable (`B728.1`, `E174.1` for DiskSpace;
`CA92.1` for UserDefaults). This is sufficient for wordsword, which uses exactly one
required-reason category, but a future run that adds another category must re-resolve this.

## 1. Review Guidelines — operative text cited in the report

**2.1(a) App Completeness** — "Submissions to App Review … should be final versions with all
necessary metadata and fully functional URLs included; placeholder text, empty websites, and other
temporary content should be scrubbed before submission. Make sure your app has been tested on-device
for bugs and stability before you submit it, and include demo account info (and turn on your
back-end service!) if your app includes a login."

**2.3.1(a)** — "Don't include any hidden, dormant, or undocumented features in your app; your app's
functionality should be clear to end users and App Review. All new features, functionality, and
product changes must be described with specificity in the Notes for Review section."

**2.3.8** — metadata must adhere to a 4+ age rating regardless of the app's own rating.

**4.2 Minimum Functionality** — "Your app should include features, content, and UI that elevate it
beyond a repackaged website. If your app is not particularly useful, unique, or 'app-like,' it
doesn't belong on the App Store."

**5.1.1(i) Privacy Policies** — "All apps must include a link to their privacy policy in the App
Store Connect metadata field **and within the app in an easily accessible manner**." The policy must
identify what data is collected and all uses of it; confirm third parties receiving data provide
equal protection; and "Explain its data retention/deletion policies and describe how a user can
revoke consent and/or request deletion of the user's data."

**5.1.1(ii) Permission** — "Ensure your purpose strings clearly and completely describe your use of
the data."

**5.1.1(iv) Access** — "Where possible, provide alternative solutions for users who don't grant
consent."

**5.1.1(v) Account Sign-In** — "If your app doesn't include significant account-based features, let
people use it without a login. **If your app supports account creation, you must also offer account
deletion within the app.** Apps may not require users to enter personal information to function,
except when directly relevant to the core functionality of the app or required by law."

**5.1.2(i) Data Use and Sharing** — "you may not use, transmit, or share someone's personal data
without first obtaining their permission. You must provide access to information about how and where
the data will be used. You must clearly disclose where personal data will be shared with third
parties, including with third-party AI, and obtain explicit permission before doing so."

## 2. Upcoming requirements — active deadlines

| Requirement | Enforced since | Applies to wordsword |
|---|---|---|
| **Builds must use Xcode 26+ and the iOS 26 SDK** | **2026-04-28** | **Yes — satisfied.** Machine has Xcode 26.6 (17F113); Release build links `iPhoneOS26.5.sdk`. |
| Updated age-rating questionnaire must be answered | 2026-01-31 (passed) | Yes — the new questionnaire applies when the app record is created. |
| Required-reason API declarations for all such APIs | 2024-05-01 | Yes — UserDefaults. Closed this run. |
| Receipt signing: SHA-256 / AppTransaction APIs | 2025-01-24 | No — no IAP, no receipt validation. |
| EU DSA trader status | 2025-02-17 | Only if distributing in the EU — see report. |
| APNs certificate trust-store updates | 2025-01/02 | No — no push. |
| macOS quarantine attribute | 2025-02-18 | No — iOS only. |

## 3. Privacy manifest structure — the four top-level keys

- `NSPrivacyTracking` (Boolean) — whether data is used for tracking per ATT.
- `NSPrivacyTrackingDomains` (Array of strings) — required only when tracking is `true`.
- `NSPrivacyCollectedDataTypes` (Array of dicts) — data types collected.
- `NSPrivacyAccessedAPITypes` (Array of dicts) — each with `NSPrivacyAccessedAPIType` (category
  string) and `NSPrivacyAccessedAPITypeReasons` (array of reason codes). Required on iOS.

## 5. Third-party SDK requirements

A named list of ~90 SDKs (Firebase*, Alamofire, Lottie, RxSwift, SnapKit, Flutter, OneSignal,
FBSDK*, GoogleSignIn, Kingfisher, SDWebImage, etc.) must ship a privacy manifest, and a signature
when used as a binary dependency. Any version of a listed SDK, and anything repackaging one, is in
scope. **wordsword has zero third-party dependencies, so none of this applies.**

## 6. Screenshot specifications — iPhone

1–10 screenshots, `.jpg`/`.jpeg`/`.png`, **no alpha channel or transparency**.

| Display | Devices | Portrait |
|---|---|---|
| 6.9" | iPhone 17/16/15/14 Pro Max | 1320 × 2868 |
| 6.5" | iPhone 14 Plus, 13/12/11 Pro Max, XS Max, XR | 1284 × 2778 or 1242 × 2688 |
| 6.3" | iPhone 17/16/15/14 Pro | 1179 × 2556 or 1206 × 2622 |
| 6.1" | iPhone 17e/16e/14/13/12/11 Pro, XS, X | 1170 × 2532, 1125 × 2436, 1080 × 2340 |

**The 6.5" set is required if the app runs on iPhone and no 6.9" set is supplied.** Supplying 6.9"
alone is sufficient — Apple scales down for smaller classes. wordsword is iPhone-only
(`TARGETED_DEVICE_FAMILY = 1`), so no iPad screenshots are needed.
