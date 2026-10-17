import Foundation

/// Every tunable number in Word Wheel, in one place. Change a value here, never in a view.
enum WordWheelRules {
    /// Coins for a board word, by length. Longer words pay more.
    static let coins: [Int: Int] = [3: 10, 4: 20, 5: 35, 6: 50, 7: 70]
    /// A bonus word — real, spellable from the wheel, but not on the board — pays this fraction.
    static let bonusFraction = 0.5
    static let hintPrice = 100
    static let startCoins = 200
    static let minWordLength = 3
    /// Consecutive real words → multiplier. `(at: 3, 1.5)` means the third word in a row pays 1.5×.
    static let streakTiers: [(at: Int, multiplier: Double)] = [(3, 1.5), (6, 2), (10, 3)]

    /// Wheel size by level: ten 4-letter levels to learn on, ten 5-letter, then 6 and 7 alternate.
    static func letterCount(level: Int) -> Int {
        level <= 10 ? 4 : level <= 20 ? 5 : (level.isMultiple(of: 2) ? 7 : 6)
    }
    /// How many of a level's words go on the board; the rest are bonus words.
    static func targetRange(letters: Int) -> ClosedRange<Int> {
        switch letters { case 4: 3...5; case 5: 5...7; case 6: 6...9; default: 7...12 }
    }
    /// Wordscapes level 1 is CAT / ACT: two words is a board.
    static let minTargets = 2
    static let maxGrid = 10

    static func multiplier(streak: Int) -> Double { streakTiers.last { streak >= $0.at }?.multiplier ?? 1 }

    static func coins(for word: String, bonus: Bool, streak: Int) -> Int {
        let base = Double(coins[word.count] ?? coins[7]!) * (bonus ? bonusFraction : 1)
        return Int((base * multiplier(streak: streak)).rounded())
    }
}
