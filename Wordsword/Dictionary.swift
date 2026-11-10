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

        // All four requests go out at once; the synonyms are ranked once the sense they sit under is known.
        async let primaryTask = primary(word)
        async let candidatesTask = synonymCandidates(word)
        let dm = await datamuseDefinition(word)
        let p = await primaryTask

        if var d = dm {
            if case .success(let rich) = p {
                if rich.partOfSpeech == d.partOfSpeech { d.example = d.example ?? rich.example }
                d.audio = rich.audio
            }
            d.synonyms = rank(await candidatesTask, for: word, sense: d.senses.first ?? "", pos: d.partOfSpeech)
            return .found(d)
        }
        switch p {
        case .success(var d):
            let ranked = rank(await candidatesTask, for: word, sense: d.senses.first ?? "", pos: d.partOfSpeech)
            if !ranked.isEmpty { d.synonyms = ranked }
            return .found(d)
        case .network: return .offline
        case .missing, .unavailable:
            let s = await suggestions(for: word).filter { $0 != word }
            return s.isEmpty ? .notFound : .suggestions(s)
        }
    }

    /// Words saved before pronunciation existed have none. Fill it in on their next lookup — but
    /// never make the user wait on the network for a word that is meant to open instantly and offline.
    static func pronunciation(for word: String, within seconds: Double = 2) async -> Pronunciation? {
        guard let d = await refresh(word, within: seconds), let r = d.respelling else { return nil }
        return Pronunciation(respelling: r, audio: d.audio)
    }

    /// A fresh lookup for a word already in the library, or nil if it takes longer than `seconds`.
    static func refresh(_ word: String, within seconds: Double = 2) async -> Definition? {
        await withTaskGroup(of: Definition?.self) { g in
            g.addTask { if case .found(let d) = await lookup(word) { return d }; return nil }
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

    // MARK: Synonyms, ranked against the sense on screen
    struct Candidate {
        var word: String
        var defs: [(pos: String, text: String)]
        var common: Bool        // 1+ uses per million: a word a reader will actually know
        var isSynonym: Bool     // Datamuse rel_syn (WordNet synonyms) rather than merely "means like"
    }

    /// Datamuse's synonyms mix every sense of a word, and its "means like" list is looser still. Both come
    /// back with their own definitions (`md=d`), which is what lets `rank` check them against ours.
    private static func synonymCandidates(_ word: String) async -> [Candidate] {
        async let syn = datamuse("rel_syn=\(word)&md=dpf&max=30")
        async let near = datamuse("ml=\(word)&md=dpf&max=40")
        func cands(_ xs: [DMWord], _ isSynonym: Bool) -> [Candidate] {
            xs.map { x in
                let f = x.tags?.first { $0.hasPrefix("f:") }.flatMap { Double($0.dropFirst(2)) } ?? 0
                return Candidate(word: x.word, defs: (x.defs ?? []).compactMap(parseDef), common: f >= 1, isSynonym: isSynonym)
            }
        }
        return cands(await syn, true) + cands(await near, false)
    }

    /// Best first. A candidate only counts if one of its meanings in the same part of speech shares a
    /// content word with the definition on screen — that's what keeps "compound" (a botany sense of the
    /// adjective) off the noun "cleft". Then: everyday words before rare ones, true synonyms before
    /// related words, more shared words first, Datamuse's own order last.
    static func rank(_ cs: [Candidate], for word: String, sense: String, pos: String) -> [String] {
        let target = stems(sense).subtracting([String(word.prefix(4))])
        let senseWords = tokens(sense)
        var seen: Set<String> = [word]
        var scored: [(word: String, common: Bool, isSynonym: Bool, overlap: Int, order: Int)] = []
        for (i, c) in cs.enumerated() where !c.word.contains(" ") && seen.insert(c.word).inserted {
            let same = c.defs.filter { $0.pos == pos }.map(\.text)
            guard let best = same.map({ stems($0).intersection(target).count + (tokens($0).contains(word) ? 2 : 0) }).max() else { continue }
            let overlap = best + (senseWords.contains(c.word) ? 2 : 0)
            guard overlap > 0, c.isSynonym || c.common else { continue }
            scored.append((c.word, c.common, c.isSynonym, overlap, i))
        }
        return scored.sorted {
            if $0.common != $1.common { return $0.common }
            if $0.isSynonym != $1.isSynonym { return $0.isSynonym }
            if $0.overlap != $1.overlap { return $0.overlap > $1.overlap }
            return $0.order < $1.order
        }.map(\.word)
    }

    private static let filler: Set<String> = ["pertaining", "relating", "especially", "something", "someone", "having",
        "being", "which", "that", "with", "from", "into", "than", "their", "other", "more", "about", "very", "such", "used",
        "made", "make", "makes", "making", "form", "kind", "thing", "things", "person", "people", "state", "quality",
        "also", "often", "usually", "typically", "like", "done", "small", "large", "process"]
    private static func tokens(_ s: String) -> [String] { s.lowercased().split { !$0.isLetter }.map(String.init) }
    /// ponytail: a 4-letter prefix is the whole stemmer ("split" ~ "splitting", "open" ~ "opening"); swap in
    /// NLTagger lemmas if near-misses ("inde"ntation ~ "inde"pendent) start ranking junk.
    private static func stems(_ s: String) -> Set<String> {
        Set(tokens(s).filter { $0.count >= 4 && !filler.contains($0) }.map { String($0.prefix(4)) })
    }

    #if DEBUG
    /// Pins the "cleft" case: the noun's chips must not include the botany adjective's "compound".
    static func selfCheck() {
        let cs = [
            Candidate(word: "crack", defs: [("verb", "To form cracks."), ("noun", "A thin and usually jagged space opened in a previously solid material.")], common: true, isSynonym: true),
            Candidate(word: "fissure", defs: [("noun", "A long, narrow crack or opening made by breaking or splitting.")], common: true, isSynonym: true),
            Candidate(word: "compound", defs: [("noun", "Anything made by combining several things."), ("adjective", "Composed of elements; not simple.")], common: true, isSynonym: true),
            Candidate(word: "divided", defs: [("adjective", "Separated or split into pieces.")], common: true, isSynonym: true),
            Candidate(word: "scissure", defs: [("noun", "A longitudinal opening made by cutting; a cleft; a fissure.")], common: false, isSynonym: true),
            Candidate(word: "crew", defs: [("noun", "A group of people working together.")], common: true, isSynonym: false),
        ]
        let r = rank(cs, for: "cleft", sense: "An opening, fissure, or V-shaped indentation made by or as if by splitting.", pos: "noun")
        assert(r == ["fissure", "crack", "scissure"], "synonym ranking: \(r)")
    }
    #endif

    /// The rarest of these words, with its first sense trimmed to one clause — the word a
    /// definition hinges on ("ulna" inside "of or pertaining to the ulna"). Nil when they're all everyday words.
    static func rarestGloss(in words: [String]) async -> (word: String, sense: String)? {
        await withTaskGroup(of: (word: String, f: Double, sense: String)?.self) { g in
            for w in words {
                g.addTask {
                    guard let hit = await datamuse("sp=\(w)&md=df&max=1").first, hit.word == w,
                          let def = hit.defs?.first?.split(separator: "\t", maxSplits: 1).last,
                          let f = hit.tags?.first(where: { $0.hasPrefix("f:") }).flatMap({ Double($0.dropFirst(2)) }),
                          f < 5 else { return nil }   // ponytail: f = uses per million; under 5 is "you might not know this one"
                    var s = stripLabel(String(def).trimmingCharacters(in: .whitespaces))
                    if let r = s.range(of: ". ") { s = String(s[..<r.lowerBound]) }
                    if s.count > 90, let r = s.range(of: ", ") { s = String(s[..<r.lowerBound]) }
                    return (w, f, s.trimmingCharacters(in: CharacterSet(charactersIn: " .")) + ".")
                }
            }
            var best: (word: String, f: Double, sense: String)?
            for await r in g { if let r, r.f < best?.f ?? .infinity { best = r } }
            return best.map { ($0.word, $0.sense) }
        }
    }

    private static let staleLabels = ["(obsolete", "(archaic", "(dated", "(rare"]

    private static func datamuseDefinition(_ word: String) async -> Definition? {
        guard let hit = await datamuse("sp=\(word)&md=dpr&max=1").first,
              hit.word == word, let defs = hit.defs, !defs.isEmpty else { return nil }
        let parsed = defs.compactMap(parseDef)
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

    /// Datamuse's "n\tAn opening…" → ("noun", "An opening…").
    private static func parseDef(_ d: String) -> (pos: String, text: String)? {
        let parts = d.split(separator: "\t", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return (expand(parts[0]), parts[1].trimmingCharacters(in: .whitespaces))
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

    /// URLSession's default is 60s per request — a minute of jabbing knight whenever dictionaryapi.dev hangs.
    private static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 5
        return URLSession(configuration: c)
    }()

    private static func datamuse(_ query: String) async -> [DMWord] {
        // Encoded so phrases ("ad hoc") and accents ("café") don't make the URL nil and read as "not found".
        guard let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.datamuse.com/words?\(q)"),
              let (data, _) = try? await session.data(from: url),
              let items = try? JSONDecoder().decode([DMWord].self, from: data) else { return [] }
        return items
    }

    // MARK: dictionaryapi.dev (example + synonyms, and fallback definitions)
    private enum Primary { case success(Definition), missing, unavailable, network }

    private static func primary(_ word: String) async -> Primary {
        guard let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word)") else { return .missing }
        do {
            let (data, resp) = try await session.data(from: url)
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
