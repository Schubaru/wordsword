# Requirements snapshot — 2026-10-17

Diff target: [requirements-snapshot-2026-08-23.md](requirements-snapshot-2026-08-23.md).

| Source | Status | Notes |
|---|---|---|
| https://developer.apple.com/app-store/review/guidelines/ | Fetched (first 100k of 114k chars) | No "last updated" date in the fetched text. |
| https://developer.apple.com/news/upcoming-requirements/ | Fetched | Latest item dated 2026-09-09. |
| https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/ | Fetched | **Changed since August.** |
| Privacy manifest / required-reason API docs | Not re-fetched | `CA92.1` was verified against TN3183 on 2026-08-23. The app adds no new API use. |

## Extracts

- **2.1(a):** "include demo account info (and turn on your back-end service!) if your app includes a login." Same as in August.
- **4.8:** If you use a third-party or social login, you must also offer an equivalent option that limits data to name and email, lets users keep their email private, and doesn't collect interactions for ads without consent.
- **5.1.1(i):** "All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner." Same as in August.
- **5.1.1(v):** "If your app supports account creation, you must also offer account deletion within the app." Same as in August.
- **SDK (since 2026-04-28):** builds must use Xcode 26 or later with the iOS 26 SDK. **Minimum target (since 2026-09-09, new):** iOS 13 or later.
- **Age rating:** the updated questionnaire has been required since 2026-01-31.
- **EU DSA:** apps without trader status are removed from the EU store.
- **Screenshots (new):** "At least one screenshot for iPhone with Dynamic Island (medium display)."
  - Medium sizes: 1179×2556 or 1206×2622 portrait.
  - The large size (1320×2868) is no longer the one required.
  - iPhone Duo screenshots become required in April 2027 for apps built with the iOS 27.1 SDK or later.
