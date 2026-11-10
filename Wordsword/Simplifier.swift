import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Turns dictionary wording into the wordsword voice (see ~/.claude/skills/wordsword):
/// one plain sentence, no jargon, never defines the word with itself.
/// Uses Apple's on-device model when the toolchain/device has it; otherwise honest heuristics.
enum Simplifier {
    /// Dictionary first. The on-device model once turned cleft's "An opening, fissure, or V-shaped
    /// indentation…" into "A crack is an opening…" — it defined the synonym. So the dictionary's own
    /// wording, tidied, is the headline; the model only rewrites a sense too long to take in at a
    /// glance, and its reply is shown only if it `passes`.
    static let rewriteOver = 100

    static func simplify(_ d: Definition) async -> String {
        let plain = heuristic(d.senses.first ?? "")
        guard plain.count > rewriteOver,
              let s = await ask("Rewrite this dictionary definition of \"\(d.word)\" (\(d.partOfSpeech)) as ONE plain-English sentence a smart 16-year-old would get instantly. Start with the meaning itself, not with another word followed by \"is\". Do not use the word itself. Reply with only the sentence.\n\nDefinition: \(d.senses.first ?? "")"),
              passes(s, for: d.word) else { return plain }
        return s
    }

    /// A model one-liner we'll show: one short sentence about this word. Not one that names another
    /// word as its subject ("A crack is…"), says the word itself, or talks about the request.
    static func passes(_ s: String, for word: String) -> Bool {
        let lower = s.lowercased()
        guard (8...160).contains(s.count),
              !lower.split(whereSeparator: { !$0.isLetter }).contains(Substring(word)),
              !lower.hasPrefix("here"), !lower.hasPrefix("sure") else { return false }
        if let m = lower.firstMatch(of: #/^(?:(?:a|an|the)\s+)?([a-z-]+)\s+(?:is|are|means|refers)\b/#),
           !["it", "this", "that", "someone", "something", "anyone", "anything", "when", "what"].contains(String(m.1)) { return false }
        return true
    }

    #if DEBUG
    static func selfCheck() {
        assert(!passes("A crack is an opening or indentation that is made by splitting or cracking.", for: "cleft"))
        assert(!passes("Cleft means split in two.", for: "cleft"))
        assert(passes("A long, narrow opening made by splitting something.", for: "cleft"))
        assert(passes("It means feeling hopeful that things will go well.", for: "sanguine"))
        assert(tidy("Sure! Here's a sentence using \"sanguine\": \"She stayed sanguine.\"") == "She stayed sanguine.")
        assert(tidy("here's a different way to explain 'cleft': A split.") == "A split.")
        assert(uses("Her hopes stayed sanguine.", "sanguine") && uses("She was happier.", "happy") && !uses("A split.", "cleft"))
    }
    #endif

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
                """), uses(s, d.word) { return firstSentences(s, 3) }
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

    /// The model's sentence if it really uses the word, else the dictionary's example, else nil:
    /// a made-up template ("It was so sanguine that everyone noticed") misuses more words than it helps.
    static func sentence(_ d: Definition) async -> String? {
        let reply = await ask("Write one natural, modern example sentence using the word \"\(d.word)\" as a \(d.partOfSpeech), the kind you'd find in a novel. Reply with only the sentence.")
        if let s = reply, uses(s, d.word) { return firstSentences(s, 1) }
        if let e = d.example, !e.isEmpty { return e.prefix(1).uppercased() + e.dropFirst() }
        return nil
    }

    /// The reply mentions the word, allowing a changed ending (happy → happier, sanguine → sanguinely).
    static func uses(_ s: String, _ word: String) -> Bool {
        let w = word.lowercased()
        let stem = w.count > 4 && (w.hasSuffix("e") || w.hasSuffix("y")) ? String(w.dropLast()) : w
        return s.lowercased().contains(stem)
    }

    /// The on-device model opens by echoing the request ("Sure! Here's a sentence using…:") and
    /// wraps its answer in quotes. Strip both, so every caller sees only the answer.
    static func tidy(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for preamble in [#"(?i)^(sure|of course|okay|ok|certainly)[!.,]\s*"#, #"(?i)^(here(?:'|’)s|here is)[^:\n]*:\s*"#] {
            s = s.replacingOccurrences(of: preamble, with: "", options: .regularExpression)
        }
        return s.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”' \n"))
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

    /// The simulator's model misses 8s on a cold start; the screenshot tour sets MODEL_TIMEOUT=30.
    private static var timeout: Double {
        #if DEBUG
        if let t = ProcessInfo.processInfo.environment["MODEL_TIMEOUT"].flatMap(Double.init) { return t }
        #endif
        return 8
    }

    private static func ask(_ prompt: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            guard SystemLanguageModel.default.isAvailable else { return nil }
            // A reply that hasn't landed in 8s isn't coming in time to help; nil lets the fallbacks answer.
            return await withTaskGroup(of: String?.self) { g in
                g.addTask {
                    let session = LanguageModelSession(instructions: "You are wordsword, a sharp friend who explains words in plain English. Be brief. Never use markdown.")
                    return (try? await session.respond(to: prompt).content).map(tidy)
                }
                g.addTask { try? await Task.sleep(for: .seconds(timeout)); return nil }
                let first = await g.next() ?? nil
                g.cancelAll()
                return first
            }
        }
        #endif
        return nil
    }
}
