import Foundation

/// What we know about a word after one lookup.
struct Definition {
    var word: String
    var partOfSpeech: String
    var senses: [String]          // most common sense first, obsolete/archaic filtered out
    var example: String?
    var synonyms: [String]
    var simple: String?           // the wordsword one-liner, set once Simplifier has run
    var respelling: String?       // "SANG-gwin" — how to say it, from Datamuse's Arpabet
    var audio: URL?               // a human recording, when dictionaryapi.dev happens to have one
}

enum Lookup {
    case found(Definition)
    case suggestions([String])    // misspelling → closest words
    case notFound
    case offline
}

/// Two free, keyless sources:
/// - Datamuse (`md=dpr`) is the primary for sense TEXT — its senses are frequency-ordered,
///   so "sanguine" leads with optimism, not blood. Also spelling suggestions, synonyms, and the
///   Arpabet the respelling is built from (`r`) — which is why pronunciation costs no extra request.
/// - dictionaryapi.dev enriches with an example sentence, extra synonyms and a human recording,
///   and is the fallback when Datamuse has no entry. (It 502s regularly; never trust it alone —
///   hence the respelling comes from Datamuse and only the recording from here.)
enum Dictionary {
    static func lookup(_ raw: String) async -> Lookup {
        let word = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !word.isEmpty else { return .notFound }

        async let primaryTask = primary(word)
        let dm = await datamuseDefinition(word)
        let p = await primaryTask

        if var d = dm {
            if case .success(let rich) = p {
                if rich.partOfSpeech == d.partOfSpeech { d.example = d.example ?? rich.example }
                d.synonyms = dedupe(d.synonyms + rich.synonyms, dropping: word)
                d.audio = rich.audio
            }
            if d.synonyms.count < 4 { d.synonyms = dedupe(d.synonyms + (await synonyms(for: word)), dropping: word) }
            return .found(d)
        }
        switch p {
        case .success(let d): return .found(d)
        case .network: return .offline
        case .missing, .unavailable:
            let s = await suggestions(for: word).filter { $0 != word }
            return s.isEmpty ? .notFound : .suggestions(s)
        }
    }

    /// Words saved before pronunciation existed have none. Fill it in on their next lookup — but
    /// never make the user wait on the network for a word that is meant to open instantly and offline.
    static func pronunciation(for word: String, within seconds: Double = 2) async -> Pronunciation? {
        await withTaskGroup(of: Pronunciation?.self) { g in
            g.addTask {
                guard case .found(let d) = await lookup(word), let r = d.respelling else { return nil }
                return Pronunciation(respelling: r, audio: d.audio)
            }
            g.addTask { try? await Task.sleep(for: .seconds(seconds)); return nil }
            let first = await g.next() ?? nil
            g.cancelAll()
            return first
        }
    }

    // MARK: Datamuse (primary sense text)
    static func suggestions(for word: String) async -> [String] {
        await datamuse("sp=\(word)&max=6").map(\.word)
    }

    static func synonyms(for word: String) async -> [String] {
        await datamuse("rel_syn=\(word)&max=12").map(\.word)
    }

    private static let staleLabels = ["(obsolete", "(archaic", "(dated", "(rare"]

    private static func datamuseDefinition(_ word: String) async -> Definition? {
        guard let hit = await datamuse("sp=\(word)&md=dpr&max=1").first,
              hit.word == word, let defs = hit.defs, !defs.isEmpty else { return nil }
        let parsed: [(pos: String, text: String)] = defs.compactMap { d in
            let parts = d.split(separator: "\t", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return (expand(parts[0]), parts[1].trimmingCharacters(in: .whitespaces))
        }
        guard let pos = parsed.first?.pos else { return nil }
        // Wiktionary has entries FOR misspellings ("ubiquitious → Misspelling of ubiquitous").
        // Those aren't words; bail out so the did-you-mean flow handles them.
        if parsed.allSatisfy({ $0.text.localizedCaseInsensitiveContains("misspelling of") }) { return nil }
        var senses = parsed.filter { $0.pos == pos && !$0.text.localizedCaseInsensitiveContains("misspelling of") }.map(\.text)
        let fresh = senses.filter { s in !staleLabels.contains { s.hasPrefix($0) } }
        if !fresh.isEmpty { senses = fresh }
        senses = senses.map(stripLabel)
        let pron = hit.tags?.first { $0.hasPrefix("pron:") }.flatMap { Arpabet.respell(String($0.dropFirst(5)).trimmingCharacters(in: .whitespaces)) }
        return Definition(word: word, partOfSpeech: pos, senses: senses,
                          example: nil, synonyms: [], simple: nil, respelling: pron)
    }

    /// "(literary) Having the colour of blood." → "Having the colour of blood."
    private static func stripLabel(_ s: String) -> String {
        guard s.hasPrefix("("), let close = s.firstIndex(of: ")") else { return s }
        let rest = s[s.index(after: close)...].trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? s : rest
    }

    private static func expand(_ abbr: String) -> String {
        switch abbr { case "n": "noun"; case "v": "verb"; case "adj": "adjective"; case "adv": "adverb"; case "u": "word"; default: abbr }
    }

    private static func dedupe(_ items: [String], dropping word: String) -> [String] {
        var out: [String] = []
        for s in items where s != word && !out.contains(s) { out.append(s) }
        return out
    }

    private static func datamuse(_ query: String) async -> [DMWord] {
        guard let url = URL(string: "https://api.datamuse.com/words?\(query)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let items = try? JSONDecoder().decode([DMWord].self, from: data) else { return [] }
        return items
    }

    // MARK: dictionaryapi.dev (example + synonyms, and fallback definitions)
    private enum Primary { case success(Definition), missing, unavailable, network }

    private static func primary(_ word: String) async -> Primary {
        guard let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word)") else { return .missing }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            switch (resp as? HTTPURLResponse)?.statusCode ?? 0 {
            case 200: break
            case 404: return .missing
            default:  return .unavailable
            }
            guard let e = try JSONDecoder().decode([Entry].self, from: data).first,
                  let m = e.meanings.first, !m.definitions.isEmpty else { return .unavailable }
            if m.definitions.allSatisfy({ $0.definition.localizedCaseInsensitiveContains("misspelling of") }) { return .missing }
            let syns = dedupe(m.synonyms + m.definitions.flatMap(\.synonyms), dropping: word)
            return .success(Definition(word: word, partOfSpeech: m.partOfSpeech,
                                       senses: m.definitions.map(\.definition),
                                       example: m.definitions.compactMap(\.example).first,
                                       synonyms: syns, simple: nil,
                                       audio: e.phonetics?.compactMap(\.audio).first { !$0.isEmpty }.flatMap(URL.init(string:))))
        } catch is URLError { return .network }
        catch { return .unavailable }
    }

    // API shapes
    private struct Entry: Decodable { var word: String; var meanings: [Meaning]; var phonetics: [Phonetic]? }
    private struct Phonetic: Decodable { var audio: String? }
    private struct Meaning: Decodable { var partOfSpeech: String; var definitions: [Def]; var synonyms: [String] }
    private struct Def: Decodable { var definition: String; var example: String?; var synonyms: [String] }
    private struct DMWord: Decodable { var word: String; var defs: [String]?; var tags: [String]? }
}
