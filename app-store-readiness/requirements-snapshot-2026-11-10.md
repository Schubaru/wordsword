# Requirements snapshot — 2026-11-10

Diff target: [requirements-snapshot-2026-11-02.md](requirements-snapshot-2026-11-02.md). **Nothing that affects wordsword changed since 11-02.** Two new items on Apple's side, neither blocking today: an iPhone Duo screenshot class (required from April 2027, iOS 27.1 SDK), and the Digital Goods and Services questionnaire page in App Store Connect Help.

| Source | Status | Apple's last-updated |
|---|---|---|
| https://developer.apple.com/app-store/review/guidelines/ | Fetched with curl (full page, 97k chars of text) | **October 16, 2026** (printed on the page; before the 11-02 fetch, so no change since then) |
| https://developer.apple.com/news/upcoming-requirements/ | Fetched | Newest item still 2026-09-09 |
| https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/ | Fetched | Not shown. **New: iPhone Duo row** |
| https://developer.apple.com/help/app-store-connect/manage-app-information/complete-the-digital-goods-and-services-questionnaire/ | Fetched (new this run) | Not shown |
| https://developer.apple.com/tutorials/data/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons.json | Fetched. 17 reason codes, CA92.1 among them | Not shown |
| https://developer.apple.com/app-store/app-privacy-details/ | Fetched (200) | Not shown |
| https://developer.apple.com/support/third-party-SDK-requirements/ | Fetched (200). Not applied: the app has no third-party SDKs | — |

## Extracts (quoted from today's fetch)

- **2.1(a):** "…placeholder text, empty websites, and other temporary content should be scrubbed before submission." "…binaries that crash or exhibit obvious technical problems."
- **2.3.3:** "…not merely the title art, login page, or splash screen."
- **2.3.7:** "App names must be limited to 30 characters."
- **4.2:** "…elevate it beyond a repackaged website."
- **4.8:** applies to "a third-party or social login service (such as Facebook Login, Google Sign-In…)". Not applicable: Sign in with Apple only.
- **5.1.1(i):** "…a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner."
- **5.1.1(v):** "If your app supports account creation, you must also offer account deletion within the app."
- **5.1.2(i):** "You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so." wordsword's model is on-device (Apple Foundation Models), so no third-party AI.
- **1.2:** UGC rules cover "social media, user-generated content platforms, and AI content creation apps." wordsword has no posting or sharing between users.
- **SDK (since 2026-04-28):** "must be built with Xcode 26 or later using an SDK for iOS 26…"
- **Min target (since 2026-09-09):** "must target iOS 13 or later."
- **Age rating (since 2026-01-31):** "Provide responses to the updated age rating questions…"
- **DSA (since 2025-02-17):** "Apps without trader status will be removed from the App Store in the European Union (EU) until trader status is provided and verified…"
- **Screenshots:** "At least one screenshot for iPhone with Dynamic Island (medium display)" — 1179×2556 or 1206×2622. Large is 1260×2736, 1290×2796 or 1320×2868. "Images can't include alpha channels or transparencies." "…you only need to provide screenshots for the highest required resolution."
- **iPhone Duo (new):** 1398×2034 outer, 2007×2853 inner. "Starting in April 2027, screenshots will be required for any app using the iOS 27.1 SDK or later." Not required for a build on the iOS 26.5 SDK.
- **Digital Goods and Services questionnaire (new to this snapshot):** "If you select No to 'Can customers consume digital goods and services in this app?', click Next." "If this questionnaire doesn't appear in App Store Connect for your app, no action is required." EU answers "remain locked for 12 months."
- **Required reason, UserDefaults — CA92.1:** still listed.
