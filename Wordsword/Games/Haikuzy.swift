import Foundation
import NaturalLanguage
import Observation

// MARK: - The haiku
/// One day's poem: three lines with the hidden word cut out of one of them (`{}` marks the spot),
/// and the word itself.
struct Haiku: Equatable, Sendable {
    enum Season: String, CaseIterable, Sendable {
        case winter, spring, summer, autumn

        /// Northern meteorological seasons, which is what a reader's window shows.
        static func of(_ date: Date, calendar: Calendar = .current) -> Season {
            switch calendar.component(.month, from: date) {
            case 12, 1, 2: .winter
            case 3, 4, 5:  .spring
            case 6, 7, 8:  .summer
            default:       .autumn
            }
        }
    }

    static let blank = "{}"

    let season: Season
    let lines: [String]
    let answer: String

    /// The lines as words, the hidden one as `{}` — or written in, once the day is done.
    func lines(filled: Bool) -> [String] {
        filled ? lines.map { $0.replacingOccurrences(of: Self.blank, with: answer) } : lines
    }
}

// MARK: - The bank
/// `haikuzy.txt`, read once. Day N is the next haiku of its own season: the bank holds each
/// season's poems in reading order, and a day takes the one after the last day of that season.
enum HaikuzyBank {
    /// Haikuzy #1 is the day it shipped.
    nonisolated static let epoch = DateComponents(year: 2026, month: 11, day: 10)

    nonisolated static let all: [Haiku] = {
        guard let url = Bundle.main.url(forResource: "haikuzy", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text)
    }()

    nonisolated static let bySeason: [Haiku.Season: [Haiku]] = Swift.Dictionary(grouping: all, by: \.season)

    /// `season | line / line / line`, the hidden word in braces. `{word:topic+extra,extra}` is
    /// allowed; the topic and extras are only for the related-words script.
    nonisolated static func parse(_ text: String) -> [Haiku] {
        text.split(separator: "\n").compactMap { raw in
            let l = raw.trimmingCharacters(in: .whitespaces)
            guard !l.isEmpty, !l.hasPrefix("#") else { return nil }
            let parts = l.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2, let season = Haiku.Season(rawValue: parts[0]) else { return nil }
            var answer: String?
            let lines = parts[1].components(separatedBy: " / ").map { line -> String in
                guard let o = line.firstIndex(of: "{"), let c = line.firstIndex(of: "}"), o < c else { return line }
                answer = String(line[line.index(after: o)..<c].prefix { $0.isLetter })
                return line.replacingCharacters(in: o...c, with: Haiku.blank)
            }
            guard let answer, lines.count == 3 else { return nil }
            return Haiku(season: season, lines: lines, answer: answer)
        }
    }

