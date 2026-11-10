import Foundation
import Observation

// MARK: - The marks
/// What a guessed letter learns: in the right spot, in the word somewhere else, or not in it.
/// Ordered, so a keyboard key keeps the best thing it has learned.
enum PlexMark: Int, Codable, Comparable, Sendable {
    case absent, present, correct
    static func < (a: PlexMark, b: PlexMark) -> Bool { a.rawValue < b.rawValue }

    /// The share text's symbol: the pen marks, as type — circled, open, nothing.
    var symbol: String {
        switch self { case .correct: "◉"; case .present: "○"; case .absent: "·" }
    }
    /// What VoiceOver says after the letter.
    var spoken: String {
        switch self { case .correct: "right spot"; case .present: "in the word, wrong spot"; case .absent: "not in the word" }
    }
}

// MARK: - The words
/// Today's word and the guesses allowed, both from the lists Word Wheel already bundles:
/// every five-letter word in ENABLE is a guess; the everyday ones (12dicts) that aren't a plain
/// plural, a past tense or crude are the answers. The answers sit in a fixed seeded order and day N
/// takes the Nth, so everyone gets the same word and none repeats for ~8 years.
enum PlexiconWords {
    nonisolated static let length = 5
    /// Plexicon #1 is the day it shipped.
    nonisolated static let epoch = DateComponents(year: 2026, month: 11, day: 10)

    /// Fine to guess, never the word of the day: a daily word is the same for everyone.
    nonisolated static let notAnswers: Set<String> = [
        "bitch", "whore", "penis", "pussy", "boobs", "dildo", "sluts", "semen", "horny", "titty",
        "prick", "turds", "farts", "nazis", "raped", "rapes", "bimbo", "negro", "honky", "gypsy",
        "spick", "kikes", "dykes", "faggy", "queer", "porno", "booze", "vomit", "pubic", "rectum",
    ]

    /// The answers in play order. Changing the common list reshuffles every future day — append
    /// to the lists only if Plexicon's past days should change, which they shouldn't.
    nonisolated static let answers: [String] = {
        let list = WordList.shared
        var rng = SplitMix64(seed: 0x9_1E71_C0DE)
        return list.rank.keys
            .filter { $0.count == length && list.contains($0) && isAnswerShaped($0, in: list) }
            .sorted()
            .shuffled(using: &rng)
    }()

    /// Not an inflection of a shorter word (BOOKS, ASHES, FREED) and not on the crude list.
    nonisolated static func isAnswerShaped(_ w: String, in list: WordList) -> Bool {
        if notAnswers.contains(w) { return false }
        if w.hasSuffix("s"), !w.hasSuffix("ss"), list.contains(String(w.dropLast())) { return false }
        if w.hasSuffix("es"), list.contains(String(w.dropLast(2))) { return false }
        if w.hasSuffix("ed"), list.contains(String(w.dropLast(2))) || list.contains(String(w.dropLast())) { return false }
        return true
    }

    nonisolated static func answer(number: Int) -> String {
        guard !answers.isEmpty else { return "words" }
        return answers[(max(1, number) - 1) % answers.count]
    }

    nonisolated static func isGuess(_ w: String) -> Bool { w.count == length && WordList.shared.contains(w) }

