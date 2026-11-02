# Requirements snapshot — 2026-11-01

Diff target: [requirements-snapshot-2026-10-22.md](requirements-snapshot-2026-10-22.md). **No Apple-side rule changes found since 10-22.** This run also fetched the metadata-field limits and the App Store search page, because this run writes the listing copy.

| Source | Status | Apple's last-updated |
|---|---|---|
| https://developer.apple.com/app-store/review/guidelines/ | Fetched (first 100k of 114k chars, through 5.2.5) | Not shown |
| https://developer.apple.com/news/upcoming-requirements/ | Fetched | Newest item 2026-09-09 (unchanged) |
| https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/ | Fetched | Not shown; same content as 10-22 |
| https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information | Fetched | Not shown |
| https://developer.apple.com/help/app-store-connect/reference/app-information/app-information | Fetched | Not shown |
| https://developer.apple.com/app-store/search/ | Fetched | Not shown |
| https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api | **FAILED**: client-rendered, empty body (5th run in a row) | — |
| Third-party SDK list | Not refetched; the app ships no third-party SDKs | — |

## Extracts (quoted from today's fetch)

- **2.1(a):** "…placeholder text, empty websites, and other temporary content should be scrubbed before submission. Make sure your app has been tested on-device … and include demo account info (and turn on your back-end service!) if your app includes a login."
- **2.3.1(a):** "…marketing your app in a misleading way, such as by promoting content or services that it does not actually offer … is grounds for removal…"
- **2.3.3:** "Screenshots should show the app in use, and not merely the title art, login page, or splash screen. They may also include text and image overlays…"
- **2.3.7:** "Choose a unique app name, assign keywords that accurately describe your app, and don't try to pack any of your metadata with trademarked terms, popular app names, pricing information, or other irrelevant phrases… App names must be limited to 30 characters. … [subtitles] should not include inappropriate content, reference other apps, or make unverifiable product claims."
- **2.3.8:** "…make sure your app and in-app purchase icons, screenshots, and previews adhere to a 4+ age rating even if your app is rated higher."
- **4.1(c):** "You cannot use another developer's icon, brand, or product name in your app's icon or name, without approval from the developer."
- **5.1.1(i):** "All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner."
- **5.1.1(v):** "If your app doesn't include significant account-based features, let people use it without a login. If your app supports account creation, you must also offer account deletion within the app."
- **5.1.2(i):** "You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so."
- **5.2.1:** "Don't use protected third-party material such as trademarks… without permission…"
- **SDK (since 2026-04-28):** "must be built with Xcode 26 or later using an SDK for iOS 26…"
- **Min target (since 2026-09-09):** "must target iOS 13 or later."
- **Age rating (since 2026-01-31):** "Provide responses to the updated age rating questions for each of your apps…"
- **Screenshots:**
  - "At least one screenshot for iPhone with Dynamic Island (medium display)": 1179×2556 or 1206×2622 portrait.
  - Dynamic Island (large) is 1260×2736, 1290×2796 or 1320×2868. Face ID (large) is "Required if app runs on iPhone and screenshots for iPhone with Dynamic Island (large display) aren't provided."
  - 1–10 per size, .png/.jpg. "Images can't include alpha channels or transparencies."
  - iPhone Duo is required from April 2027, and only for iOS 27.1 SDK builds.

## Metadata limits (today's fetch)
| Field | Limit |
|---|---|
| Name | 2–30 characters |
| Subtitle | 30 characters |
| Promotional text | 170 characters. It doesn't affect search ("promotional text doesn't affect your app's search ranking") |
| Description | 4,000 characters, plain text |
| Keywords | "limited to 100 characters total, with terms separated by commas and no spaces". The ASC reference says 100 bytes, and each keyword must be more than 2 characters |
| Support URL | Must lead to real contact information |

**Search (app-store/search):**
- "text relevance (matches for your app's title, subtitle, keywords, and primary category)" plus user behavior.
- "Don't repeat any words included in your app name, subtitle, or category." Plurals count as duplicates. Skip filler words.
- Don't use other apps' or companies' names.
- The page doesn't say whether the description is indexed.

**Required-reason codes:** not readable today. `CA92.1` (UserDefaults, app-only data) was last verified 2026-08-23. The new call sites (`LinkingWordsSave.swift`, `WordOfTheDay.swift`, `WordWheelSave.swift`) store only the app's own data.
