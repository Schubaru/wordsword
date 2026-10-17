# Privacy policy — DRAFT for wordsword

**This is a draft, not legal advice.** It was written from what the code actually does, audited on
2026-08-23, so the factual claims are accurate as of that commit. Read it, correct anything that
does not match your intent, and have it reviewed if you want certainty. You must host it at a
public URL before submitting — App Store guideline 5.1.1(i) requires the link in App Store Connect
**and** inside the app.

**Fill in before publishing:** `[EFFECTIVE DATE]` and `[CONTACT EMAIL]`.

**Updated 2026-10-17 for Sign in with Apple.** Accounts use Sign in with Apple. The app requests only
the name scope, not email, and the Apple user ID and name stay on the device. **Re-check §2 if you
ever add a server or sync** — that is the change that would make the App Privacy labels change.

---

## Privacy Policy for wordsword

**Effective date:** [EFFECTIVE DATE]

wordsword is a dictionary and vocabulary app. It is built to keep your data on your phone. This
policy explains the few things that leave it, and why.

### 1. What stays on your device

Everything you build in wordsword is stored locally on your iPhone and is never uploaded to us:

- Words you save, and the definitions, examples, pronunciations, and synonyms attached to them
- Your wordlists and tags
- Your flashcard review history and scheduling
- Your recent search history
- Your username

We do not operate a server that receives this information, and we cannot see it. Deleting the app
removes all of it.

### 2. Your account

Accounts use Sign in with Apple. When you sign in, Apple gives wordsword an anonymous identifier
for your account and, the first time only, your first name if you choose to share it. We use the
name only to suggest a username. We do not ask Apple for your email address.

Both stay on your iPhone. We do not operate a server that receives them, and we cannot see them.
Signing in is handled by Apple under Apple's privacy policy (<https://www.apple.com/legal/privacy/>).

Creating an account is optional. Every part of wordsword works without one except flashcards.

### 3. What is sent when you look up a word

To define a word, wordsword sends **the word you looked up** to two third-party services:

| Service | What is sent | Why |
|---|---|---|
| Free Dictionary API (dictionaryapi.dev) | the word | definitions, examples, pronunciation |
| Datamuse (api.datamuse.com) | the word | synonyms and spelling suggestions |

When you play a pronunciation, your device also downloads the audio file for that word from the
Free Dictionary API's host.

These requests carry the word itself. They do not carry your name, your account, your username, or
any identifier we attach — the services receive the word and the ordinary network information any
web request includes, such as your IP address. We do not send them your saved library or your
history, and we do not ask them to associate lookups with you.

Words already saved to your library are defined from your device and are not re-sent.

### 4. Voice input

If you hold the search field to speak a word, wordsword uses Apple's speech recognition to turn
your speech into text.

**Where this happens depends on your device.** On devices that support on-device speech
recognition, the audio never leaves your iPhone. On devices that do not, **the recorded audio is
sent to Apple** for transcription, and Apple's privacy policy governs that processing. wordsword
requests on-device recognition whenever your device is capable of it.

The microphone is used only while you are actively holding the control. Audio is used only to
produce the word you are searching for. We never store recordings, and we never transmit audio to
anyone other than Apple's speech recognition service as described above.

You can decline microphone or speech-recognition access, or revoke it later in iOS Settings, and
continue using wordsword by typing.

### 5. What we do not do

- We do not use analytics or crash-reporting SDKs.
- We do not use advertising, and we do not track you across apps or websites. wordsword does not
  ask for App Tracking Transparency permission because it has nothing to track you with.
- We do not build a profile about you.
- We do not sell or share your personal data with anyone for their own purposes.
- We do not knowingly collect personal information from children.

### 6. Retention and deletion

Because your library lives on your device, you control it:

- **Delete your account:** Settings → Delete account. This removes your account identifier and
  username from the device permanently. Your saved words stay unless you also clear them. To also
  remove wordsword from your Apple ID: iOS Settings → your name → Sign in with Apple → wordsword →
  Delete.
- **Delete your words:** Settings → Clear all my words. This removes every saved word and wordlist.
- **Delete everything:** delete the app. All local data goes with it.
- **Withdraw permission:** revoke microphone or speech-recognition access at any time in iOS
  Settings → wordsword.

We do not retain copies of your library or your account, because we never receive them.

The third-party services in §3 receive the word you looked up. Their retention is governed by their
own policies:

- Free Dictionary API — <https://dictionaryapi.dev>
- Datamuse — <https://www.datamuse.com/api/>
- Apple speech recognition — <https://www.apple.com/legal/privacy/>

To ask a question about your data or request deletion of anything we hold, email
**[CONTACT EMAIL]**. We will respond within 30 days.

### 7. Changes

If this policy changes materially, we will update the effective date above and note the change in
the app's release notes.

### 8. Contact

**[CONTACT EMAIL]**
