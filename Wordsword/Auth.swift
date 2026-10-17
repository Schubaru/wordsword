import AuthenticationServices
import Foundation
import Observation

/// Identity for wordsword: Sign in with Apple, with nothing behind it.
///
/// Apple hands back a stable, opaque user ID per app — that ID *is* the account. It never leaves
/// the device, so there is no server, no code to deliver, and nothing to collect. Apple can revoke
/// it from outside the app (Settings → Sign in with Apple), which `checkCredential` and the
/// revoked notification in `WordswordApp` both turn into a sign out.
///
/// ponytail: no token revocation on delete — that needs a server holding the .p8 key. The app
/// never exchanges the authorization code, so there are no tokens to revoke; the delete dialog
/// points at the Apple ID setting instead. Add a revoke endpoint if review asks for it.
@MainActor
@Observable
final class Auth {
    private enum Key {
        static let signedIn = "signedIn"
        static let identifier = "contact"
        static let username = "username"
        static let storySeen = "storySeen"
        static let legacyOnboarded = "onboarded"
    }

    private(set) var isSignedIn: Bool
    /// Apple's user ID for this account. Opaque — never shown to anyone. Kept after sign out so a
    /// returning sign-in can tell whether it's the same person (and keep their username).
    private(set) var identifier: String
    var username: String { didSet { defaults.set(username, forKey: Key.username) } }
    var hasSeenStory: Bool { didSet { defaults.set(hasSeenStory, forKey: Key.storySeen) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        // Was `= UserDefaults.standard` on the property, which quietly made this parameter
        // read-only: a caller passing its own suite got reads from it and writes to standard.
        // Nothing passed one, so nothing broke — but the self-check below needs the seam to work.
        self.defaults = defaults
        let saved = defaults.string(forKey: Key.identifier) ?? ""
        // Migration: anyone who finished the old onboarding keeps their place. They've seen the
        // story, and a saved contact means they'd already "made an account" under the old rules.
        let legacy = defaults.bool(forKey: Key.legacyOnboarded)
        identifier = saved
        username = defaults.string(forKey: Key.username) ?? ""
        hasSeenStory = defaults.bool(forKey: Key.storySeen) || legacy
        isSignedIn = defaults.bool(forKey: Key.signedIn) || (legacy && !saved.isEmpty)
        if legacy {
            defaults.set(hasSeenStory, forKey: Key.storySeen)
            defaults.set(isSignedIn, forKey: Key.signedIn)
        }
    }

    /// A successful Sign in with Apple. Covers sign up and sign in alike — Apple doesn't
    /// distinguish them, so neither do we. A different Apple ID than last time is a different
    /// person, so their username doesn't carry over.
    func signIn(userID: String, givenName: String?) {
        if userID != identifier { username = "" }
        identifier = userID
        defaults.set(userID, forKey: Key.identifier)
        // Apple only sends the name on the very first authorization; later sign-ins get nil.
        if username.isEmpty, let g = givenName?.filter({ $0.isLetter || $0.isNumber }), !g.isEmpty {
            username = g.lowercased()
        }
        isSignedIn = true
        defaults.set(true, forKey: Key.signedIn)
    }

    /// On launch: the user can stop using their Apple ID with wordsword from iOS Settings while
    /// the app isn't running. If they did, they're signed out here.
    func checkCredential() async {
        guard isSignedIn, !identifier.isEmpty else { return }
        #if DEBUG
        if identifier == Self.debugID { return }   // the snapshot walker's fake account
        #endif
        let id = identifier
        let state = await withCheckedContinuation { (c: CheckedContinuation<ASAuthorizationAppleIDProvider.CredentialState?, Never>) in
            // An error means "couldn't tell" (no entitlement, keychain locked), not "revoked" —
            // signing someone out on a guess would lock their flashcards for nothing.
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: id) { s, e in
                c.resume(returning: e == nil ? s : nil)
            }
        }
        // .transferred is a team migration, not a revocation — leave it alone.
        if state == .revoked || state == .notFound { signOut() }
    }