    nonisolated static func number(for date: Date = .now, calendar: Calendar = .current) -> Int {
        guard let start = calendar.date(from: epoch) else { return 1 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0
        return max(1, days + 1)
    }

    nonisolated static func haiku(number n: Int, calendar: Calendar = .current) -> Haiku? {
        guard let start = calendar.date(from: epoch) else { return all.first }
        let day = calendar.date(byAdding: .day, value: max(1, n) - 1, to: start) ?? start
        let season = Haiku.Season.of(day, calendar: calendar)
        // How many days of this season came before this one: the k-th day reads the k-th poem.
        var k = 0
        for i in 0..<(max(1, n) - 1) {
            if let d = calendar.date(byAdding: .day, value: i, to: start), Haiku.Season.of(d, calendar: calendar) == season { k += 1 }
        }
        // ponytail: a season with no poems yet borrows the whole bank; write that season before it comes round.
        let pool = bySeason[season].flatMap { $0.isEmpty ? nil : $0 } ?? all
        return pool.isEmpty ? nil : pool[k % pool.count]
    }

    #if DEBUG
    nonisolated static func selfCheck() {
        assert(all.count >= 60, "only \(all.count) haiku parsed")
        let words = HaikuzyWords.shared
        var answers = Set<String>()
        for h in all {
            let a = h.answer
            assert(a.allSatisfy { $0.isASCII && $0.isLowercase }, "\(a): lowercase letters only")
            assert(words.contains(a), "\(a) isn't in haiku-words.txt")
            assert(HaikuzyScore.table[a] != nil, "\(a) has no haikuzy-near.txt line — run Scripts/make-haikuzy-near.swift")
            assert(answers.insert(a).inserted, "\(a) is hidden twice")
            assert(h.lines.joined().components(separatedBy: Haiku.blank).count == 2, "\(a): one blank per haiku")
            for w in h.lines.joined(separator: " ").lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init) {
                let shared = min(w.count, a.count) >= 4 && (w.hasPrefix(a) || a.hasPrefix(w))
                assert(!HaikuzyScore.isAnswer(w, a) && !shared, "\(a): the poem gives it away with \"\(w)\"")
            }
        }
        // The calendar: launch day opens autumn, Dec 1 opens winter, the solstice and the turn of
        // the year land on their own poems.
        assert(haiku(number: 1)?.answer == "ember")
        assert(haiku(number: 22)?.season == .winter && haiku(number: 22) == bySeason[.winter]?.first, "Dec 1 isn't winter's first")
        assert(haiku(number: 42)?.answer == "solstice", "Dec 21 is \(haiku(number: 42)?.answer ?? "-")")
        assert(haiku(number: 52)?.answer == "confetti" && haiku(number: 53)?.answer == "calendar", "the year doesn't turn on its poems")
        let cal = Calendar.current
        for n in 1...400 {
            let date = cal.date(byAdding: .day, value: n - 1, to: cal.date(from: epoch)!)!
            assert(number(for: date) == n, "day \(n) is numbered \(number(for: date))")
        }
        HaikuzyWords.selfCheck()
        HaikuzyScore.selfCheck()
    }
    #endif
}

// MARK: - Real words, and the typo you meant
/// Every ENABLE word (any length) and an everyday ranking, for checking guesses and fixing typos.
final class HaikuzyWords: Sendable {
    nonisolated static let shared = HaikuzyWords.bundled()

    enum Resolution: Equatable, Sendable {
        case word(String)                         // a real word, as typed
        case corrected(from: String, to: String)  // a typo with one obvious fix
        case choices([String])                    // a typo with several fixes: let them pick
        case unknown                              // nothing close
    }

    let words: Set<String>
    /// Lower is more everyday; absent = uncommon.
    let rank: [String: Int]

    init(words: [String], common: [String]) {
        self.words = Set(words)
        var rank: [String: Int] = [:]
        for (i, w) in common.enumerated() where rank[w] == nil { rank[w] = i }
        self.rank = rank
    }

