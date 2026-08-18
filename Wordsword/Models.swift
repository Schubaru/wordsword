import Foundation
import SwiftData

/// A word the user has looked up. Every lookup lands here ("All").
@Model final class Word {
    @Attribute(.unique) var text: String
    var partOfSpeech: String
    var definition: String        // the simple, one-sentence version shown in chat
    var rawDefinition: String     // the dictionary's own wording
    var example: String?
    var createdAt: Date
    var lastLookedUp: Date
    var lookupCount: Int

    // Spaced repetition (SM-2 lite)
    var dueAt: Date
    var intervalDays: Int
    var ease: Double

    @Relationship(inverse: \Tag.words) var tags: [Tag]
    var wordlists: [Wordlist]

    init(text: String, partOfSpeech: String, definition: String, rawDefinition: String, example: String?) {
        self.text = text
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.rawDefinition = rawDefinition
        self.example = example
        let now = Date()
        createdAt = now; lastLookedUp = now; lookupCount = 1
        dueAt = now; intervalDays = 0; ease = 2.5
        tags = []; wordlists = []
    }

    /// Tags are the extensible metadata system. `kind` is an open string:
    /// "pos", "synonym" today; "antonym", "origin", "book" tomorrow — no schema change.
    func tags(_ kind: String) -> [String] { tags.filter { $0.kind == kind }.map(\.value) }
    var synonyms: [String] { tags("synonym") }

    func addTag(_ kind: String, _ value: String, in context: ModelContext) {
        guard !tags.contains(where: { $0.kind == kind && $0.value == value }) else { return }
        tags.append(Tag.fetchOrCreate(kind: kind, value: value, in: context))
    }

    // MARK: spaced repetition
    func review(knewIt: Bool) {
        if knewIt {
            intervalDays = intervalDays == 0 ? 1 : Int((Double(intervalDays) * ease).rounded())
            ease = min(2.8, ease + 0.1)
        } else {
            intervalDays = 0
            ease = max(1.3, ease - 0.2)
        }
        dueAt = Calendar.current.date(byAdding: .day, value: max(intervalDays, knewIt ? 1 : 0), to: Date()) ?? Date()
    }

    static func find(_ text: String, in context: ModelContext) -> Word? {
        let t = text.lowercased()
        var d = FetchDescriptor<Word>(predicate: #Predicate { $0.text == t })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }
}

@Model final class Tag {
    var kind: String
    var value: String
    var words: [Word]

    init(kind: String, value: String) { self.kind = kind; self.value = value; words = [] }

    static func fetchOrCreate(kind: String, value: String, in context: ModelContext) -> Tag {
        var d = FetchDescriptor<Tag>(predicate: #Predicate { $0.kind == kind && $0.value == value })
        d.fetchLimit = 1
        if let t = try? context.fetch(d).first { return t }
        let t = Tag(kind: kind, value: value)
        context.insert(t)
        return t
    }
}

/// A playlist, but for words.
@Model final class Wordlist {
    var name: String
    var createdAt: Date
    @Relationship(inverse: \Word.wordlists) var words: [Word]

    init(name: String) { self.name = name; createdAt = Date(); words = [] }
}
