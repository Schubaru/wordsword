import Foundation
import Observation

/// The game with no SwiftUI in it: today's puzzle, what's selected, what's been solved, how many
/// strikes, and what the last submission did. The view reacts; this decides.
@MainActor @Observable final class LinkingWords {
    enum Phase: Equatable { case playing, won, lost }

    struct Flash: Identifiable, Equatable {
        enum Kind: Equatable { case solved(LinkingPuzzle.Group), wrong, oneAway, already }
        let id: Int
        let kind: Kind
    }

    nonisolated static let maxMistakes = 4
    static let hint = "Four groups of four words that mean the same thing"

    private(set) var save = LinkingWordsSave.load()
    private(set) var puzzle: LinkingPuzzle?
    /// Tapped words, in tap order.
    private(set) var selected: [String] = []
    /// Strips, in the order they appeared — solved by the player, then revealed after a loss.
    private(set) var solved: [LinkingPuzzle.Group] = []
    private(set) var mistakes = 0
    private(set) var phase: Phase = .playing
    /// True from the fourth tap until the result lands: the tiles are hopping.
    private(set) var submitting = false
    /// True while the unsolved groups are being revealed after the fourth strike.
    private(set) var revealing = false
    private(set) var flash: Flash?
    private(set) var caption: String?
    /// True once a game ends on this screen; false when a finished day is merely reloaded.
    private(set) var justFinished = false
    private var flashes = 0
    private var flashTask: Task<Void, Never>?
    private var captionTask: Task<Void, Never>?

    /// The words still on the grid, in board order.
    var remaining: [String] {
        let gone = Set(solved.flatMap(\.words))
        return save.order.filter { !gone.contains($0) }
    }
    var mistakesLeft: Int { Self.maxMistakes - mistakes }
    var number: Int { puzzle?.number ?? save.number }
    var streak: Int { save.streak(asOf: number) }
    var finished: Bool { phase != .playing }
    var canSubmit: Bool { selected.count == 4 && phase == .playing && !submitting }

    /// Each guess as a row of squares, the way results are shared.
    var shareRows: [[LinkTier]] {
        guard let puzzle else { return [] }
        return save.guesses.map { $0.compactMap { puzzle.group(of: $0)?.tier } }
    }
    var shareText: String {
        "Linking words #\(number)\n" + shareRows.map { $0.map(\.square).joined() }.joined(separator: "\n")
    }
    /// The results title, by how it went.
    var verdict: String {
        switch (phase, mistakes) {
        case (.lost, _): "Not today"
        case (_, 0): "Clean sweep"
        case (_, 1): "Nicely done"
        case (_, 2): "Solid"
        default: "Close one"
        }
    }

    // MARK: Loading
    /// Builds today's puzzle off the main thread, starts a fresh day if the date rolled over, and
    /// replays today's guesses so the board comes back exactly as it was left.
    func load() async {
        var n = LinkingPuzzle.number()
        #if DEBUG
        if let d = ProcessInfo.processInfo.environment["LINKING_DAY"], let v = Int(d) { n = v }
        #endif
        let built = await Task.detached(priority: .userInitiated) { LinkingPuzzle.make(number: n) }.value
        puzzle = built
        if save.number != n || save.order.count != built.order.count || Set(save.order) != Set(built.order) {
            save.number = n
            save.order = built.order
            save.guesses = []
            save.store()
        }
        #if DEBUG
        // `SIMCTL_CHILD_LINKING_POSE=2 simctl launch …` opens with two groups already solved.
        if save.guesses.isEmpty, let p = ProcessInfo.processInfo.environment["LINKING_POSE"], let k = Int(p) {
            save.guesses = built.groups.prefix(max(0, min(k, 4))).map(\.words)
        }
        #endif
        replay()
    }

    private func replay() {
        guard let puzzle else { return }
        solved = []; mistakes = 0; phase = .playing; selected = []
        for g in save.guesses {
            if let group = puzzle.group(matching: g) { solved.append(group) } else { mistakes += 1 }
        }
        if solved.count == puzzle.groups.count {
            phase = .won
            credit()
        } else if mistakes >= Self.maxMistakes {
            solved += puzzle.groups.filter { !solved.contains($0) }
            phase = .lost
        }
    }

    // MARK: Picking
    func tap(_ word: String) {
        guard phase == .playing, !submitting else { return }
        if let i = selected.firstIndex(of: word) { selected.remove(at: i); return }
        guard selected.count < 4 else { return }
        selected.append(word)
        if selected.count == 4 { submit() }
    }

    func deselectAll() {
        guard !submitting else { return }
        selected = []
    }

