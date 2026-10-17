import Foundation

// MARK: - The dictionary
/// Bundled word lists (see Scripts/make-wordlists.py): `wheel-words.txt` is every playable word,
/// `wheel-common.txt` ranks board words (everyday words first), `wheel-seeds.txt` is the words a
/// level can be built around. Loaded once, lazily, by whoever asks first — `WordWheel` asks from
/// the background.
final class WordList: Sendable {
    static let shared = WordList.bundled()

    let words: Set<String>
    /// Rank in the common list; absent = uncommon. Lower is more common.
    let rank: [String: Int]
    /// Pangram pools by letter count: common words in a fixed seeded order, so level N is level N forever.
    private let pools: [Int: [String]]
    private let bySignature: [String: [String]]

    init(words: [String], common: [String], seeds: [String]) {
        self.words = Set(words)
        var rank: [String: Int] = [:]
        for (i, w) in common.enumerated() where rank[w] == nil { rank[w] = i }
        self.rank = rank
        var by: [String: [String]] = [:]
        for w in words { by[Self.signature(w), default: []].append(w) }
        for k in by.keys { by[k]!.sort() }   // deterministic member order
        bySignature = by
        var pools: [Int: [String]] = [:]
        for n in 4...7 {
            var rng = SplitMix64(seed: 0x5EED_0000 + UInt64(n))
            pools[n] = seeds.filter { $0.count == n }.shuffled(using: &rng)
        }
        self.pools = pools
    }

    static func bundled() -> WordList {
        func lines(_ name: String) -> [String] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
                  let s = try? String(contentsOf: url, encoding: .utf8) else { return [] }
            return s.split(separator: "\n").map(String.init)
        }
        return WordList(words: lines("wheel-words"), common: lines("wheel-common"), seeds: lines("wheel-seeds"))
    }

    func contains(_ w: String) -> Bool { words.contains(w) }
    func pool(letters n: Int) -> [String] { pools[n] ?? [] }

    static func signature(_ w: some Sequence<Character>) -> String { String(w.sorted()) }

    /// Can `word` be spelled from these letters, each used at most once?
    static func canMake(_ word: String, from letters: [Character]) -> Bool {
        var left = letters
        for ch in word {
            guard let i = left.firstIndex(of: ch) else { return false }
            left.remove(at: i)
        }
        return true
    }

    /// Every word spellable from these letters. Enumerates the ≤ 2⁷ letter subsets and looks each
    /// one up by signature, so it's a hundred dictionary hits rather than a pass over 60k words.
    func answers(from letters: [Character]) -> Set<String> {
        var out = Set<String>(), seen = Set<String>()
        let n = letters.count
        for mask in 1..<(1 << n) where mask.nonzeroBitCount >= WordWheelRules.minWordLength {
            var picked: [Character] = []
            for i in 0..<n where mask & (1 << i) != 0 { picked.append(letters[i]) }
            let sig = Self.signature(picked)
            guard seen.insert(sig).inserted, let ws = bySignature[sig] else { continue }
            out.formUnion(ws)
        }
        return out
    }
}

/// Deterministic RNG so a level is the same on every phone and every launch.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - A level
/// A wheel of letters, the words laid out on the board, and every other word the wheel can spell.
/// Pure value: `make` is a function of the level number and the bundled lists, nothing else.
struct Level: Hashable, Sendable {
    struct Cell: Hashable, Codable, Sendable { let row: Int; let col: Int }

    struct Placed: Hashable, Sendable {
        let word: String
        let row: Int, col: Int
        let across: Bool
        var cells: [Cell] {
            (0..<word.count).map { Cell(row: across ? row : row + $0, col: across ? col + $0 : col) }
        }
    }

    let index: Int
    let letters: [Character]
    let pangram: String
    let targets: [Placed]
    let bonus: Set<String>
    let rows: Int, cols: Int
    /// Every board cell and the letter that belongs there.
    let grid: [Cell: Character]

    var targetWords: Set<String> { Set(targets.map(\.word)) }

    static func make(index: Int, list: WordList) -> Level {
        let n = WordWheelRules.letterCount(level: index)
        let pool = list.pool(letters: n)
        precondition(!pool.isEmpty, "no \(n)-letter words in wheel-seeds.txt")
        // The k-th level of this size takes the k-th pangram; the pool wraps thousands of levels out,
        // and by then the per-level seed below picks a different board from the same letters.
        let k = (1..<index).reduce(0) { $0 + (WordWheelRules.letterCount(level: $1) == n ? 1 : 0) }
        let pangram = pool[k % pool.count]
        var rng = SplitMix64(seed: UInt64(index) &* 0x9E37_79B9_7F4A_7C15 &+ 0xD1B5_4A32)
        let letters = Array(pangram).shuffled(using: &rng)
        let answers = list.answers(from: letters)
        // Board words: the pangram, then the most common of the rest.
        let ranked = answers.subtracting([pangram]).sorted {
            (list.rank[$0] ?? .max, -$0.count, $0) < (list.rank[$1] ?? .max, -$1.count, $1)
        }
        let want = Int.random(in: WordWheelRules.targetRange(letters: n), using: &rng) - 1
        var placed: [Placed] = []
        for skip in 0..<5 {   // a board that won't lay out tries the next-most-common words instead
            let picks = Array(ranked.dropFirst(skip).prefix(want)).sorted { ($0.count, $0) > ($1.count, $1) }
            placed = Crossword.layout([pangram] + picks, maxGrid: WordWheelRules.maxGrid)
            if placed.count >= min(WordWheelRules.minTargets, answers.count) { break }
        }
        return Level(index: index, letters: letters, pangram: pangram, targets: placed,
                     bonus: answers.subtracting(placed.map(\.word)))
    }

