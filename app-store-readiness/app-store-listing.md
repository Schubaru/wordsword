# wordsword — App Store listing copy

Drafted 2026-11-01 for the first App Store submission; updated 2026-11-10 for Plexicon, Haikuzy and Alex's name and category picks. Paste-ready. Every count below was computed by a script (Python `len()` for characters, `len(s.encode())` for keyword bytes), not estimated. Apple's limits are the ones fetched live on 2026-11-01.

Only features that ship today are described. Not mentioned anywhere because they don't exist: backup, sync, multiple devices, widgets, ads, purchases.

---

## 1. Name (limit 2–30 characters) — updated 2026-11-10

Alex's pick, `wordsword: AI Dictionary & Games`, is **32 characters**: two over the limit in 2.3.7 ("App names must be limited to 30 characters"), so App Store Connect won't take it. Two pairings keep both halves of that idea. Name and subtitle are both indexed for search, so either one covers "AI", "dictionary" and "games".

**Pairing A (recommended):**

```text
wordsword: AI Dictionary
```
**24 / 30 characters.**

```text
Thesaurus, flashcards & games
```
**Subtitle, 29 / 30 characters.**

**Pairing B:**

```text
wordsword: Dictionary & Games
```
**29 / 30 characters.**

```text
Thesaurus, flashcards & AI
```
**Subtitle, 26 / 30 characters.**

**About "AI" in the name.** 2.3.1(a) rules out "promoting content or services that it does not actually offer." The AI is real, but only on iPhones with Apple Intelligence turned on. Elsewhere, "Explain it differently" uses the dictionary's wording, and since 2026-11-10 the headline definition is the dictionary's own words on every iPhone. Keep the description's "On supported devices…" sentence (section 5) and the review note that says so; together they make the claim accurate. Neither pairing repeats a word or names another app (2.3.7).

## 3. Keywords (limit 100 bytes)

```text
definition,define,meaning,synonym,vocabulary,spelling,pronunciation,puzzle,learn,english,anagram
```
**96 / 100 bytes**, 11 terms, comma-separated with no spaces after commas.

Not repeated from the name, subtitle or category: wordsword, dictionary, AI, thesaurus, flashcard(s), game(s), reference. ("word" is no longer in the name under either pairing. The "Games → Word" category may index it, but Apple doesn't say so, so add `word` back in place of `anagram` if search shows it isn't matching.) Singular forms only (plurals would count as duplicates).

**High-intent terms left out, and why:**

| Term | Why it's out |
|---|---|
| dictionary, thesaurus, word, words, flashcards, games | Already indexed from the name or subtitle. Repeating wastes bytes. |
| reference, education | Indexed from the category. |
| antonym, opposite | The app doesn't show antonyms (2.3.1). |
| etymology, origin | The app doesn't show word origins (2.3.1). |
| crossword | Neither game is a crossword. Misleading (2.3.1). |
| offline dictionary | Only words already saved open offline; new lookups need a connection. Would over-promise. |
| AI, chatbot | Explanations come from the on-device model only on supported devices, and there's no free-text chat. Risky as a headline claim. |
| translate, translator, spanish | English only. |
| SAT, GRE, test prep | Implies a study program the app doesn't have. |
| vocab | Ran out of bytes; "vocabulary" covers the main intent. Swap in if "learn" underperforms. |
| daily, spell, lookup, wheel, study | Lower intent; cut to fit 100 bytes. "daily" is the first one to add back if space frees up. |
| kids | The app isn't built for the Kids category; listing it there brings rules the app doesn't meet. |
| free | Price shows on the listing already; filler. |
| Any other app's or company's name | Not allowed (2.3.7). |

If the name changes to alternate 2, swap `define` for `dictionary` (bytes: 100).

## 4. Promotional text (limit 170 characters)

