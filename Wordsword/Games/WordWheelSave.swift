import Foundation

/// A player's whole Word Wheel progress: one record under one key. Deliberately not SwiftData —
/// it's a save slot, not a library of things to query, and `LastSearch` set the precedent.
struct WordWheelSave: Codable {
    var level = 1
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
