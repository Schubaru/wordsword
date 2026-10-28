# Requirements snapshot — 2026-10-22

Diff target: [requirements-snapshot-2026-10-17.md](requirements-snapshot-2026-10-17.md). **No Apple-side changes found since 10-17.**

| Source | Status | Apple's last-updated |
|---|---|---|
| https://developer.apple.com/app-store/review/guidelines/ | Fetched (first 100k of 114k chars; read through 5.2.5) | Not shown on the page |
| https://developer.apple.com/news/upcoming-requirements/ | Fetched | Newest item: 2026-09-09 (same as 10-17) |
| https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/ | Fetched | Not shown; content same as 10-17 |
| https://developer.apple.com/support/third-party-SDK-requirements/ | Fetched | Not shown; 86 SDKs listed |
| https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api | **FAILED**: client-rendered, empty body | — |
| https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest | **FAILED**: client-rendered, empty body | — |

## Extracts (quoted from today's fetch)

- **2.1(a):** "placeholder text, empty websites, and other temporary content should be scrubbed before submission. Make sure your app has been tested on-device … and include demo account info (and turn on your back-end service!) if your app includes a login."
- **4.8:** applies to apps using "a third-party or social login service (such as Facebook Login, Google Sign-In, …)". Sign in with Apple isn't on that list.
- **5.1.1(i):** "All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner."
- **5.1.1(ii):** "Ensure your purpose strings clearly and completely describe your use of the data."
- **5.1.1(v):** "If your app doesn't include significant account-based features, let people use it without a login. If your app supports account creation, you must also offer account deletion within the app."
- **SDK (since 2026-04-28):** "must be built with Xcode 26 or later using an SDK for iOS 26 …"
- **Min target (since 2026-09-09):** "must target iOS 13 or later."
- **Screenshots:** "At least one screenshot for iPhone with Dynamic Island (medium display)": 1179×2556 or 1206×2622 portrait. No alpha. iPhone Duo screenshots will be required from April 2027 for apps built with the iOS 27.1 SDK or later.
- **Third-party SDKs:** the list starts with Abseil, AFNetworking, Alamofire, AppAuth, BoringSSL. wordsword ships no third-party SDKs, so the list doesn't apply.
- **Required-reason codes:** not readable today. `CA92.1` for UserDefaults was last verified against TN3183 on 2026-08-23. The app still only uses UserDefaults for its own data (new call sites in `WordOfTheDay.swift` and `WordWheelSave.swift` fit the same reason).
