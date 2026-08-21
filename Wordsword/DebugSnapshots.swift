#if DEBUG
import SwiftUI

/// Dev-only: `SIMCTL_CHILD_SHOTS_DIR=/some/dir xcrun simctl launch <udid> com.alexschumacher.Wordsword`
/// walks every screen and writes PNGs of the live window. Lets us eyeball the UI on machines where
/// `simctl io screenshot` / XCUITest are locked behind the Xcode license prompt. Not compiled in Release.
enum DebugSnapshots {
    static func runIfRequested(_ router: Router, _ auth: Auth) {
        guard let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"] else { return }
        let out = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        @MainActor func snap(_ name: String, after s: Double = 1.2) async {
            try? await Task.sleep(for: .seconds(s))
            guard let w = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
            let img = UIGraphicsImageRenderer(bounds: w.bounds).image { _ in w.drawHierarchy(in: w.bounds, afterScreenUpdates: true) }
            try? img.pngData()?.write(to: out.appendingPathComponent(name + ".png"))
        }
        // Voice-only run: pose each hold-to-speak state and get out. Keeps the full tour untouched.
        if ProcessInfo.processInfo.environment["VOICE_SHOTS"] != nil {
            Task { @MainActor in
                auth.hasSeenStory = true
                auth.debugSignIn()
                router.path = []
                router.debug = "voice:idle";      await snap("v1-idle", after: 1.4)
                router.debug = "voice:arming";    await snap("v2-arming", after: 0.5)
                router.debug = "voice:listening"; await snap("v3-listening", after: 0.6)
                router.debug = "voice:speaking";  await snap("v4-speaking", after: 0.6)
                router.debug = "voice:settled";   await snap("v5-settled", after: 0.6)
                router.debug = "voice:idle";      try? await Task.sleep(for: .milliseconds(600))
                router.debug = "voice:uncertain"; await snap("v6-uncertain", after: 0.9)
                router.debug = "voice:idle";      try? await Task.sleep(for: .milliseconds(600))
                router.debug = "voice:nothing";   await snap("v7-nothing", after: 0.7)
                router.debug = "voice:idle";      try? await Task.sleep(for: .milliseconds(600))
                router.debug = "voice:denied";    await snap("v8-denied", after: 0.7)
                print("SHOTS DONE")
            }
            return
        }

        Task { @MainActor in
            // --- first run: splash → story → account ---
            auth.signOut()
            auth.username = ""
            auth.hasSeenStory = false
            await snap("01-splash", after: 0.45)

            router.debug = "story:0"; await snap("02-story-book", after: 1.4)
            router.debug = "story:1"; await snap("03-story-define")
            router.debug = "story:2"; await snap("04-story-kept")

            router.debug = "story:done"; await snap("05-account-choice")
            router.debug = "acct:id";    await snap("06-identifier")
            router.debug = "acct:code";  await snap("07-code", after: 2)
            router.debug = "acct:bad";   await snap("08-code-wrong")
            router.debug = "acct:name";  await snap("09-username")

            // --- signed out: the app still works, flashcards ask for an account ---
            auth.hasSeenStory = true
            router.path = []; await snap("10-home-empty")
            router.path = [.library, .flashcards(nil)]; await snap("11-flashcards-locked")

            // --- signed in: the rest of the app ---
            auth.debugSignIn()
            router.path = [.define("sanguine")]; await snap("12-define", after: 5)
            router.debug = "sentence"; await snap("13-sentence", after: 2)
            router.debug = "explain";  await snap("14-explain", after: 2)
            router.debug = "follow:optimistic"; await snap("15-chain", after: 5)
            router.debug = "more";     await snap("16-more-synonyms", after: 3)
            router.debug = "sheet";    await snap("17-add-to-wordlist", after: 1.5)
            router.debug = "unsheet"
            router.path = [.define("ubiquitious")]; await snap("18-did-you-mean", after: 5)
            router.path = [.define("halcyon")];     await snap("19-halcyon", after: 5)
            router.path = []; await snap("20-home-history")
            router.path = [.library]; await snap("21-library")
            router.path = [.library, .flashcards(nil)]; await snap("22-flashcard-front", after: 1.5)
            router.debug = "flip"; await snap("23-flashcard-back", after: 1.5)
            router.path = [.settings]; await snap("24-settings")
            router.path = []; await snap("25-home-focus")
            print("SHOTS DONE")
        }
    }
}
#endif