    /// Reorders only what's still on the grid; the solved words keep their place at the front.
    func shuffle() {
        guard phase == .playing, !submitting else { return }
        let gone = Set(solved.flatMap(\.words))
        var rest = save.order.filter { !gone.contains($0) }
        guard rest.count > 1 else { return }
        let before = rest
        repeat { rest.shuffle() } while rest == before
        save.order = save.order.filter { gone.contains($0) } + rest
        save.store()
    }

    // MARK: Submitting
    /// The tiles hop first (the view animates `submitting`), then the guess lands.
    func submit() {
        guard canSubmit, let puzzle else { return }
        let guess = selected
        submitting = true
        Task {
            try? await Task.sleep(for: .milliseconds(80 * 4 + 300))
            submitting = false
            land(guess, in: puzzle)
        }
    }

    private func land(_ guess: [String], in puzzle: LinkingPuzzle) {
        let set = Set(guess)
        if save.guesses.contains(where: { Set($0) == set }) {
            show("Already guessed")
            emit(.already)
            return
        }
        save.guesses.append(guess)
        if let group = puzzle.group(matching: guess) {
            // The four move to the top row first; the strip takes their place a beat later.
            save.order = save.order.filter { gone(in: $0) } + guess + save.order.filter { !gone(in: $0) && !set.contains($0) }
            selected = []
            save.store()
            emit(.solved(group))
            Task {
                try? await Task.sleep(for: .milliseconds(380))
                solved.append(group)
                remember(group)
                if solved.count == puzzle.groups.count { win() }
            }
        } else {
            mistakes += 1
            save.store()
            let oneAway = puzzle.isOneAway(guess)
            if oneAway { show("One away…") }
            emit(oneAway ? .oneAway : .wrong)
            if mistakes >= Self.maxMistakes { lose(puzzle) }
        }
    }

    private func gone(in word: String) -> Bool { solved.contains { $0.words.contains(word) } }

    private func win() {
        credit()
        justFinished = true
        phase = .won
    }

    /// Counts today towards the streak, once.
    private func credit() {
        guard save.lastSolved != save.number else { return }
        save.streak = save.lastSolved == save.number - 1 ? save.streak + 1 : 1
        save.bestStreak = max(save.bestStreak, save.streak)
        save.lastSolved = save.number
        save.store()
    }

    /// Four strikes: the rest of the groups come up one at a time, then the day is over.
    private func lose(_ puzzle: LinkingPuzzle) {
        selected = []
        show("Next time")
        revealing = true
        Task {
            for g in puzzle.groups where !solved.contains(g) {
                try? await Task.sleep(for: .milliseconds(700))
                save.order = save.order.filter { gone(in: $0) } + g.words + save.order.filter { !gone(in: $0) && !g.words.contains($0) }
                try? await Task.sleep(for: .milliseconds(380))
                solved.append(g)
            }
            revealing = false
            justFinished = true
            phase = .lost
        }
    }

    /// A word you link is a word you can look up: the four and their headword, newest first.
    private func remember(_ g: LinkingPuzzle.Group) {
        for w in (g.words + [g.headword.lowercased()]).reversed() {
            save.history.removeAll { $0 == w }
            save.history.insert(w, at: 0)
        }
        save.store()
    }

    /// Where you are in today's puzzle, for the Home card and the hub row: how many mistakes are
    /// left until the day's over, or that it is.
    nonisolated static func cardDetail(_ save: LinkingWordsSave) -> String {
        let n = LinkingPuzzle.number()
        guard save.number == n, !save.guesses.isEmpty else { return "\(maxMistakes) mistakes left" }
        if save.lastSolved == n { return "Solved" }
        let puzzle = LinkingPuzzle.make(number: n)
        let left = maxMistakes - save.guesses.filter { puzzle.group(matching: $0) == nil }.count
        return left <= 0 ? "Back tomorrow" : "\(left) mistake\(left == 1 ? "" : "s") left"
    }

    func markRulesSeen() {
        guard !save.rulesSeen else { return }
        save.rulesSeen = true
        save.store()
    }

    // MARK: Signals
    private func emit(_ kind: Flash.Kind) {
        flashes += 1
        flash = Flash(id: flashes, kind: kind)
        flashTask?.cancel()
        flashTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            flash = nil
        }
    }

    private func show(_ text: String) {
        caption = text
        captionTask?.cancel()
        var seconds = 2.2
        #if DEBUG
        // `SIMCTL_CHILD_LINKING_CAPTION=10 simctl launch …` holds captions long enough to screenshot.
        if let s = ProcessInfo.processInfo.environment["LINKING_CAPTION"], let v = Double(s) { seconds = v }
        #endif
        captionTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            caption = nil
        }
    }
}
