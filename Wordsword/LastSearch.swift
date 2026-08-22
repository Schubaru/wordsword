import Foundation

/// The chain from the most recent lookup, so Home can offer to pick it up where it stopped.
///
/// Deliberately not SwiftData: this is one ephemeral pointer, not a record. A saved chain is a
/// `Wordlist` (Define's "Save chain") and that's the thing that's meant to last — this is just
/// "where you were", overwritten on every lookup.
enum LastSearch {
    private static let key = "lastChain"

    /// Oldest word first; `.last` is where the user actually was.
    static var chain: [String] {
        get { UserDefaults.standard.stringArray(forKey: key) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