    nonisolated static func bundled() -> HaikuzyWords {
        func lines(_ name: String) -> [String] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
                  let s = try? String(contentsOf: url, encoding: .utf8) else { return [] }
            return s.split(separator: "\n").map(String.init)
        }
        return HaikuzyWords(words: lines("haiku-words"), common: lines("haiku-common"))
    }

    func contains(_ w: String) -> Bool { words.contains(w) }

    /// Lowercase, first word only, letters only: "  Globe! " → "globe".
    nonisolated static func clean(_ raw: String) -> String {
        let first = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: \.isWhitespace).first ?? ""
        return String(first.lowercased().filter { $0.isLetter && $0.isASCII })
    }

    /// A real word is taken as typed — "glob" is never turned into "globe". Otherwise: one edit
    /// away (two for longer words), with swapped letters first because they're the commonest slip
    /// ("gloeb" → "globe", though "glob" is one deletion away too); then a single everyday
    /// candidate wins; more than one, and they choose.
    func resolve(_ typed: String) -> Resolution {
        guard !typed.isEmpty else { return .unknown }
        if contains(typed) { return .word(typed) }

        let swaps = Set(Self.transpositions(typed).filter(contains))
        if swaps.count == 1, let w = swaps.first { return .corrected(from: typed, to: w) }

        var near = Set(Self.edits(typed).filter(contains))
        var reach = 1
        if near.isEmpty, typed.count >= 6 {
            near = Set(Self.edits(typed).flatMap(Self.edits).filter(contains))
            reach = 2
        }
        guard !near.isEmpty else { return .unknown }
        let ranked = near.sorted { (rank[$0] ?? .max, $0) < (rank[$1] ?? .max, $1) }
        let everyday = ranked.filter { rank[$0] != nil }
        if everyday.count == 1 { return .corrected(from: typed, to: everyday[0]) }
        if everyday.isEmpty, ranked.count == 1, reach == 1 { return .corrected(from: typed, to: ranked[0]) }
        return .choices(Array((everyday.isEmpty ? ranked : everyday).prefix(3)))
    }

    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyz")

    nonisolated static func transpositions(_ w: String) -> [String] {
        let c = Array(w)
        guard c.count > 1 else { return [] }
        return (0..<(c.count - 1)).compactMap { i in
            guard c[i] != c[i + 1] else { return nil }
            var s = c; s.swapAt(i, i + 1); return String(s)
        }
    }

    /// Every string one deletion, swap, substitution or insertion away.
    nonisolated static func edits(_ w: String) -> [String] {
        let c = Array(w)
        var out = transpositions(w)
        for i in 0..<c.count {
            var d = c; d.remove(at: i); out.append(String(d))
            for a in alphabet where a != c[i] { var s = c; s[i] = a; out.append(String(s)) }
        }
        for i in 0...c.count {
            for a in alphabet { var s = c; s.insert(a, at: i); out.append(String(s)) }
        }
        return out
    }

    #if DEBUG
    nonisolated static func selfCheck() {
        let w = shared
        assert(w.words.count > 150_000, "only \(w.words.count) words")
        assert(w.resolve("globe") == .word("globe"))
        assert(w.resolve("glob") == .word("glob"), "a real word was corrected")
        assert(w.resolve("gloeb") == .corrected(from: "gloeb", to: "globe"), "gloeb → \(w.resolve("gloeb"))")
        assert(w.resolve("embre") == .corrected(from: "embre", to: "ember"), "embre → \(w.resolve("embre"))")
        assert(w.resolve("lantren") == .corrected(from: "lantren", to: "lantern"))
        assert(w.resolve("persimon") == .corrected(from: "persimon", to: "persimmon"), "persimon → \(w.resolve("persimon"))")
        assert(w.resolve("qzxvbn") == .unknown)
        assert(clean("  Globe! ") == "globe" && clean("ember glow") == "ember")
    }
    #endif
}

// MARK: - The score
/// How close a guess is, 1–100. The word, or a plural of it (or its stem, when the word is a past
/// form), is 100. Anything else
/// is the better of two reads, capped at 99 so only the word ever reaches 100:
///  - **meaning** — its rank in the answer's bundled "means like" list (haikuzy-near.txt, from
///    Datamuse): rank 1 ≈ 96, 10 ≈ 78, 100 ≈ 60.
///  - **company** — Apple's on-device word embedding: the distance to the answer, scaled between
///    the answer's 5th-nearest neighbour (≈ 95) and an everyday word (1). It catches what a
///    thesaurus misses — ember → fire, flame.
/// Both run offline and give every phone the same number. The curve lives in `HaikuzyRules`.
enum HaikuzyScore {
    struct Near: Sendable {
        let near: Double
        let base: Double
        let rank: [String: Int]
    }

    nonisolated static let table: [String: Near] = {
        guard let url = Bundle.main.url(forResource: "haikuzy-near", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var out: [String: Near] = [:]
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let halves = line.split(separator: ":", maxSplits: 1)
            let head = halves[0].split(separator: " ")
            guard head.count == 3, let near = Double(head[1]), let base = Double(head[2]) else { continue }
            var rank: [String: Int] = [:]
            if halves.count > 1 {
                for (i, w) in halves[1].split(separator: " ").enumerated() { rank[String(w)] = i + 1 }
            }
            out[String(head[0])] = Near(near: near, base: base, rank: rank)
        }
        return out
    }()