    nonisolated static func number(for date: Date = .now, calendar: Calendar = .current) -> Int {
        guard let start = calendar.date(from: epoch) else { return 1 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0
        return max(1, days + 1)
    }

    /// Greens first; then a letter turns yellow only while the answer still has an unmatched copy
    /// of it, left to right — so two Es in a guess never claim one E in the answer twice.
    nonisolated static func score(_ guess: String, against answer: String) -> [PlexMark] {
        let g = Array(guess), a = Array(answer)
        var marks = [PlexMark](repeating: .absent, count: g.count)
        var left: [Character: Int] = [:]
        for i in g.indices {
            if i < a.count, g[i] == a[i] { marks[i] = .correct } else if i < a.count { left[a[i], default: 0] += 1 }
        }
        for i in g.indices where marks[i] != .correct {
            if let n = left[g[i]], n > 0 { marks[i] = .present; left[g[i]] = n - 1 }
        }
        return marks
    }

    #if DEBUG
    nonisolated static func selfCheck() {
        let A = PlexMark.absent, P = PlexMark.present, C = PlexMark.correct
        assert(score("speed", against: "abide") == [A, A, P, A, P], "a second E with one E left must stay gray")
        assert(score("eerie", against: "there") == [P, A, P, A, C], "the green E claims its copy first")
        assert(score("abbey", against: "kebab") == [P, P, C, P, A], "one B green, the other yellow")
        assert(score("llama", against: "hello") == [P, P, A, A, A], "two Ls, two in the answer")
        assert(score("crane", against: "crane") == [C, C, C, C, C])
        assert(answers.count > 2000, "only \(answers.count) answers")
        assert(answers.allSatisfy { $0.count == 5 && isGuess($0) }, "an answer isn't a valid guess")
        assert(Set(answers).isDisjoint(with: notAnswers), "a crude word is an answer")
        assert(!answers.contains("books") && !answers.contains("ashes") && !answers.contains("freed"), "a plain inflection is an answer")
        assert(answer(number: 1) == answer(number: 1 + answers.count) && answer(number: 1) != answer(number: 2))
        let cal = Calendar.current
        for n in 1...800 {
            let date = cal.date(byAdding: .day, value: n - 1, to: cal.date(from: epoch)!)!
            assert(number(for: date) == n, "day \(n) is numbered \(number(for: date))")
        }
    }
    #endif
}

// MARK: - The save
/// A player's Plexicon: today's guesses (the board and the keyboard are replayed from them), the
/// streak, and finished days. One record under one key, like the other games.
struct PlexiconSave: Codable {
    var number = 0                  // the day `guesses` belong to
    var guesses: [String] = []
    var streak = 0
    var bestStreak = 0
    var lastSolved = 0
    var rulesSeen = false
    var played = 0
    var won = 0
    var lastCounted = 0             // so a day counts once
    /// Wins by guess count: index 0 is "in one".
    var distribution = [Int](repeating: 0, count: 6)

    var winPercent: Int { played == 0 ? 0 : Int((Double(won) * 100 / Double(played)).rounded()) }
    /// A missed day zeroes the streak without anything being written.
    func streak(asOf number: Int) -> Int { lastSolved >= number - 1 ? streak : 0 }

    private static let key = "plexicon"

    static func load() -> PlexiconSave {
        guard let d = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(PlexiconSave.self, from: d) else { return PlexiconSave() }
        return s
    }

    func store() { UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.key) }
}

// MARK: - The game
/// The game with no SwiftUI in it: today's word, the row being typed, the guesses, and what the
/// last enter did. The view draws and reacts; this decides.
@MainActor @Observable final class Plexicon {
    enum Phase: Equatable { case playing, won, lost }

    struct Flash: Identifiable, Equatable {
        enum Kind: Equatable { case invalid, landed }
        let id: Int
        let kind: Kind
    }

    nonisolated static let maxGuesses = 6
    /// Between one tile's highlighter and the next.
    nonisolated static let stagger = 0.22
    static let hint = "Find today's five-letter word"

    private(set) var save = PlexiconSave.load()
    private(set) var answer: String?
    private(set) var typed = ""
    private(set) var phase: Phase = .playing
    /// True while the newest row's marks are drawing in; the keyboard waits so it can't give the
    /// row away before the tiles do.
    private(set) var revealing = false
    private(set) var flash: Flash?
    private(set) var caption: String?
    /// True once the game ends on this screen; false when a finished day is merely reloaded.
    private(set) var justFinished = false
    private var flashes = 0
    private var captionTask: Task<Void, Never>?

    var guesses: [String] { save.guesses }
    var number: Int { save.number }
    var streak: Int { save.streak(asOf: number) }
    var finished: Bool { phase != .playing }
    var canType: Bool { phase == .playing && !revealing && answer != nil }

    func marks(_ guess: String) -> [PlexMark] { answer.map { PlexiconWords.score(guess, against: $0) } ?? [] }

    /// What each key has learned, from the rows that have finished drawing.
    var keyMarks: [Character: PlexMark] {
        var out: [Character: PlexMark] = [:]
        for g in guesses.dropLast(revealing ? 1 : 0) {
            for (ch, m) in zip(g, marks(g)) { out[ch] = max(out[ch] ?? .absent, m) }
        }
        return out
    }

    var shareText: String {
        let how = phase == .won ? "got it on guess \(guesses.count)" : "not today"
        return "Plexicon #\(number) · \(how)\n" + guesses.map { marks($0).map(\.symbol).joined(separator: " ") }.joined(separator: "\n")
    }

