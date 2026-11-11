# Requirements snapshot — 2026-11-11

All sources were fetched today. Each returned HTTP 200 and none had moved. Where a quote is a model summary of the page rather than the page's own words, it's marked [summary].

| # | Source | Status | Last updated |
|---|---|---|---|
| 1 | https://developer.apple.com/app-store/review/guidelines/ | Fetched (two chunks; 5.x read as summary) | "October 16, 2026" [summary]. No change since 11-10. |
| 2 | https://developer.apple.com/news/upcoming-requirements/ | Fetched in full | Newest item is dated Sept 9, 2026. No change. |
| 3 | https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/ | Fetched [summary] | Not shown |
| 4 | …/nsprivacyaccessedapitypereasons.json | Fetched in full | Not shown |

## Extracts cited this run
- **2.1(a):** "final versions with all necessary metadata and fully functional URLs included"; "placeholder text, empty websites, and other temporary content should be scrubbed before submission."
- **2.3.7:** "App names must be limited to 30 characters." Subtitles "should not … reference other apps, or make unverifiable product claims."
- **4.1(a) Copycats:** "Don't simply copy the latest popular app on the App Store, or make some minor changes to another app's name or UI and pass it off as your own." **4.1(c):** "You cannot use another developer's icon, brand, or product name in your app's icon or name … without approval from the developer."
- **4.2:** "features, content, and UI that elevate it beyond a repackaged website."
- **5.1.1(i)** [summary]: there must be a privacy policy link "in the App Store Connect metadata field and within the app."
- **5.1.1(v)** [summary]: "If your app supports account creation, you must also offer account deletion within the app."
- **5.2.1** [summary]: "Don't use protected third-party material such as trademarks, copyrighted works, or patented ideas…"
- **5.2.2** [summary]: when using a third-party service, "ensure that you are specifically permitted to do so under the service's terms of use."
- **Upcoming requirements:** "must be built with Xcode 26 or later using an SDK for iOS 26…" (since Apr 28, 2026); "must target iOS 13 or later" (since Sept 9, 2026).
- **Screenshots** [summary]:
  - Required: "At least one screenshot for iPhone with Dynamic Island (medium display)", meaning 1179×2556 or 1206×2622.
  - The large display (1260×2736, 1290×2796 or 1320×2868) is optional.
  - iPhone Duo screenshots are required "Starting in April 2027 … for any app using the iOS 27.1 SDK or later."
- **CA92.1** is still listed: "access user defaults to read and write information that is only accessible to the app itself."
