import Foundation

// MARK: - Tiers
/// The four highlighters, easiest to hardest. Yellow is everyday words, green moderate, blue the
/// bookish synonyms, pink the words that only mean the headword in a second sense.
enum LinkTier: Int, CaseIterable, Codable, Hashable, Sendable {
    case yellow, green, blue, pink

    init?(letter: Character) {
        switch letter { case "y": self = .yellow; case "g": self = .green; case "b": self = .blue; case "p": self = .pink; default: return nil }
    }

    var name: String {
        switch self { case .yellow: "Yellow"; case .green: "Green"; case .blue: "Blue"; case .pink: "Pink" }
    }
    /// The square for the share grid — the same four NYT uses, so a shared result reads at a glance.
    var square: String {
        switch self { case .yellow: "🟨"; case .green: "🟩"; case .blue: "🟦"; case .pink: "🟪" }
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
        let headword: String
        let words: [String]
    }

    let number: Int
    /// Yellow → pink.
    let groups: [Group]
    /// The sixteen words, shuffled.
    let order: [String]

    var words: [String] { groups.flatMap(\.words) }
    func group(of word: String) -> Group? { groups.first { $0.words.contains(word) } }
    func group(matching guess: some Collection<String>) -> Group? {
        let set = Set(guess)
        return groups.first { Set($0.words) == set }
    }
    /// Three of the four in one group — the "One away…" case.
    func isOneAway(_ guess: some Collection<String>) -> Bool {
        let set = Set(guess)
        return groups.contains { Set($0.words).intersection(set).count == 3 }
    }

    /// Puzzle #1 is launch day. Days are counted in the device's calendar, so the puzzle changes at
    /// local midnight — everyone on the same date gets the same board.
    static let epoch = DateComponents(year: 2026, month: 10, day: 24)

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
    /// and where they land on the board, come from an RNG seeded by the day.
    static func make(number: Int, bank: LinkBank = .shared) -> LinkingPuzzle {
        var rng = SplitMix64(seed: 0x11AC_5EED &+ UInt64(max(0, number)))
        var groups: [Group] = []
        for t in LinkTier.allCases {
            guard let list = bank.byTier[t], !list.isEmpty else { continue }
            let c = list[(max(1, number) - 1) % list.count]
            let picked = Array(c.words.shuffled(using: &rng).prefix(4))
            groups.append(Group(tier: t, headword: c.headword, words: picked))
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
        let counts = LinkTier.allCases.map { bank.byTier[$0]?.count ?? 0 }
        assert(counts.allSatisfy { $0 > 0 }, "a tier has no clusters: \(counts)")
        let lcm = counts.reduce(1) { a, b in a / gcd(a, b) * b }
        assert(lcm >= 365 * 200, "tier counts \(counts) repeat a set after \(lcm) days — make them coprime")
        assert(make(number: 1) == make(number: 1) && make(number: 1) != make(number: 2), "generator isn't deterministic")
        for n in 1...400 {
            let p = make(number: n)
            assert(p.groups.count == 4 && Set(p.words).count == 16 && p.order.count == 16, "puzzle \(n) is malformed")
        }
        print("LinkingPuzzle.selfCheck: \(bank.clusters.count) clusters \(counts), cycle \(lcm / 365) years")
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
}
#endif
