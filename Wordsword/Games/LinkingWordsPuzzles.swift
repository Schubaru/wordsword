import Foundation

// MARK: - Tiers
/// What kind of synonym a cluster is, `1`–`4` in the bank: everyday words, moderate ones, bookish
/// ones, and words that only mean the headword in a second sense. A day takes one of each so every
/// board has the same spread. Never shown to the player: no colour, label or order on screen
/// follows the tier.
enum LinkTier: Int, CaseIterable, Codable, Hashable, Sendable {
    case everyday, moderate, bookish, secondSense

    init?(letter: Character) {
        guard let d = letter.wholeNumberValue, let t = LinkTier(rawValue: d - 1) else { return nil }
        self = t
    }
}

// MARK: - Inks
/// The app's four highlighters. Each day deals them to its four groups in a seeded order, so a
/// colour says which words belong together and nothing about how hard they were.
enum LinkInk: Int, CaseIterable, Codable, Hashable, Sendable {
    case yellow, green, blue, pink

    var name: String {
        switch self { case .yellow: "Yellow"; case .green: "Green"; case .blue: "Blue"; case .pink: "Pink" }
    }
    /// The share text's symbol for this ink's group: a shape, so a shared result reads in plain text.
    var symbol: String {
        switch self { case .yellow: "●"; case .green: "▲"; case .blue: "■"; case .pink: "◆" }
    }
}

/// One line of the bank: a headword and the words that mean it.
struct LinkCluster: Hashable, Sendable {
    let tier: LinkTier
    let headword: String
    let words: [String]
}

// MARK: - The bank
/// `linking-words.txt`, parsed once. Each tier's clusters sit in a fixed seeded order so the daily
/// walk through them isn't the authored order.
final class LinkBank: Sendable {
    static let shared = LinkBank.bundled()

    let clusters: [LinkCluster]
    let byTier: [LinkTier: [LinkCluster]]

    init(clusters: [LinkCluster]) {
        self.clusters = clusters
        var by: [LinkTier: [LinkCluster]] = [:]
        for t in LinkTier.allCases {
            var rng = SplitMix64(seed: 0x11AC_0000 + UInt64(t.rawValue))
            by[t] = clusters.filter { $0.tier == t }.shuffled(using: &rng)
        }
        byTier = by
    }

    static func bundled() -> LinkBank {
        guard let url = Bundle.main.url(forResource: "linking-words", withExtension: "txt"),
              let s = try? String(contentsOf: url, encoding: .utf8) else { return LinkBank(clusters: []) }
        return LinkBank(clusters: parse(s))
    }

    /// `y HAPPY: glad, cheerful, …` per line; `#` lines and blanks are skipped. A malformed line is
    /// dropped here and caught by `selfCheck` in DEBUG.
    static func parse(_ text: String) -> [LinkCluster] {
        text.split(separator: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let colon = line.firstIndex(of: ":"),
                  let first = line.first, let tier = LinkTier(letter: first) else { return nil }
            let head = line[line.index(after: line.startIndex)..<colon].trimmingCharacters(in: .whitespaces)
            let words = line[line.index(after: colon)...].split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !head.isEmpty, !words.isEmpty else { return nil }
            return LinkCluster(tier: tier, headword: head, words: words)
        }
    }
}

// MARK: - A day's puzzle
/// Four groups of four, and the board they start on. Pure value: a function of the puzzle number
/// and the bank, so every phone builds the same one.
struct LinkingPuzzle: Hashable, Sendable {
    struct Group: Hashable, Sendable {
        let tier: LinkTier
        /// The highlighter this group wears today.
        let ink: LinkInk
        let headword: String
        let words: [String]
    }

    let number: Int
    /// One per tier, in tier order.
    let groups: [Group]
    /// The sixteen words, shuffled.
    let order: [String]

    var words: [String] { groups.flatMap(\.words) }
    func group(of word: String) -> Group? { groups.first { $0.words.contains(word) } }
    func group(matching guess: some Collection<String>) -> Group? {
        let set = Set(guess)
        return groups.first { Set($0.words) == set }
    }
    /// Three of the four in one group — the "Three of those share a meaning" case.
    func isOneAway(_ guess: some Collection<String>) -> Bool {
        let set = Set(guess)
        return groups.contains { Set($0.words).intersection(set).count == 3 }
    }

    /// Puzzle #1 is launch day. Days are counted in the device's calendar, so the puzzle changes at
    /// local midnight — everyone on the same date gets the same board. Must be on or before the
    /// first day anyone can play: every earlier date clamps to #1, so the board wouldn't change.
    static let epoch = DateComponents(year: 2026, month: 10, day: 23)