    /// "Maybe later" and finishing the story both land here: the story is done, no account.
    func finishOnboarding() { hasSeenStory = true }

    #if DEBUG
    static let debugID = "000000.debug.0000"

    /// Snapshot walker only: land in the signed-in state without the Apple sheet.
    func debugSignIn(_ id: String = debugID, name: String = "alex") {
        identifier = id
        defaults.set(id, forKey: Key.identifier)
        username = name
        isSignedIn = true
        defaults.set(true, forKey: Key.signedIn)
    }
    #endif

    func signOut() {
        isSignedIn = false
        defaults.set(false, forKey: Key.signedIn)
    }

    /// Deletes the account, which App Store guideline 5.1.1(v) requires any app that offers
    /// account creation to offer from inside the app.
    ///
    /// Unlike `signOut`, this drops the identifier too, so there's nothing left to prefill or
    /// sign back into — the device is returned to the state it was in before anyone signed up.
    /// The legacy-onboarding path can't resurrect the account afterwards: `init` only honours it
    /// when a saved identifier is present, and this clears it.
    ///
    /// Saved words survive on purpose. They're local content that was never account-derived, and
    /// Settings has its own control for clearing them — deleting an account shouldn't quietly take
    /// a library with it. The confirmation dialog says so before this runs.
    ///
    /// Local only, because the account is local only: Apple's ID is the whole record. Removing
    /// wordsword from the user's Apple ID is theirs to do in iOS Settings — the dialog says where.
    func deleteAccount() {
        isSignedIn = false
        identifier = ""
        username = ""
        // After the assignments, not before: `username`'s didSet writes "" back to the store, so
        // removing the key first would leave an empty string behind instead of nothing.
        defaults.removeObject(forKey: Key.signedIn)
        defaults.removeObject(forKey: Key.identifier)
        defaults.removeObject(forKey: Key.username)
    }

    #if DEBUG
    /// Deletion is destructive and can't be undone, so it gets a check. Runs against a throwaway
    /// suite so it never touches the real one.
    static func selfCheck() {
        let suite = "selfcheck.\(UUID().uuidString)"
        guard let store = UserDefaults(suiteName: suite) else { return }
        defer { UserDefaults.standard.removeSuite(named: suite) }

        let a = Auth(defaults: store)
        // Sign in the real way: first authorization carries a name, a repeat one doesn't.
        a.signIn(userID: "apple.1", givenName: "Ada")
        assert(a.isSignedIn && a.username == "ada", "first sign-in didn't take the given name")
        a.signOut()
        a.signIn(userID: "apple.1", givenName: nil)
        assert(a.username == "ada", "same Apple ID lost its username on sign-in")
        // A different Apple ID on the same phone is a different person.
        a.signIn(userID: "apple.2", givenName: nil)
        assert(a.username.isEmpty, "a second Apple ID inherited the first one's username")
        assert(store.string(forKey: Key.identifier) == "apple.2")

        a.deleteAccount()
        assert(!a.isSignedIn, "delete left the session signed in")
        assert(a.identifier.isEmpty, "delete kept the identifier in memory")
        assert(a.username.isEmpty, "delete kept the username in memory")
        assert(store.string(forKey: Key.identifier) == nil, "delete left the identifier on disk")
        assert(store.string(forKey: Key.username) == nil, "delete left the username on disk")

        // The one that matters: a deleted account must not come back on the next launch.
        let relaunch = Auth(defaults: store)
        assert(!relaunch.isSignedIn, "deleted account came back on next launch")
        assert(relaunch.identifier.isEmpty, "deleted identifier came back on next launch")

        // …including via the legacy-onboarding migration, which treats a saved identifier as
        // proof of an account. Clearing the identifier is what defuses it.
        store.set(true, forKey: Key.legacyOnboarded)
        assert(!Auth(defaults: store).isSignedIn, "legacy onboarding resurrected a deleted account")
    }
    #endif
}