```text
New: Haikuzy, a daily haiku with one word missing, and Plexicon, a daily five-letter word. Look up any word in one plain sentence; it waits in your library.
```
**156 / 170 characters.** Not indexed for search, so it's free to talk about what's new. It can be changed without a new build; swap it when there's news.

## 5. Description (limit 4000 characters)

```text
You hit a word mid-chapter. wordsword tells you what it means in one plain sentence, then gets out of the way so you can get back to the page.

And it keeps the word. Everything you look up is saved, so next week it's still there, not lost in your browser history.

LOOK IT UP FAST
• Plain-English definitions, not a wall of every sense at once.
• Misspelled it? You'll get suggestions.
• Tap the mic and say the word instead of typing it.
• See how it's said with an easy respelling, and tap to hear it.

FOLLOW UP WITHOUT TYPING
Under every definition sit three taps:
• Explain it differently. Each tap tries a new angle. On supported devices this is written by Apple's on-device model; everywhere else you get the dictionary's own wording.
• Use it in a sentence.
• More synonyms.

KEEP YOUR WORDS
• Every word lands in your library on its own.
• Make wordlists. Think playlists, but for words.
• Follow a chain of synonyms from word to word, then save the chain as a wordlist.
• Words you've saved open even when you're offline.

REMEMBER THEM
• Flashcards bring a word back just before you'd forget it (spaced repetition).
• A new word of the day, every day.

PLAY WITH WORDS
• Haikuzy: a new haiku every day with one word missing. You get four guesses, and each one scores how close it came.
• Plexicon: a new five-letter word every day, found in six guesses.
• Linking words: a new puzzle every day. Sort 16 words into four groups that mean the same thing, and keep track of your stats.
• Word Wheel: drag across a wheel of letters to spell words. The levels keep coming.
Every word you find in a game is one you can look up.

YOUR WORDS STAY ON YOUR PHONE
Everything is stored on this iPhone, not in the cloud. To define a word, the app sends only that word to open dictionary and thesaurus services. No ads, no purchases, no tracking.

No account needed. Sign in with Apple if you'd like a username; that's all it does.
```
**1928 / 4000 characters** (plain text; the bullets are the "•" character).

Honesty checks: AI explanations are scoped to "supported devices" with the dictionary fallback named. No backup or sync claimed; it says outright that words are stored on the phone, not in the cloud. "No tracking" matches the "Data Not Collected" label below.

## 6. Category — Alex's call

**Chosen 2026-11-10:** primary **Reference**, secondary **Games → Word**. (The earlier recommendation was Reference + Education. With four games in the app, Games → Word is the better second shelf.)

Rationale: the reason someone opens wordsword is to look a word up mid-book, and that's what Reference is for. Reference is also a smaller, quieter category than Games, so a new app has a real chance of showing up in its charts, and the category name itself is indexed for search alongside the title. Education as secondary fits the flashcards and the "remember the words you looked up" promise. Games → Word is the right home only if the two games become the main draw: it puts the app next to much bigger, more established word games, and a primary Games category may push reviewers to judge it as a game first and a dictionary second. Start with Reference; revisit if the games end up driving most installs.

## 7. Review notes (paste into App Store Connect → App Review Information → Notes)

```text
No login is needed. Every feature works without an account.

Sign in with Apple is optional. It only sets a username shown in the app; no data leaves the phone and there is no server account.

To delete an account: sign in with Apple first (Settings → You → Create an account or sign in), then Settings → You → Delete account. Words already saved stay on the phone.

Voice lookup: tap the mic in the search field and say a word. The app asks for microphone and speech recognition permission the first time.

Definitions and synonyms come from Datamuse (api.datamuse.com) and dictionaryapi.dev. Both are free, public APIs. The app sends only words (the one looked up, plus a few from its definition and synonyms), with no identifiers.

"Explain it differently" (a follow-up under each definition) uses Apple's on-device Foundation Models when the device supports it. On other devices it falls back to wording from the dictionary entry. Each tap gives a new angle. Users can't type free text to the model; the only inputs are the three follow-up buttons.

Games (Home → Play with words): Haikuzy (a daily haiku with one word missing, 4 guesses scored 1–100), Plexicon (a daily five-letter word, 6 guesses), Linking words (a daily puzzle) and Word Wheel (spell words from a letter wheel). The daily games change at local midnight. Word Wheel coins are earned by playing and spent on hints. They can't be bought and have no cash value. The haiku are original, written for the app.

Everything is stored on the device. No ads, no in-app purchases, no tracking.
```
**1555 characters.**