    init(index: Int, letters: [Character], pangram: String, targets: [Placed], bonus: Set<String>) {
        self.index = index; self.letters = letters; self.pangram = pangram; self.targets = targets; self.bonus = bonus
        var grid: [Cell: Character] = [:]
        for p in targets { for (c, ch) in zip(p.cells, p.word) { grid[c] = ch } }
        self.grid = grid
        rows = (grid.keys.map(\.row).max() ?? -1) + 1
        cols = (grid.keys.map(\.col).max() ?? -1) + 1
    }
}

// MARK: - Laying out the board
/// Greedy crossword: the first word goes across, every later word must cross one already placed,
/// and among its legal crossings the one that keeps the board smallest wins. A word with no legal
/// crossing is left out (it becomes a bonus word). Connected by construction.
enum Crossword {
    static func layout(_ words: [String], maxGrid: Int) -> [Level.Placed] {
        guard let first = words.first else { return [] }
        var placed = [Level.Placed(word: first, row: 0, col: 0, across: true)]
        var grid: [Level.Cell: Character] = [:]
        for (c, ch) in zip(placed[0].cells, first) { grid[c] = ch }
        for w in words.dropFirst() {
            var best: (Level.Placed, area: Int, crossings: Int)?
            for p in placed {
                for (i, pc) in p.word.enumerated() {
                    for (j, wc) in w.enumerated() where wc == pc {
                        let cand = p.across
                            ? Level.Placed(word: w, row: p.row - j, col: p.col + i, across: false)
                            : Level.Placed(word: w, row: p.row + i, col: p.col - j, across: true)
                        guard let (area, x) = fit(cand, in: grid, maxGrid: maxGrid) else { continue }
                        if best == nil || (area, -x) < (best!.area, -best!.crossings) { best = (cand, area, x) }
                    }
                }
            }
            if let best {
                for (c, ch) in zip(best.0.cells, best.0.word) { grid[c] = ch }
                placed.append(best.0)
            }
        }
        // Normalise to the origin.
        let r0 = grid.keys.map(\.row).min() ?? 0, c0 = grid.keys.map(\.col).min() ?? 0
        return placed.map { Level.Placed(word: $0.word, row: $0.row - r0, col: $0.col - c0, across: $0.across) }
    }

    /// nil if illegal; else the board's area with this word on it, and how many letters it shares.
    private static func fit(_ p: Level.Placed, in grid: [Level.Cell: Character], maxGrid: Int) -> (Int, Int)? {
        let cells = p.cells
        let dr = p.across ? 0 : 1, dc = p.across ? 1 : 0
        // Nothing may touch the word's two ends — that would spell a longer, different word.
        if grid[Level.Cell(row: p.row - dr, col: p.col - dc)] != nil { return nil }
        if let last = cells.last, grid[Level.Cell(row: last.row + dr, col: last.col + dc)] != nil { return nil }
        var crossings = 0
        for (c, ch) in zip(cells, p.word) {
            if let g = grid[c] {
                guard g == ch else { return nil }
                crossings += 1
            } else if grid[Level.Cell(row: c.row + dc, col: c.col + dr)] != nil
                   || grid[Level.Cell(row: c.row - dc, col: c.col - dr)] != nil {
                return nil   // a fresh letter beside someone else's letter makes an accidental word
            }
        }
        guard crossings > 0 else { return nil }
        let all = Array(grid.keys) + cells
        let rows = all.map(\.row), cols = all.map(\.col)
        let h = rows.max()! - rows.min()! + 1, w = cols.max()! - cols.min()! + 1
        guard h <= maxGrid, w <= maxGrid else { return nil }
        return (h * w, crossings)
    }
}

#if DEBUG
extension Level {
    /// The one runnable check: the first 300 levels all have a pangram on the board, enough words,
    /// a connected board that fits, and generate fast enough to build on the way into the screen.
    static func selfCheck(_ list: WordList = .shared) {
        let t0 = Date()
        for i in 1...300 {
            let l = make(index: i, list: list)
            let words = l.targets.map(\.word)
            assert(words.contains(l.pangram), "level \(i): pangram \(l.pangram) not on the board")
            assert(l.targets.count >= WordWheelRules.minTargets, "level \(i): only \(words) on the board")
            assert(l.letters.count == WordWheelRules.letterCount(level: i), "level \(i): wrong wheel size")
            assert(l.rows <= WordWheelRules.maxGrid && l.cols <= WordWheelRules.maxGrid, "level \(i): board too big")
            for p in l.targets {
                assert(WordList.canMake(p.word, from: l.letters), "level \(i): \(p.word) can't be spelled")
                assert(l.targets.count == 1 || l.targets.contains { $0 != p && !Set($0.cells).isDisjoint(with: p.cells) },
                       "level \(i): \(p.word) floats free")
            }
            for b in l.bonus { assert(WordList.canMake(b, from: l.letters) && list.contains(b), "level \(i): bad bonus \(b)") }
            assert(Set(words).isDisjoint(with: l.bonus), "level \(i): a word is both board and bonus")
        }
        let ms = Date().timeIntervalSince(t0) * 1000
        assert(ms / 300 < 100, "levels take \(ms / 300)ms each")
        print("Level.selfCheck: 300 levels in \(Int(ms))ms")
    }
}
#endif
