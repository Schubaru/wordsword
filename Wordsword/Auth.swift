import Foundation
import Observation

/// What the user typed on the identifier screen.
///
/// Parsing happens once, here, so the keyboard we show, the validation hint, and the
/// "we sent it to ___" echo on the code screen can never disagree with each other.
enum Contact: Equatable {
    case email(String)
    case phone(String)

    /// Nil until the value is plausibly complete — this gates Continue, so the rule has to be
    /// exactly what the hint under the field promises.
    static func parse(_ raw: String) -> Contact? {
        let t = raw.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        if t.contains("@") {
            let parts = t.split(separator: "@", omittingEmptySubsequences: false)
            guard parts.count == 2, !parts[0].isEmpty,
                  parts[1].contains("."), !parts[1].hasPrefix("."), !parts[1].hasSuffix(".")
            else { return nil }
            return .email(t.lowercased())
        }
        // Deliberately permissive on formatting (+, spaces, dashes, parens) so international
        // numbers aren't rejected by a mask that only knows one country's shape.
        let digits = t.filter(\.isNumber)
        guard (10...15).contains(digits.count),
              t.allSatisfy({ $0.isNumber || " ()-+.".contains($0) })
        else { return nil }
        return .phone(t)
    }

    /// Echoed back verbatim on the code screen. A typo here is the single likeliest way to strand
    /// someone, so we always show exactly what we sent to rather than a prettied-up version.
    var display: String {
        switch self {
        case .email(let e): e
        case .phone(let p): p
        }
    }

    var isEmail: Bool { if case .email = self { true } else { false } }

    /// "Check your email." / "Check your messages."
    var inbox: String { isEmail ? "email" : "messages" }

    /// Suggested username when signing up with an email — beats an empty field.
    var suggestedName: String {
        guard case .email(let e) = self, let at = e.firstIndex(of: "@") else { return "" }
        return String(e[e.startIndex..<at]).filter { $0.isLetter || $0.isNumber }
    }
}

enum AuthError: LocalizedError, Equatable {
    case badCode

    var errorDescription: String? {
        switch self {
        case .badCode: "That code doesn't match. Check the newest message."
        }
    }
}

/// Identity for wordsword.
///
/// v1 has no server, so this is a local stand-in: `sendCode` invents a code and holds it in
/// memory, `verify` checks it, and nothing leaves the device. Every screen in the account flow —
/// resend, wrong code, unknown account, sign out — runs against this, so replacing it with
/// Supabase later means rewriting the three `// stub:` bodies below and nothing else.
///
/// ponytail: local stub, no delivery and no sync. Swap for a real backend before any public
/// release — until then the code is shown on screen (see `pendingCode`) so nobody gets stranded.
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
    /// The email or phone this device's account belongs to. Kept after sign out so signing back
    /// in can prefill it.
    private(set) var identifier: String
    var username: String { didSet { defaults.set(username, forKey: Key.username) } }
    var hasSeenStory: Bool { didSet { defaults.set(hasSeenStory, forKey: Key.storySeen) } }

    /// The code the stub "sent". A real backend never hands this back — it exists so the account
    /// flow is completable on a build with no delivery behind it.
    private(set) var pendingCode: String?

    private let defaults = UserDefaults.standard

    init(defaults: UserDefaults = .standard) {
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

    /// Does this device already know an account for that contact? Drives the two no-dead-end
    /// crossovers: sign in with an unknown contact, sign up with a known one.
    func knownAccount(_ c: Contact) -> Bool {
        !identifier.isEmpty && identifier.caseInsensitiveCompare(c.display) == .orderedSame
    }

    func sendCode(to c: Contact) async {
        // stub: no delivery. The delay is here so the button's loading state is a real state.
        try? await Task.sleep(for: .milliseconds(650))
        pendingCode = String(format: "%06d", Int.random(in: 0..<1_000_000))
    }

    func verify(_ code: String, for c: Contact) async throws {
        // stub: compares against the code we generated locally.
        try? await Task.sleep(for: .milliseconds(600))
        guard code == pendingCode else { throw AuthError.badCode }
        pendingCode = nil
        identifier = c.display
        defaults.set(identifier, forKey: Key.identifier)
        isSignedIn = true
        defaults.set(true, forKey: Key.signedIn)
    }

    /// "Maybe later" and finishing the story both land here: the story is done, no account.
    func finishOnboarding() { hasSeenStory = true }

    #if DEBUG
    /// Snapshot walker only: land in the signed-in state without driving the code screen.
    func debugSignIn(_ id: String = "alex@example.com", name: String = "alex") {
        identifier = id
        defaults.set(id, forKey: Key.identifier)
        username = name
        isSignedIn = true
        defaults.set(true, forKey: Key.signedIn)
    }
    #endif

    func signOut() {
        isSignedIn = false
        pendingCode = nil
        defaults.set(false, forKey: Key.signedIn)
    }
}
