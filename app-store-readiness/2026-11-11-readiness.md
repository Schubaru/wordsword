# App Store readiness — wordsword — 2026-11-11

Previous report: [2026-11-10-readiness.md](2026-11-10-readiness.md). Requirements fetched today: [requirements-snapshot-2026-11-11.md](requirements-snapshot-2026-11-11.md). Listing copy: [app-store-listing.md](app-store-listing.md).

## Verdict
**No known blockers remain.** Build **1.0 (2)**, archived from `989b580`, is uploaded and processing in App Store Connect. It's the build to test and submit. Build 1 still has the NYT-style colours, share squares and labels, so don't submit it.

What's left happens in App Store Connect and on your phone: fill in the version page, test build 2 in TestFlight, then submit. This run changed two pieces of copy to match the new game endings (see Fixed automatically). It made no code changes.

Approval is never guaranteed. Reviewers use judgment, and this audit covers the repo plus the guidelines as published today.

## Requirements freshness
| Source | Status | Apple's last-updated |
|---|---|---|
| App Store Review Guidelines | Fetched | October 16, 2026 [summary]. No change since 11-10. |
| Upcoming requirements | Fetched | Newest item Sept 9, 2026. No change. |
| Screenshot specifications | Fetched | No change. iPhone Duo is still only for iOS 27.1 SDK builds, from April 2027. |
| Required-reason API codes (JSON) | Fetched | CA92.1 is still listed. |

**Toolchain:** Xcode 26.6 with the iOS 26.5 SDK meets "Xcode 26 or later … SDK for iOS 26". The iOS 17 target meets "iOS 13 or later".

## Since last run (2026-11-10)
**Closed (1):**
- **B2. Signing** is closed. Build 1.0 (1) was uploaded on 11-10, and build 1.0 (2) on 11-11. Both were signed with team `DJKZQ223JK` and passed the upload validator.

**New code reviewed:** the Plexicon and Linking words re-skin, 16 files from `adc6029` to `989b580`.
- **4.1(a) Copycats.** This was the main risk, and it's now much lower. Plexicon has pen circles and underlines instead of green and yellow tiles. Linking words has four inks that don't encode difficulty. Both have their own share symbols, their own stats labels, and end on a meaning. No NYT name or brand appears anywhere (4.1(c)). The game rules themselves (5 letters and 6 tries; 16 words in four groups) aren't something 4.1 or 5.2.1 protects, but a reviewer could still compare the games.
- **2.1(a).** The meaning fetch fails quietly. The results screen shows without it when offline (`PlexiconView.swift:237`), so nothing blank or broken appears.
- **Required-reason APIs.** The only new storage is `wotd.meaning.*` in UserDefaults (`WordOfTheDay.swift:17`). It's the app's own data, covered by CA92.1.
- **No new debug hooks or env vars.** None were added in this change.
- **Screenshots.** Panels 06 and 07 were re-shot at 1206×2622 and 1320×2868, with no alpha. The 6.3 set fills the required "Dynamic Island (medium display)" slot.
- **Credits.** The CC BY-SA credits are live in Settings → About and on https://schubaru.github.io/wordsword/support.html. I checked both today.

**New (2), both fixed this run:**
- **N6. The privacy policy undercounted what's sent, again.** §3 said only "the word you looked up" goes to the dictionary services. Since the re-skin, the Plexicon word and the four Linking words headwords are also sent, to fetch their meanings, and so is the word of the day. That last one was already true before and never listed. It's still only words, with no identifiers. Fixed in `docs/privacy.html`.
- **N7. The listing pitched Plexicon in Wordle's own terms.** "A new five-letter word every day, found in six guesses" is close to how Wordle describes itself, and it left out the part that's yours. Under 4.1(a) a reviewer reads the description too. Fixed in `app-store-listing.md`.

## Blockers
None.

