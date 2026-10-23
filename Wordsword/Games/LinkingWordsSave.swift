import Foundation

/// A player's Linking words: today's board as it stands, the streak, and every word they've linked.
/// One record under one key, like `WordWheelSave`. Today's solved groups and mistakes aren't stored
/// — they're replayed from `guesses`, which is the whole truth of a day.
struct LinkingWordsSave: Codable {
    var number = 0                  // the puzzle `order` and `guesses` belong to
    var order: [String] = []        // the board as currently shuffled
    var guesses: [[String]] = []    // every submitted set, in order
    var streak = 0
    var bestStreak = 0
    var lastSolved = 0              // puzzle number
    var rulesSeen = false
    /// Every word from a solved group, newest first — the words you can look up.
    var history: [String] = []

    /// The streak as it stands on puzzle `number`: a day missed without solving it zeroes the streak
    /// without anything being written.
    func streak(asOf number: Int) -> Int { lastSolved >= number - 1 ? streak : 0 }

    private static let key = "linkingWords"

    static func load() -> LinkingWordsSave {
        guard let d = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(LinkingWordsSave.self, from: d) else { return LinkingWordsSave() }
        return s
    }

    func store() { UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key) }
}