## 8. Age-rating questionnaire — draft answers

> **Alex must answer the live questionnaire in App Store Connect, honestly, question by question.** These drafts are based on what the code does today. Apple's live wording governs; if a question below doesn't match what you see, go by what the app actually does, not by this draft.

Two facts drive the answers:

1. **Definitions come unfiltered from a third-party API (dictionaryapi.dev).** Anyone can type any word, including crude, sexual or offensive ones, and the definition is shown as the API returns it. (Word Wheel's built-in word lists do have a slur blocklist, but lookups are not filtered.)
2. **There's on-device AI-generated text.** On supported devices "Explain it differently" rewrites the definition with Apple's on-device model. The user can't type a prompt; it only rephrases whatever word was looked up, so it inherits fact 1.

| Topic | Draft answer | Reason |
|---|---|---|
| Profanity or crude humor | Infrequent / mild | Only if the user looks up such a word; the app never shows it unprompted. |
| Mature or suggestive themes | Infrequent / mild | Same: definitions of sexual or adult terms appear only when looked up. |
| Sexual content or nudity (incl. graphic) | None | Text definitions only, no images; nothing graphic beyond what a dictionary entry says. |
| Cartoon, realistic or prolonged graphic violence | None | |
| Horror / fear themes | None | |
| Alcohol, tobacco or drug use or references | None (consider Infrequent) | Definitions of such words exist if looked up. Use the same judgment as profanity for consistency. |
| Medical or treatment information | None | A definition isn't medical advice. |
| Guns or other weapons | None | |
| Gambling / simulated gambling | None | Word Wheel coins are earned by playing and spent on hints; no chance mechanics, no cash value, can't be bought. |
| Contests | None | |
| Unrestricted web access | No | No browser or web view; only two fixed APIs. |
| User-generated content | No | Wordlists and libraries are private to the phone; nobody sees anyone else's content. The Linking words, Plexicon and Haikuzy "Share" buttons send the player's own result out through the system share sheet. |
| Messaging and chat | No | The "chat" is tap-only definitions, not people talking to people, and has no text field. |
| Advertising | No | |
| Parental controls / age assurance | No | |
| AI or generated content (if asked) | Yes | On-device text generation for "Explain it differently" on supported devices; fixed buttons only, no free-text prompt. |

Expected outcome: a low rating with the two "Infrequent" content answers. Apple computes the final rating from the answers; don't pick a rating, answer the questions. Note 2.3.8 is about metadata: everything in this file is written to suit a 4+ audience regardless of the computed rating.

## 9. App Privacy

**Data Not Collected.** Nothing reaches the developer: words, wordlists, stats and the optional username live only on the phone, and lookups send just the word (no identifiers) to dictionaryapi.dev and Datamuse.

(Voice lookup uses Apple's speech recognition, which Apple handles under its own terms; the app keeps only the recognized word.)

## 10. URLs

| Field | URL |
|---|---|
| Privacy Policy URL | https://schubaru.github.io/wordsword/privacy.html |
| Support URL | https://schubaru.github.io/wordsword/support.html |
| Marketing URL | https://schubaru.github.io/wordsword/ |

All three were live on 2026-11-01 (HTTP 200, served by GitHub Pages from `docs/`). Open them once more before submitting; App Review rejects a dead privacy or support link.