## Likely rejection — reviewer discretion
- **R1. 4.1(a) comparison with Wordle and Connections, now low.** The look, labels and shares are your own. What's left is the rules, which are generic to the genre. If a reviewer raises 4.1 anyway, reply in the Resolution Center. Point out that the marks, colours, share format and labels are original, and that every game ends on a word's meaning. Never name the NYT in the listing.

## Polish
- **P1. Datamuse needs an API key from 2027-02-01** (`Dictionary.swift:231`). Not a review issue today, but definitions break on that date. Datamuse asks customer-facing apps to get in touch first. 5.2.2 asks you to use a service only "under the service's terms of use", and today's use is within them. Email them before launch or soon after.
- **P2. Haikuzy has 60 haiku.** They run to Jan 8, and then winter repeats. Carried over from 11-10.
- **P3. Cold model vs. the 8s timeout** (`Simplifier.swift:177`). Carried over from 11-10. Check it in TestFlight.

## Unverified
These need build 2 on a real iPhone, through TestFlight:
- Sign in with Apple end to end: sign in, sign out, delete account, and revoking in iOS Settings. **It has never run end to end on a release-signed build.**
- The mic and speech prompts, and the path when you deny them.
- Model replies on an Apple Intelligence iPhone (P3).
- Plexicon and Linking words results showing a meaning, and how the share text looks once it lands in Messages.
- The daily games across a real midnight.
- **Build 2 processing.** The upload said "Upload succeeded" and "processing". I can't see App Store Connect from here. Check that build 2 shows up under TestFlight and that Apple sent no "issues" email.

## N/A — checked, does not apply
- **3.1.1 / 3.1.2:** no StoreKit and no paywall. Word Wheel coins can't be bought.
- **4.8:** Sign in with Apple is the only login.
- **5.1.2(i) third-party AI:** the model runs on the device.
- **1.2 user-generated content:** nothing passes between users. Shares go to the iOS share sheet.
- **Third-party SDKs and manifests:** there are none. The UITests target's `CODE_SIGNING_REQUIRED: NO` (`project.yml:50-51`) applies only to tests and isn't shipped.
- **iPad:** the app is iPhone only.

## Fixed automatically
### `docs/privacy.html`: N6
- Added under §3: "The word of the day, the Plexicon word and the Linking words groups are sent the same way, to fetch the meaning shown with them."
- Changed the effective date to November 11, 2026.
- **It goes live when `main` is pushed.**

### `app-store-listing.md`: N7
- Description: "Plexicon: a new five-letter word every day. Find it, then see what it means." The description is now 1939 / 4000 characters.
- Review notes: Plexicon and Linking words are now described by what they do, including the meanings at the end. The notes are now 1641 characters.
- **If you already pasted the description or notes into App Store Connect, paste them again.**

## Needs your decision
1. **D4. Datamuse.** Email Datamuse now (I can draft it), or after launch? Either way, it should happen before 2027-02-01.

## Next steps
### In the codebase
1. **[me]** Commit this run and push `main`. That puts the privacy fix live.

### In App Store Connect
2. **[you]** Wait for build 2 to finish processing (TestFlight tab).
3. **[you] TestFlight:** add yourself as an internal tester, install build 2, and run every Unverified check.
4. **[you] App Information** (if not done already):
   - Name `wordsword: AI Dictionary`.
   - Subtitle `Thesaurus, flashcards & games`.
   - Categories Reference + Games → Word.
   - Privacy Policy URL https://schubaru.github.io/wordsword/privacy.html
   - The age-rating questionnaire. Drafts are in listing §8.
   - Digital Goods: **No**.
5. **[you] App Privacy:** Data Not Collected. **Pricing:** free.
6. **[you] Version 1.0 page:**
   - Screenshots from `screenshots/6.3`, plus `6.9` if you like.
   - Description, keywords and promo text from the listing.
   - Support URL https://schubaru.github.io/wordsword/support.html
   - Review notes from listing §7.
   - **Select build 2.**
7. **[you] Submit for review** with **manual release**.
