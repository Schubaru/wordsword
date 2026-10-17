# App Store readiness — wordsword — 2026-10-17

Previous report: [2026-08-23-readiness-2.md](2026-08-23-readiness-2.md). Requirements I fetched today: [requirements-snapshot-2026-10-17.md](requirements-snapshot-2026-10-17.md).

**Verdict:** not ready to submit. 3 blockers are still open, and the account-deletion work isn't committed yet.

**Since August:**
- **Closed:** nothing.
- **Code:** no new commits.
- **Apple:** the required screenshot size changed.
- **Toolchain:** Xcode 26.6 and an iOS 17 target are fine.

Approval is never guaranteed. Reviewers use their own judgment.

## Blockers (must fix in code)
- **Sign-in codes have no delivery, and the code shows on screen.** `Wordsword/AccountFlow.swift:357` displays "No server yet — your code is …". Guideline 2.1(a) says "turn on your back-end service!" Pick one:
  - **Sign in with Apple** (recommended): no backend needed, and 4.8 is satisfied automatically.
  - Or an email/SMS provider (Supabase, Resend, Twilio) that replaces the three `// stub:` bodies in `Auth.swift`.
  - Remove the on-screen code only *after* delivery works.
- **No privacy policy link in the app.** 5.1.1(i) requires one "within the app in an easily accessible manner."
  - Fill in the placeholders in `app-store-readiness/privacy-policy-draft.md` and host it.
  - Add a `Link("Privacy policy", …)` row to the About section of `SettingsView.swift`.
- **Code signing is disabled.** `project.yml:35,44` has `CODE_SIGNING_REQUIRED: "NO"` and no `DEVELOPMENT_TEAM`. Set your team, run `xcodegen generate`, and confirm Product → Archive works.
- **Commit the account-deletion work.** It's done but uncommitted (`Auth.swift`, `SettingsView.swift`, `PrivacyInfo.xcprivacy`, …). 5.1.1(v) requires it.

## Update together once sign-in is real (same build)
- Add the email or phone you collect to `NSPrivacyCollectedDataTypes` in `PrivacyInfo.xcprivacy`. Skip this if you use Sign in with Apple and only store Apple's user ID.
- Set the App Privacy labels in App Store Connect to match.
- Name the provider in section 2 of the privacy policy.

## Apple account / App Store Connect (start the slow ones first)
- **Enroll in the Apple Developer Program.** Signing and Sign in with Apple both depend on it. Start today.
- Register the bundle ID `com.alexschumacher.Wordsword`. Enable Sign in with Apple if you chose it. That also needs a new `.entitlements` file.
- Create the app record: name (check it's available), primary language, SKU. Free, no in-app purchases.
- Answer the age-rating questionnaire honestly. The dictionary content is unfiltered.
- **Screenshots:** at least one for the medium Dynamic Island iPhone: **1206×2622 or 1179×2556** portrait. 1320×2868 is optional. No alpha channel.
- Review notes: a demo account (a test identifier with a fixed code, or a real inbox you control), where Delete account lives, how hold-to-speak works, and that the dictionary API is third-party.
- Set your EU trader (DSA) status if you distribute in the EU.
- Export compliance is already answered (`ITSAppUsesNonExemptEncryption = false`).

## Before you hit Submit
- Archive → Validate → Upload, then **install from TestFlight on your own iPhone**. Test the microphone, speech, account deletion with real data, and offline saved words. The simulator can't stand in for these.
- Optional polish: dark mode (currently forced Light) and Dynamic Type at the largest sizes.
- Run `/app-store` again to get a clean "no known blockers" verdict.

## Order
Enroll → decide on sign-in → build it and remove the on-screen code → host the policy and add the link → turn signing on → commit → screenshots and metadata → TestFlight on a device → submit.

## Verification
- `strings` on the Release binary shows 0 matches for "No server yet".
- Archive succeeds with signing on.
- The TestFlight build works on a real device.

## Update, later on 2026-10-17: sign-in blocker fixed in code

The app now uses Sign in with Apple instead of email/phone codes.
- **Code:**
  - `Auth.signIn(userID:givenName:)` and `checkCredential()` are added.
  - `AccountFlow` is now two steps: the Continue with Apple button, then the username.
  - The entitlement is in `project.yml`.
- **Verified:**
  - Release build succeeds.
  - `strings` finds 0 matches for "No server yet".
  - The self-check passes. One assertion was inverted to confirm it runs: the app crashed, then survived after reverting.
  - The snapshot tour shows the new screens.
- **Not verified:** a real Apple sign-in. That needs a signing team plus the capability enabled on the bundle ID, so test it on a device through TestFlight.
- **Privacy:** only the name is requested, never email, and nothing leaves the device. `PrivacyInfo.xcprivacy` is unchanged. The privacy policy draft's section 2 is rewritten.
- **Known risk:** tokens aren't revoked on delete. Apple's account-deletion page says apps "should" use the REST API to revoke tokens, and that needs a server. Instead, the delete dialog tells people how to remove wordsword from their Apple ID (path from Apple support article 102571).
- **Review notes:** no demo account is needed. Say "Sign in with Apple; any Apple ID works."
