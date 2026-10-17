import Foundation
import Observation

/// The game with no SwiftUI in it: what's on the wheel, what's connected, what's been found, and
/// what the last submission did. The view reacts; this decides.
@MainActor @Observable final class WordWheel {
    struct Flash: Identifiable, Equatable {
        enum Kind: Equatable { case board(coins: Int), bonus(coins: Int), already, invalid }
        let id: Int
        let word: String
        let kind: Kind
    }

    private(set) var save = WordWheelSave.load()
    private(set) var level: Level?
    /// Wheel slot → index into `level.letters`. Shuffle permutes this; the letters themselves never move.
    private(set) var order: [Int] = []
    /// Letter indices in the order they were connected.
    private(set) var selection: [Int] = []
    /// Hint bought, waiting for a tile.
    private(set) var picking = false
    /// The last submission, held for a beat so the capsule can react to it.
    private(set) var flash: Flash?
    private(set) var caption: String?
    /// The board word most recently found, so its tiles can write in one after another.
    private(set) var lastFound: Level.Placed?
    private var flashes = 0
    private var captionTask: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?

    var current: String { String(selection.compactMap { level?.letters[$0] }) }
    var found: Set<String> { Set(save.foundTargets) }
    var completed: Bool {
        guard let level, !level.targets.isEmpty else { return false }
        return level.targets.allSatisfy { found.contains($0.word) }
    }
    var canHint: Bool { save.coins >= WordWheelRules.hintPrice }
    var multiplier: Double { WordWheelRules.multiplier(streak: save.streak) }

    /// Builds the current level off the main thread (the first call also loads the dictionary).
    func load() async {
        let index = save.level
        let built = await Task.detached(priority: .userInitiated) { Level.make(index: index, list: .shared) }.value
        level = built
        order = Array(built.letters.indices)
        // A level rebuilt by a newer generator may not hold what an older save found on it.
        save.foundTargets.removeAll { !built.targetWords.contains($0) }
        save.revealed.removeAll { built.grid[$0] == nil }
        save.store()
    }

    // MARK: Connecting letters
    /// The finger entered a letter. Dragging back onto the previous one undoes the last.
    func enter(_ i: Int) {
        picking = false
        guard selection.last != i else { return }
        if let at = selection.firstIndex(of: i) {
            if at == selection.count - 2 { selection.removeLast() }
        } else {
            selection.append(i)
        }
    }

    func release() {
        let word = current
        selection = []
        guard word.count >= WordWheelRules.minWordLength else { return }
        submit(word)
    }

    /// Typed instead of dragged (VoiceOver's path). Still has to come from the wheel.
    func submit(typed: String) {
        let w = typed.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let level, w.count >= WordWheelRules.minWordLength, WordList.canMake(w, from: level.letters) else {
            show("Use only the wheel's letters, three or more"); return
        }
        submit(w)
    }

    private func submit(_ word: String) {
        guard let level else { return }
        let kind: Flash.Kind
        if found.contains(word) || save.foundBonus.contains(word) {
            kind = .already
            show("Already found")
        } else if level.targetWords.contains(word) {
            save.streak += 1
            let c = WordWheelRules.coins(for: word, bonus: false, streak: save.streak)
            save.coins += c; save.levelCoins += c
            save.foundTargets.append(word)
            lastFound = level.targets.first { $0.word == word }
            remember(word)
            kind = .board(coins: c)
        } else if level.bonus.contains(word) {
            save.streak += 1
            let c = WordWheelRules.coins(for: word, bonus: true, streak: save.streak)
            save.coins += c; save.levelCoins += c
            save.foundBonus.append(word)
            remember(word)
            kind = .bonus(coins: c)
            show("+\(c) — bonus word")
        } else {
            save.streak = 0
            kind = .invalid
            show("Not a word I know")
        }
        save.bestStreak = max(save.bestStreak, save.streak)
        save.store()
        flashes += 1
        flash = Flash(id: flashes, word: word, kind: kind)
        flashTask?.cancel()
        flashTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            flash = nil
        }
    }

    private func remember(_ w: String) {
        save.history.removeAll { $0 == w }
        save.history.insert(w, at: 0)
    }

    // MARK: The wheel
    func shuffle() {
        guard order.count > 1 else { return }
        var next = order
        repeat { next.shuffle() } while next == order
        order = next
        selection = []
        picking = false
    }

    // MARK: Hints
    /// Tap once to pick a tile; tap again to change your mind.
    func hint() {
        if picking { picking = false; return }
        guard canHint else { show("Find a few more words first"); return }
        guard let level, level.grid.keys.contains(where: { letter(at: $0) == nil }) else { return }
        picking = true
        selection = []
    }

    func cancelHint() { picking = false }

    func reveal(_ cell: Level.Cell) {
        guard picking, let level, level.grid[cell] != nil, letter(at: cell) == nil else { return }
        picking = false
        save.coins -= WordWheelRules.hintPrice
        save.revealed.append(cell)
        // A word whose every letter is now showing counts as found. No coins: the hints paid for it.
        for p in level.targets where !found.contains(p.word) && p.cells.allSatisfy({ letter(at: $0) != nil }) {
            save.foundTargets.append(p.word)
            remember(p.word)
        }
        save.store()
    }

    /// The letter showing in a tile — from a found word or a hint. nil = still blank.
    func letter(at cell: Level.Cell) -> Character? {
        guard let level, let ch = level.grid[cell] else { return nil }
        if save.revealed.contains(cell) { return ch }
        return level.targets.contains { found.contains($0.word) && $0.cells.contains(cell) } ? ch : nil
    }

    func isRevealed(_ cell: Level.Cell) -> Bool { save.revealed.contains(cell) }

    /// A found word running through this tile, for tap-to-define.
    func foundWord(at cell: Level.Cell) -> String? {
        level?.targets.first { found.contains($0.word) && $0.cells.contains(cell) }?.word
    }

    // MARK: Levels
    func nextLevel() {
        save.level += 1
        save.levelCoins = 0
        save.foundTargets = []
        save.foundBonus = []
        save.revealed = []
        save.store()
        level = nil
        lastFound = nil
        selection = []
        picking = false
        Task { await load() }
    }

    #if DEBUG
    /// Poses a half-spelled word for screenshots.
    func debugSelect(_ n: Int) { selection = Array(order.prefix(n)) }
    #endif

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
