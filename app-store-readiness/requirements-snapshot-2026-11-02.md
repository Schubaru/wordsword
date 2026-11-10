# Requirements snapshot — 2026-11-02

Diff target: [requirements-snapshot-2026-11-01.md](requirements-snapshot-2026-11-01.md). **No Apple-side rule changes since 11-01.** New this run: the required-reason reason codes were read for the first time since 2026-08-23, through Apple's JSON docs endpoint.

| Source | Status | Apple's last-updated |
|---|---|---|
| https://developer.apple.com/app-store/review/guidelines/ | Fetched (first 100k of 114k chars, through 5.2.5) | Not shown |
| https://developer.apple.com/news/upcoming-requirements/ | Fetched | Newest item 2026-09-09 (unchanged) |
| https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/ | Fetched | Not shown; same content as 11-01 |
| https://developer.apple.com/tutorials/data/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons.json | **Fetched.** The HTML page is still client-rendered; this JSON form of it isn't | Not shown |
| App icon alpha rule | No official page found. Only Apple Developer Forums threads quoting the upload error | — |
| Third-party SDK list | Not refetched. The app ships no third-party SDKs | — |

## Extracts (quoted from today's fetch)

- **2.1(a):** "…placeholder text, empty websites, and other temporary content should be scrubbed before submission." "We will reject incomplete app bundles and binaries that crash or exhibit obvious technical problems."
- **2.3.3:** "Screenshots should show the app in use, and not merely the title art, login page, or splash screen."
- **2.3.7:** "…App names must be limited to 30 characters."
- **4.2:** "Your app should include features, content, and UI that elevate it beyond a repackaged website."
- **4.8:** applies to apps that "use a third-party or social login service (such as Facebook Login, Google Sign-In…)". wordsword uses only Sign in with Apple, so it doesn't apply.
- **5.1.1(i):** "All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner."
- **5.1.1(v):** "If your app supports account creation, you must also offer account deletion within the app."
- **SDK (since 2026-04-28):** "must be built with Xcode 26 or later using an SDK for iOS 26…"
- **Min target (since 2026-09-09):** "must target iOS 13 or later."
- **Age rating (since 2026-01-31):** "Provide responses to the updated age rating questions…"
- **DSA (since 2025-02-17):** "Apps without trader status will be removed from the App Store in the European Union (EU) until trader status is provided and verified."
- **Screenshots:**
  - At least one screenshot for "iPhone with Dynamic Island (medium display)": 1179×2556 or 1206×2622.
  - The large display is 1320×2868, among others. 1–10 per size.
  - "Images can't include alpha channels or transparencies."
  - "you only need to provide screenshots for the highest required resolution. App Store Connect automatically scales them down"
- **Required reason, UserDefaults — CA92.1:** "Declare this reason to access user defaults to read and write information that is only accessible to the app itself." The alternatives don't fit: 1C8F.1 covers App Groups, C56D.1 is for third-party SDKs only, and AC6B.1 covers MDM keys.
- **Icon alpha (forum-sourced, not an official rule page):** the upload validator's error ITMS-90717 reads "can't be transparent nor contain an alpha channel" ([forum thread 123146](https://developer.apple.com/forums/thread/123146), [thread 795411](https://developer.apple.com/forums/thread/795411)).