    /// Built in to iOS. Reads only, so sharing one across threads is fine.
    nonisolated(unsafe) static let embedding = NLEmbedding.wordEmbedding(for: .english)

    /// The same word, give or take a plural: "embers" is "ember", "cinder" is "cinders".
    nonisolated static func sameWord(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        func plural(_ x: String, _ y: String) -> Bool {
            x == y + "s" || x == y + "es" || (y.hasSuffix("y") && x == y.dropLast() + "ies")
        }
        return plural(a, b) || plural(b, a)
    }

    /// The answer, as far as a guess goes: the same word, or — only when the answer is itself a
    /// past form — its stem ("muffle" for "muffled"). Never the other way: "wicked" isn't "wick".
    nonisolated static func isAnswer(_ guess: String, _ answer: String) -> Bool {
        if sameWord(guess, answer) { return true }
        return answer.hasSuffix("ed") && (guess == String(answer.dropLast()) || guess == String(answer.dropLast(2)))
    }

    nonisolated static func score(_ guess: String, answer: String) -> Int {
        if isAnswer(guess, answer) { return 100 }
        var best = 1.0
        if let n = table[answer] {
            // A plural of a listed word counts as that word.
            let r = n.rank[guess] ?? n.rank.first { sameWord($0.key, guess) }?.value
            if let r { best = max(best, HaikuzyRules.meaning(rank: r)) }
            if let e = embedding, e.contains(guess), e.contains(answer) {
                let d = e.distance(between: guess, and: answer)
                best = max(best, HaikuzyRules.company(distance: d, near: n.near, base: n.base))
            }
        }
        return min(99, max(1, Int(best.rounded())))
    }

    #if DEBUG
    nonisolated static func selfCheck() {
        assert(score("ember", answer: "ember") == 100 && score("embers", answer: "ember") == 100)
        assert(score("track", answer: "tracks") == 100 && score("muffle", answer: "muffled") == 100)
        assert(score("wicked", answer: "wick") < 100, "wicked isn't a form of wick")
        assert(score("coal", answer: "ember") >= 85, "coal → \(score("coal", answer: "ember"))")
        assert(score("fire", answer: "ember") >= 80, "fire → \(score("fire", answer: "ember"))")
        assert(score("quiet", answer: "hush") >= 80, "quiet → \(score("quiet", answer: "hush"))")
        assert(score("banana", answer: "ember") < 30, "banana → \(score("banana", answer: "ember"))")
        assert(score("egret", answer: "heron") > score("car", answer: "heron"))
        assert((1...99).contains(score("qzx", answer: "ember")))
    }
    #endif
}

/// Haikuzy's numbers, in one place so the feel can be tuned without touching the game.
enum HaikuzyRules {
    static let maxGuesses = 4

    /// Rank in the "means like" list → score: 96 at rank 1, falling by 18 per factor of ten.
    nonisolated static func meaning(rank: Int) -> Double { 96 - 18 * log10(Double(max(1, rank))) }

    /// Embedding distance → score: 95 at the answer's 5th-nearest neighbour or closer, 1 at an
    /// everyday word or farther, eased so the warm middle reads warm.
    nonisolated static func company(distance d: Double, near: Double, base: Double) -> Double {
        guard base > near else { return 1 }
        let t = min(1, max(0, (base - d) / (base - near)))
        return 1 + 94 * pow(t, 0.8)
    }

    /// The word for a score, said on the caption row as it lands.
    static func warmth(_ score: Int) -> String {
        switch score {
        case 100:    "That's the word"
        case 90...:  "So close"
        case 70...:  "Warm"
        case 40...:  "Lukewarm"
        default:     "Cold"
        }
    }
}

// MARK: - The save
/// Today's guesses, the days solved, and every revealed word (for Words found). One record under
/// one key, like the other games.
struct HaikuzySave: Codable {
    struct Guess: Codable, Equatable, Identifiable {
        var word: String
        var typed: String?          // what was typed, when a typo was fixed
        var score: Int
        var id: String { word }
    }

