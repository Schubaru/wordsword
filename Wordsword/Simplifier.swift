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

    static func explainDifferently(_ d: Definition, tried: Int) async -> String {
        if let s = await ask("Explain the word \"\(d.word)\" (\(d.partOfSpeech)) a different way than this: \"\(d.senses.first ?? "")\". One or two short plain sentences, maybe a tiny analogy. Reply with only the explanation.") { return s }
        let alt = d.senses.dropFirst().map(heuristic)
        if tried < alt.count { return "Another way to put it: " + alt[tried] }
        if !d.synonyms.isEmpty { return "Think of it as roughly the same as \(d.synonyms.prefix(3).joined(separator: ", "))." }
        return "That's the plainest way I have to say it: " + heuristic(d.senses.first ?? "")
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
