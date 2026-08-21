# Requirements snapshot — 2026-08-18

What was fetched from Apple this run, and what the audit is allowed to cite. A finding that
references a source marked FAILED below is tagged UNVERIFIED in the report.

| Source | Status | Apple's last-updated | Notes |
|---|---|---|---|
| App Store Review Guidelines | **fetched** | not printed on page | 2.1, 3.1.1, 3.1.2, 4.2, 5.1.1(i–v), 5.1.2 read in full |
| Upcoming requirements | **fetched** | — | SDK minimum + age-rating deadline captured |
| Privacy manifest file structure | **fetched** | — | four top-level keys + placement confirmed |
| Required-reason API reason codes | **FAILED** | — | 4 attempts, see below |
| Third-party SDK list | **fetched** | — | full list captured; moot, this app has zero third-party SDKs |

## The failed fetch

`describing-use-of-required-reason-api` and its three alternates
(`.../privacy-manifest-files/describing-use-of-required-reason-api` → HTTP 404, TN3183, and
`NSPrivacyAccessedAPITypeReasons`) all returned the page title with no body — Apple's
documentation site renders these client-side and WebFetch receives an empty shell.

**Consequence:** the valid reason code for `NSPrivacyAccessedAPICategoryUserDefaults` is unknown
this run. It was left blank in the generated manifest rather than filled from memory, because
`NSPrivacyAccessedAPITypeReasons` values must be valid codes for the category since 1 May 2024, and
an invalid code is rejection ITMS-91055 — the same outcome as a missing one, arriving later.

## Rules captured, verbatim where cited

**2.1(a)** — "Submissions to App Review … should be final versions with all necessary metadata and
fully functional URLs included; placeholder text, empty websites, and other temporary content
should be scrubbed before submission … include demo account info (and turn on your back-end
service!) if your app includes a login."

**4.2** — "Your app should include features, content, and UI that elevate it beyond a repackaged
website. If your app is not particularly useful, unique, or 'app-like,' it doesn't belong on the
App Store."

**5.1.1(i)** — "All apps must include a link to their privacy policy in the App Store Connect
metadata field **and within the app in an easily accessible manner**."

**5.1.1(v)** — "If your app doesn't include significant account-based features, let people use it
without a login. **If your app supports account creation, you must also offer account deletion
within the app.**"

**5.1.2(i)** — "You must clearly disclose where personal data will be shared with third parties,
including with third-party AI, and obtain explicit permission before doing so."

**SDK minimum, effective 28 April 2026** — apps uploaded to App Store Connect must be built with
Xcode 26 or later and the iOS 26 SDK.

**Age rating, deadline 31 January 2026** — responses to the updated age-rating questions are
required per app. That date has passed; a new app answers the current questionnaire at creation.

**Privacy manifest structure** — `NSPrivacyTracking` (Bool), `NSPrivacyTrackingDomains` (Array),
`NSPrivacyAccessedAPITypes` (Array of Dict), `NSPrivacyCollectedDataTypes` (Array of Dict). Must be
in the app target's Copy Bundle Resources phase.

**Third-party SDK privacy-manifest list** — 80+ named SDKs (Alamofire, Firebase*, Lottie, RxSwift,
SDWebImage, GoogleSignIn, OneSignal, …). Applies to any version and to repackagers.