    static func number(for date: Date = .now, calendar: Calendar = .current) -> Int {
        guard let start = calendar.date(from: epoch) else { return 1 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0
        return max(1, days + 1)
    }

    /// Local midnight after `date` — when the next puzzle arrives.
    static func nextPuzzle(after date: Date = .now, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
    }

    /// Day N takes cluster N (mod count) from each tier's seeded list. The four counts are kept
    /// pairwise coprime (see the bank's header), so the same four clusters can't meet again for
    /// their product in days — longer than the app will exist. Which four of a cluster's words play,
    /// and where they land on the board, come from an RNG seeded by the day. The inks come from a
    /// second RNG of their own, so dealing them never changes which words a day plays.
    static func make(number: Int, bank: LinkBank = .shared) -> LinkingPuzzle {
        var rng = SplitMix64(seed: 0x11AC_5EED &+ UInt64(max(0, number)))
        var inkRng = SplitMix64(seed: 0x11AC_1A4C &+ UInt64(max(0, number)))
        let inks = LinkInk.allCases.shuffled(using: &inkRng)
        var groups: [Group] = []
        for t in LinkTier.allCases {
            guard let list = bank.byTier[t], !list.isEmpty else { continue }
            let c = list[(max(1, number) - 1) % list.count]
            let picked = Array(c.words.shuffled(using: &rng).prefix(4))
            groups.append(Group(tier: t, ink: inks[groups.count], headword: c.headword, words: picked))
        }
        let order = groups.flatMap(\.words).shuffled(using: &rng)
        return LinkingPuzzle(number: number, groups: groups, order: order)
    }
}

#if DEBUG
extension LinkingPuzzle {
    /// The one runnable check: the bank obeys its own rules (so every day has exactly one solution),
    /// the tier cycle outlives us, and the generator is deterministic.
    static func selfCheck(_ bank: LinkBank = .shared) {
        var seen: [String: LinkTier] = [:]
        var heads = Set<String>()
        let letters = CharacterSet.lowercaseLetters
        for c in bank.clusters {
            assert(c.words.count >= 5, "\(c.headword): only \(c.words.count) words — a cluster needs five or more")
            assert(Set(c.words).count == c.words.count, "\(c.headword) repeats a word")
            assert(heads.insert(c.headword).inserted, "two clusters are called \(c.headword)")
            for w in c.words {
                assert((2...10).contains(w.count) && w.unicodeScalars.allSatisfy(letters.contains), "\(c.headword): bad word '\(w)'")
                if let t = seen[w] { assert(t == c.tier, "'\(w)' is in two tiers (\(t), \(c.tier)) — a day could have two answers") }
                seen[w] = c.tier
            }
        }
        for c in bank.clusters { assert(seen[c.headword.lowercased()] == nil, "headword \(c.headword) is also a word") }
        // Consecutive days get consecutive puzzles, across midnight and a DST change.
        let cal = Calendar.current
        for (y, m, d, n) in [(2026, 10, 23, 1), (2026, 10, 24, 2), (2026, 11, 2, 11)] {
            let date = cal.date(from: DateComponents(year: y, month: m, day: d, hour: 23, minute: 59))!
            assert(number(for: date) == n, "\(y)-\(m)-\(d) should be puzzle #\(n), got #\(number(for: date))")
            assert(number(for: nextPuzzle(after: date)) == n + 1, "the day after #\(n) isn't #\(n + 1)")
        }
        let counts = LinkTier.allCases.map { bank.byTier[$0]?.count ?? 0 }
        assert(counts.allSatisfy { $0 > 0 }, "a tier has no clusters: \(counts)")
        let lcm = counts.reduce(1) { a, b in a / gcd(a, b) * b }
        assert(lcm >= 365 * 200, "tier counts \(counts) repeat a set after \(lcm) days — make them coprime")
        assert(make(number: 1) == make(number: 1) && make(number: 1) != make(number: 2), "generator isn't deterministic")
        var laddered = 0
        for n in 1...400 {
            let p = make(number: n)
            assert(p.groups.count == 4 && Set(p.words).count == 16 && p.order.count == 16, "puzzle \(n) is malformed")
            assert(Set(p.groups.map(\.ink)).count == 4, "puzzle \(n) gives two groups one ink")
            if p.groups.map(\.ink.rawValue) == p.groups.map(\.tier.rawValue) { laddered += 1 }
        }
        // A colour mustn't track difficulty: the ink order should match tier order only by chance (1 in 24).
        assert(laddered < 40, "inks follow the tiers on \(laddered) of 400 days")
        print("LinkingPuzzle.selfCheck: \(bank.clusters.count) clusters \(counts), cycle \(lcm / 365) years")
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
}
#endif