    var number = 0                  // the day `guesses` belong to
    var guesses: [Guess] = []
    var lastSolved = 0
    var rulesSeen = false
    /// Revealed words, newest first.
    var history: [String] = []

    var best: Guess? { guesses.max { $0.score < $1.score } }

    private static let key = "haikuzy"

    static func load() -> HaikuzySave {
        guard let d = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(HaikuzySave.self, from: d) else { return HaikuzySave() }
        return s
    }

    func store() { UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key) }
}

// MARK: - The game
/// The game with no SwiftUI in it: today's haiku, the guesses, what the last one did. The view
/// draws and reacts; this decides.
@MainActor @Observable final class Haikuzy {
    enum Phase: Equatable { case playing, won, lost }

    struct Flash: Identifiable, Equatable {
        enum Kind: Equatable { case invalid, repeated, scored(best: Bool), won }
        let id: Int
        let kind: Kind
    }

    static let hint = "Guess the missing word"

    private(set) var save = HaikuzySave.load()
    private(set) var haiku: Haiku?
    private(set) var phase: Phase = .playing
    private(set) var caption: String?
    /// A typo that could be more than one word: these are offered, and picking one is the guess.
    private(set) var choices: [String] = []
    private(set) var choicesFor: String?
    private(set) var busy = false
    private(set) var flash: Flash?
    /// True once the game ends on this screen; false when a finished day is merely reloaded.
    private(set) var justFinished = false
    private var flashes = 0
    private var captionTask: Task<Void, Never>?

    var guesses: [HaikuzySave.Guess] { save.guesses }
    var number: Int { save.number }
    var finished: Bool { phase != .playing }
    var answer: String? { haiku?.answer }
    var bestIndex: Int? { save.best.flatMap { b in guesses.firstIndex(of: b) } }

    var verdict: String {
        if phase == .won {
            switch guesses.count {
            case 1: return "First guess"
            case 2: return "Sharp"
            case 3: return "Nicely done"
            default: return "Last guess"
            }
        }
        switch save.best?.score ?? 0 {
        case 90...: return "So close"
        case 70...: return "Warm"
        default:    return "Not today"
        }
    }

    /// The scores only — the word stays a secret for whoever you send it to.
    var shareText: String {
        "Haikuzy #\(number)\n" + guesses.map { "\($0.score)" }.joined(separator: " · ")
    }

    // MARK: Loading
    func load() async {
        let n = Self.today()
        justFinished = false
        choices = []
        haiku = HaikuzyBank.haiku(number: n)
        if save.number != n {
            save.number = n
            save.guesses = []
            save.store()
        }
        #if DEBUG
        // `SIMCTL_CHILD_HAIKUZY_GUESSES=coal,fire simctl launch …` opens with those played.
        if save.guesses.isEmpty, let g = ProcessInfo.processInfo.environment["HAIKUZY_GUESSES"], let a = answer {
            save.guesses = g.split(separator: ",").prefix(HaikuzyRules.maxGuesses).map {
                let w = String($0).lowercased()
                return .init(word: w, score: HaikuzyScore.score(w, answer: a))
            }
        }
        #endif
        replay()
        // The dictionary and the embedding load on first use; get that out of the way now.
        await Task.detached(priority: .userInitiated) {
            _ = HaikuzyWords.shared.contains("a")
            _ = HaikuzyScore.embedding?.contains("a")
        }.value
    }

    private static func today() -> Int {
        #if DEBUG
        if let d = ProcessInfo.processInfo.environment["HAIKUZY_DAY"], let v = Int(d) { return v }
        #endif
        return HaikuzyBank.number()
    }

    /// The poem on screen is an earlier day's: midnight passed while the app was open or away.
    var isStale: Bool { haiku != nil && save.number != Self.today() }

    private func replay() {
        phase = .playing
        guard let answer else { return }
        if guesses.contains(where: { $0.score == 100 }) { phase = .won; record(answer, won: true) }
        else if guesses.count >= HaikuzyRules.maxGuesses { phase = .lost; record(answer, won: false) }
    }