    var verdict: String {
        guard phase == .won else { return "Not today" }
        switch guesses.count {
        case 1: return "First guess"
        case 2: return "Sharp"
        case 3: return "Nicely done"
        case 4: return "Solid"
        case 5: return "Close one"
        default: return "Just in time"
        }
    }

    // MARK: Loading
    /// Builds the word lists off the main thread the first time, starts a fresh day if the date
    /// rolled over, and replays today's guesses.
    func load() async {
        let n = Self.today()
        justFinished = false
        answer = await Task.detached(priority: .userInitiated) { PlexiconWords.answer(number: n) }.value
        if save.number != n {
            save.number = n
            save.guesses = []
            save.store()
        }
        #if DEBUG
        // `SIMCTL_CHILD_PLEXICON_GUESSES=slate,crony simctl launch …` opens with those rows played.
        if save.guesses.isEmpty, let g = ProcessInfo.processInfo.environment["PLEXICON_GUESSES"] {
            save.guesses = g.split(separator: ",").map { String($0).lowercased() }.filter { $0.count == 5 }
        }
        #endif
        typed = ""
        revealing = false
        replay()
    }

    private static func today() -> Int {
        #if DEBUG
        if let d = ProcessInfo.processInfo.environment["PLEXICON_DAY"], let v = Int(d) { return v }
        #endif
        return PlexiconWords.number()
    }

    /// The board on screen is an earlier day's: midnight passed while the app was open or away.
    var isStale: Bool { answer != nil && save.number != Self.today() }

    private func replay() {
        phase = .playing
        if let answer, guesses.last == answer { phase = .won; tally(won: true) }
        else if guesses.count >= Self.maxGuesses { phase = .lost; tally(won: false) }
    }

    // MARK: Typing
    func type(_ letter: Character) {
        guard canType, typed.count < PlexiconWords.length, let l = letter.lowercased().first, l.isLetter, l.isASCII else { return }
        typed.append(l)
    }

    func delete() {
        guard canType, !typed.isEmpty else { return }
        typed.removeLast()
    }

    func enter() {
        guard canType, let answer else { return }
        guard typed.count == PlexiconWords.length else { show("Five letters"); emit(.invalid); return }
        guard PlexiconWords.isGuess(typed) else { show("Not a word I know"); emit(.invalid); return }
        save.guesses.append(typed)
        typed = ""
        save.store()
        revealing = true
        let guess = guesses.last!
        Task {
            // The last tile starts 4 staggers in and takes a slash to draw.
            try? await Task.sleep(for: .seconds(Self.stagger * 4 + 0.45))
            revealing = false
            emit(.landed)
            if guess == answer { win() } else if guesses.count >= Self.maxGuesses { lose() }
        }
    }

    private func win() {
        tally(won: true)
        justFinished = true
        phase = .won
    }

    private func lose() {
        tally(won: false)
        justFinished = true
        phase = .lost
    }

    /// Counts today once: a finished day is played; a win extends the streak, a loss ends it.
    private func tally(won: Bool) {
        guard save.lastCounted != save.number else { return }
        save.played += 1
        save.lastCounted = save.number
        if won {
            save.won += 1
            let k = min(max(guesses.count, 1), Self.maxGuesses) - 1
            if save.distribution.count < Self.maxGuesses { save.distribution = [Int](repeating: 0, count: Self.maxGuesses) }
            save.distribution[k] += 1
            save.streak = save.lastSolved == save.number - 1 ? save.streak + 1 : 1
            save.bestStreak = max(save.bestStreak, save.streak)
            save.lastSolved = save.number
        } else {
            save.streak = 0
        }
        save.store()
    }

    func markRulesSeen() {
        guard !save.rulesSeen else { return }
        save.rulesSeen = true
        save.store()
    }

    /// Where you are today, for the Home card: guesses to come, the one you're on, or how it ended.
    nonisolated static func cardDetail(_ save: PlexiconSave) -> String {
        let n = PlexiconWords.number()
        guard save.number == n, !save.guesses.isEmpty else { return "\(maxGuesses) guesses" }
        if save.lastSolved == n { return "Solved in \(save.guesses.count)" }
        if save.guesses.count >= maxGuesses { return "Back tomorrow" }
        return "Guess \(save.guesses.count + 1) of \(maxGuesses)"
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
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            caption = nil
        }
    }
}
