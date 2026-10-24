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
    /// Optional because saves from launch day predate it, and a missing key would fail the decode.
    var stats: Stats?

    /// Finished days: `played` counts wins and losses, a day left half-done counts as neither.
    struct Stats: Codable, Equatable {
        var played = 0
        var won = 0
        var last = 0                // the last puzzle counted, so a day counts once
        var winPercent: Int { played == 0 ? 0 : Int((Double(won) * 100 / Double(played)).rounded()) }
    }

    /// The stats, with a launch-day solve (the only history before stats existed) counted as a win.
    var record: Stats { stats ?? (lastSolved > 0 ? Stats(played: 1, won: 1, last: lastSolved) : Stats()) }

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