    // MARK: Guessing
    /// Checks the word is real (fixing an obvious typo), then scores it.
    func submit(_ raw: String) async {
        guard phase == .playing, !busy, answer != nil else { return }
        let typed = HaikuzyWords.clean(raw)
        guard !typed.isEmpty else { return }
        choices = []
        busy = true
        let resolution = await Task.detached(priority: .userInitiated) { HaikuzyWords.shared.resolve(typed) }.value
        busy = false
        switch resolution {
        case .unknown:
            show("Not a word I know"); emit(.invalid)
        case .choices(let ws):
            // A fix you've already guessed isn't a choice; one left over is simply the guess.
            let open = ws.filter { w in !guesses.contains { HaikuzyScore.sameWord($0.word, w) } }
            if open.count == 1 { await commit(open[0], typed: typed) }
            else if open.isEmpty { show("Already guessed"); emit(.repeated) }
            else { choices = open; choicesFor = typed }
        case .word(let w):
            await commit(w, typed: nil)
        case .corrected(let from, let to):
            await commit(to, typed: from)
        }
    }

    /// One of the offered fixes for a typo.
    func pick(_ word: String) async {
        guard choices.contains(word) else { return }
        let typo = choicesFor
        choices = []
        await commit(word, typed: typo)
    }

    func dismissChoices() { choices = [] }

    private func commit(_ word: String, typed: String?) async {
        guard let answer else { return }
        if guesses.contains(where: { HaikuzyScore.sameWord($0.word, word) }) {
            show("Already guessed"); emit(.repeated); return
        }
        busy = true
        let score = await Task.detached(priority: .userInitiated) { HaikuzyScore.score(word, answer: answer) }.value
        busy = false
        let wasBest = save.best?.score ?? 0
        save.guesses.append(.init(word: word, typed: typed, score: score))
        save.store()
        show(HaikuzyRules.warmth(score))
        if score == 100 {
            record(answer, won: true); justFinished = true; phase = .won; emit(.won)
        } else {
            emit(.scored(best: score > wasBest))
            if guesses.count >= HaikuzyRules.maxGuesses { record(answer, won: false); justFinished = true; phase = .lost }
        }
    }

    /// A finished day: the word goes into Words found, and a solve is remembered for the Home card.
    private func record(_ answer: String, won: Bool) {
        if won { save.lastSolved = save.number }
        if save.history.first != answer {
            save.history.removeAll { $0 == answer }
            save.history.insert(answer, at: 0)
        }
        save.store()
    }

    func markRulesSeen() {
        guard !save.rulesSeen else { return }
        save.rulesSeen = true
        save.store()
    }

    /// Where you are today, for the Home card.
    nonisolated static func cardDetail(_ save: HaikuzySave) -> String {
        let n = HaikuzyBank.number()
        guard save.number == n, !save.guesses.isEmpty else { return "Guess the missing word" }
        if save.lastSolved == n { return "Solved in \(save.guesses.count)" }
        let best = save.best?.score ?? 0
        if save.guesses.count >= HaikuzyRules.maxGuesses { return "Best \(best) · back tomorrow" }
        return "Guess \(save.guesses.count + 1) of \(HaikuzyRules.maxGuesses) · best \(best)"
    }

    /// Is today done, and how? For the card, which writes the word in once it is.
    nonisolated static func cardState(_ save: HaikuzySave) -> (finished: Bool, solved: Bool) {
        let n = HaikuzyBank.number()
        guard save.number == n else { return (false, false) }
        let solved = save.lastSolved == n
        return (solved || save.guesses.count >= HaikuzyRules.maxGuesses, solved)
    }

    // MARK: Signals
    private func emit(_ kind: Flash.Kind) {
        flashes += 1
        flash = Flash(id: flashes, kind: kind)
    }

    private func show(_ text: String) {
        caption = text
        captionTask?.cancel()
        captionTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            caption = nil
        }
    }
}
