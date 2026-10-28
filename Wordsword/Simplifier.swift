import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Turns dictionary wording into the wordsword voice (see ~/.claude/skills/wordsword):
/// one plain sentence, no jargon, never defines the word with itself.
/// Uses Apple's on-device model when the toolchain/device has it; otherwise honest heuristics.
enum Simplifier {
    static func simplify(_ d: Definition) async -> String {
        if let s = await ask("Rewrite this dictionary definition of \"\(d.word)\" (\(d.partOfSpeech)) as ONE plain-English sentence a smart 16-year-old would get instantly. Do not use the word itself. Reply with only the sentence.\n\nDefinition: \(d.senses.first ?? "")") { return s }
        return heuristic(d.senses.first ?? "")
    }

    /// Not a simpler version — a different way in. Each tap takes a new angle; once they're used up,
    /// the dictionary's own wording, then round again.
    static func explainDifferently(_ d: Definition, tried: Int) async -> String {
        let sense = d.senses.first ?? ""
        let dictionary = "Here's how the dictionary puts it: " + sense
        let gloss = await Dictionary.rarestGloss(in: keyWords(sense, skipping: d.word))
        if modelReady {
            let i = tried % (lenses.count + 1)
            if i == lenses.count { return dictionary }
            // The small on-device model invents facts when pushed for an analogy; hand it the hard word's meaning.
            let fact = gloss.map { "\nFor reference, \"\($0.word)\" means: \($0.sense)" } ?? ""
            if let s = await ask("""
                Someone read this definition of "\(d.word)" (\(d.partOfSpeech)) and it didn't click: "\(sense)"\(fact)
                Explain it again through \(lenses[i]). Don't just reword or shorten the definition; give them a new way in. \
                Stay accurate: if a comparison would be a stretch, use a plain real example instead. \
                End by making clear what "\(d.word)" means. \
                Two or three short sentences in plain words. Reply with only the explanation.
                """) { return firstSentences(s, 3) }
        }
        var angles: [String] = []
        if let r = rephrase(sense) { angles.append(r) }
        if let g = gloss {
            angles.append("It hinges on “\(g.word)”, which means \(g.sense.prefix(1).lowercased() + g.sense.dropFirst())")
        }
        angles += d.senses.dropFirst().map { "It can also mean: " + heuristic($0) }
        if !d.synonyms.isEmpty { angles.append("It sits close to \(d.synonyms.prefix(3).joined(separator: ", ")).") }
        let i = tried % (angles.count + 1)
        return i < angles.count ? angles[i] : dictionary
    }

    /// What the model looks through on each tap, in order. Concrete first: the on-device model
    /// is most accurate grounded in a real situation and loosest with analogies.
    private static let lenses = [
        "where someone would actually run into it in real life",
        "a two-sentence scene where the word comes up naturally",
        "what it is not: its opposite, or a word it's easily confused with",
        "where the word comes from, if that makes the meaning click",
        "an everyday comparison",
    ]

    /// Dictionary formulas, said the way a person would.
    private static let formulas = [
        ("of or pertaining to ", "It describes anything to do with "), ("of or relating to ", "It describes anything to do with "),
        ("pertaining to ", "It describes anything to do with "), ("relating to ", "It describes anything to do with "),
        ("the act or process of ", "It's the name for "), ("the act of ", "It's the name for "),
        ("the state of being ", "It's what it's like to be "), ("the quality of being ", "It's what it's like to be "),
        ("the condition of being ", "It's what it's like to be "),
        ("one who ", "It's someone who "), ("a person who ", "It's someone who "),
        ("characterized by ", "It describes something marked by "), ("having ", "It describes something with "),
        ("to cause to ", "It means making something "),
    ]

    private static func rephrase(_ sense: String) -> String? {
        let s = sense.trimmingCharacters(in: .whitespaces)
        guard let (from, to) = formulas.first(where: { s.lowercased().hasPrefix($0.0) }) else { return nil }
        return to + s.dropFirst(from.count).trimmingCharacters(in: CharacterSet(charactersIn: " .")) + "."
    }

    private static let filler: Set<String> = ["pertaining", "relating", "especially", "something", "someone", "having",
        "being", "which", "that", "with", "from", "into", "than", "their", "other", "more", "about", "very", "such", "used"]

    /// The on-device model ignores length limits and "no markdown", and opens with "Sure!" or a
    /// "Scene:" label — tidy all of that here.
    private static func firstSentences(_ raw: String, _ n: Int) -> String {
        var s = raw.replacingOccurrences(of: "*", with: "")
        for filler in [#"^\s*(Sure|Of course|Okay|OK)[!.,]\s*"#, #"^\s*[A-Z][a-z]+:\s+"#] {
            s = s.replacingOccurrences(of: filler, with: "", options: .regularExpression)
        }
        var out: [String] = []
        s.enumerateSubstrings(in: s.startIndex..., options: .bySentences) { sub, _, _, stop in
            if let sub { out.append(sub.trimmingCharacters(in: .whitespacesAndNewlines)) }
            if out.count == n { stop = true }
        }
        return out.isEmpty ? s : out.joined(separator: " ")
    }

    /// The content words of a definition, for finding the one that's doing the heavy lifting.
    private static func keyWords(_ sense: String, skipping word: String) -> [String] {
        let ws = sense.lowercased().split { !$0.isLetter }.map(String.init)
        return Array(ws.filter { $0.count >= 4 && $0 != word && !filler.contains($0) }.prefix(5))
    }

    static func sentence(_ d: Definition) async -> String {
        if let s = await ask("Write one natural, modern example sentence using the word \"\(d.word)\" as a \(d.partOfSpeech), the kind you'd find in a novel. Reply with only the sentence.") { return s }
        if let e = d.example, !e.isEmpty { return e.prefix(1).uppercased() + e.dropFirst() }
        switch d.partOfSpeech {   // ponytail: canned templates until the on-device model is available
        case "adjective": return "It was so \(d.word) that everyone in the room noticed."
        case "verb":      return "She decided to \(d.word) before anyone could stop her."
        case "adverb":    return "He said it \(d.word), and the conversation shifted."
        default:          return "There was a certain \(d.word) to the whole afternoon."
        }
    }

    // MARK: - heuristics
    /// Dictionary senses often chain clauses with ";" or pile on qualifiers. Keep the first clause, tidy it.
    static func heuristic(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = s.firstIndex(of: ";") { s = String(s[..<i]) }
        for sep in [", especially", ", typically", ", usually", " (", ", as ", ", or "] where s.count > 90 {
            if let r = s.range(of: sep) { s = String(s[..<r.lowerBound]) }
        }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " .,"))
        guard let f = s.first else { return raw }
        return f.uppercased() + s.dropFirst() + "."
    }

    // MARK: - on-device model
    private static var modelReady: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) { return SystemLanguageModel.default.isAvailable }
        #endif
        return false
    }

    private static func ask(_ prompt: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            guard SystemLanguageModel.default.isAvailable else { return nil }
            let session = LanguageModelSession(instructions: "You are wordsword, a sharp friend who explains words in plain English. Be brief. Never use markdown.")
            return try? await session.respond(to: prompt).content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        return nil
    }
}
