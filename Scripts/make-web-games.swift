// Builds the web games' data (docs/play/data/) and the golden file the web is checked against
// (Scripts/web-games-golden.json), straight from the app's own game code — nothing re-implemented
// here, so the web plays the app's puzzles. Run after editing any game list or bank:
//
//   S=Wordsword/Games; B=$(mktemp -d)
//   swiftc -O -parse-as-library Scripts/make-web-games.swift $S/WordWheelLevels.swift $S/WordWheelRules.swift \
//     $S/Plexicon.swift $S/LinkingWordsPuzzles.swift $S/Haikuzy.swift -o $B/webgames
//   cp $S/*.txt $B/ && $B/webgames && node Scripts/check-web-games.mjs
//
// The .txt lists sit next to the binary because that's where a command-line tool's Bundle.main
// looks. macOS only (Haiklu's scores need NaturalLanguage).
import Foundation

@main struct MakeWebGames {
    static func main() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let games = root.appendingPathComponent("Wordsword/Games")
        let data = root.appendingPathComponent("docs/play/data")
        try FileManager.default.createDirectory(at: data.appendingPathComponent("haiklu"), withIntermediateDirectories: true)
        func write(_ text: String, _ name: String) throws {
            try text.write(to: data.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        func copy(_ name: String) throws {
            let to = data.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: to)
            try FileManager.default.copyItem(at: games.appendingPathComponent(name), to: to)
        }

        // Plexicon: the whole answer cycle in play order, and every word that counts as a guess.
        let answers = PlexiconWords.answers
        precondition(answers.count > 2000, "word lists didn't load — are the .txt files next to the binary?")
        try write(answers.joined(separator: "\n") + "\n", "plexicon-answers.txt")
        let guesses = WordList.shared.words.filter { $0.count == PlexiconWords.length }.sorted()
        try write(guesses.joined(separator: "\n") + "\n", "plexicon-guesses.txt")

        // Linking words: the bank as is; the browser runs the same seeded combiner.
        try copy("linking-words.txt")

        // Haiklu: the poems in bank order, the word lists for typo fixes, and each poem's scores.
        let bank = HaikuzyBank.all
        let poems = bank.map { ["season": $0.season.rawValue, "lines": $0.lines, "answer": $0.answer] as [String: Any] }
        try write(String(data: JSONSerialization.data(withJSONObject: poems), encoding: .utf8)!, "haiklu-bank.json")
        try copy("haiku-words.txt")
        try copy("haiku-common.txt")
        let words = HaikuzyWords.shared
        var scored = Set(try String(contentsOf: games.appendingPathComponent("haiku-common.txt"), encoding: .utf8)
            .split(separator: "\n").map(String.init).filter(words.contains))
        for near in HaikuzyScore.table.values { scored.formUnion(near.rank.keys.filter(words.contains)) }
        let pool = scored.sorted()
        for (i, h) in bank.enumerated() {
            // `57: word word …`, best first; anything that scores 1 is left out.
            var byScore: [Int: [String]] = [:]
            for w in pool {
                let s = HaikuzyScore.score(w, answer: h.answer)
                if s > 1 { byScore[s, default: []].append(w) }
            }
            let text = byScore.keys.sorted(by: >).map { "\($0): " + byScore[$0]!.joined(separator: " ") }.joined(separator: "\n")
            try write(text + "\n", "haiklu/\(i).txt")
        }

        // The golden: what the app plays on days 1…800, plus its own self-check cases.
        let index = Swift.Dictionary(uniqueKeysWithValues: bank.enumerated().map { ($1.answer, $0) })
        var days: [[String: Any]] = []
        for n in 1...800 {
            let p = LinkingPuzzle.make(number: n)
            days.append([
                "n": n,
                "plexicon": PlexiconWords.answer(number: n),
                "linking": [
                    "groups": p.groups.map { ["tier": $0.tier.rawValue, "ink": $0.ink.rawValue, "headword": $0.headword, "words": $0.words] },
                    "order": p.order,
                ],
                "haiklu": index[HaikuzyBank.haiku(number: n)!.answer]!,
            ])
        }
        let typos = ["globe", "glob", "gloeb", "embre", "lantren", "persimon", "qzxvbn", "heorn", "quitt", "cnidle"]
        let resolve = typos.map { t -> [String: Any] in
            switch words.resolve(t) {
            case .word(let w): ["typed": t, "word": w]
            case .corrected(_, let to): ["typed": t, "corrected": to]
            case .choices(let ws): ["typed": t, "choices": ws]
            case .unknown: ["typed": t, "unknown": true]
            }
        }
        let pairs = [("ember", "ember"), ("embers", "ember"), ("track", "tracks"), ("muffle", "muffled"), ("wicked", "wick"),
                     ("coal", "ember"), ("fire", "ember"), ("quiet", "hush"), ("banana", "ember"), ("egret", "heron"), ("car", "heron")]
        let scores = pairs.map { ["guess": $0.0, "answer": $0.1, "score": HaikuzyScore.score($0.0, answer: $0.1)] as [String: Any] }
        let plex = [("speed", "abide"), ("eerie", "there"), ("abbey", "kebab"), ("llama", "hello"), ("crane", "crane")]
        let marks = plex.map { ["guess": $0.0, "answer": $0.1, "marks": PlexiconWords.score($0.0, against: $0.1).map(\.rawValue)] as [String: Any] }
        let golden: [String: Any] = ["days": days, "resolve": resolve, "scores": scores, "plexicon": marks]
        try JSONSerialization.data(withJSONObject: golden, options: [.sortedKeys])
            .write(to: root.appendingPathComponent("Scripts/web-games-golden.json"))
        print("web games: \(answers.count) Plexicon answers, \(guesses.count) guesses, \(bank.count) haiku, \(pool.count) scored words")
    }
}
