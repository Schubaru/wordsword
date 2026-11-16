import Foundation
import Observation

/// A player's whole Word Wheel progress: one record under one key. Deliberately not SwiftData —
/// it's a save slot, not a library of things to query, and `LastSearch` set the precedent.
struct WordWheelSave: Codable {
    var level = 1
    /// The balance from before the coins became the app's `Wallet`: read once, to seed it.
    var coins = WordWheelRules.startCoins
    var streak = 0
    var bestStreak = 0
    var levelCoins = 0                  // earned on the current level, for the "done" sheet
    var foundTargets: [String] = []     // in the order they were found
    var foundBonus: [String] = []
    var revealed: [Level.Cell] = []     // hint tiles
    /// Every word ever found, newest first. ponytail: an array in defaults; move to SwiftData if it
    /// ever runs to many thousands.
    var history: [String] = []

    private static let key = "wordWheel"

    static func load() -> WordWheelSave {
        guard let d = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(WordWheelSave.self, from: d) else { return WordWheelSave() }
        return s
    }

    func store() { UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key) }
}

// MARK: - The wallet
/// The app's one coin balance. Word Wheel earns into it and spends on letters; Haiklu pays its day's
/// total into it and spends on hints. It began as Word Wheel's, so the first read carries that over.
@MainActor @Observable final class Wallet {
    static let shared = Wallet()
    private static let key = "wallet.coins"
    private(set) var coins: Int

    private init() {
        coins = UserDefaults.standard.object(forKey: Self.key) as? Int ?? WordWheelSave.load().coins
        store()
    }

    func earn(_ n: Int) { coins += n; store() }

    /// Takes the coins and says yes, or takes nothing and says no.
    func spend(_ n: Int) -> Bool {
        guard coins >= n else { return false }
        coins -= n; store()
        return true
    }

    private func store() { UserDefaults.standard.set(coins, forKey: Self.key) }
}
