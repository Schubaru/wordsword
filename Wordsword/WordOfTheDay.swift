import SwiftUI

/// Curated, reader-flavored. Cycles by day of year. Edit freely — order is the schedule.
enum WordOfTheDay {
    static var today: String {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return words[(day - 1) % words.count]
    }

    /// The one-line meaning written under the word on Home: wordsword's own sentence, the same one
    /// Define would show. Fetched once per word and kept, so Home never waits on it twice.
    static func meaning(of word: String) async -> String? {
        let key = "wotd.meaning.\(word)"
        if let kept = UserDefaults.standard.string(forKey: key) { return kept }
        guard case .found(let d) = await Dictionary.lookup(word) else { return nil }
        let m = await Simplifier.simplify(d)
        UserDefaults.standard.set(m, forKey: key)
        return m
    }

    static let words = [
        "ephemeral", "sanguine", "laconic", "ineffable", "mellifluous", "petrichor", "sonder", "liminal",
        "halcyon", "vestige", "penumbra", "quixotic", "serendipity", "taciturn", "verdant", "wistful",
        "zephyr", "ebullient", "gossamer", "insouciant", "languid", "luminous", "nascent", "obfuscate",
        "palimpsest", "querulous", "reticent", "sonorous", "tenuous", "ubiquitous", "vicarious", "winsome",
        "aberration", "bucolic", "cacophony", "denouement", "elegy", "furtive", "garrulous", "hubris",
        "iconoclast", "juxtapose", "kismet", "lugubrious", "maudlin", "nebulous", "ostensible", "pernicious",
        "quiescent", "raconteur", "surreptitious", "trepidation", "umbrage", "vociferous", "wanton", "yearn",
        "abscond", "belie", "capricious", "diaphanous", "equanimity", "fastidious", "grandiloquent", "harbinger",
        "idyllic", "jejune", "kaleidoscopic", "lachrymose", "mercurial", "nonchalant", "opulent", "perfunctory",
        "quotidian", "recalcitrant", "sagacious", "torpid", "unctuous", "verisimilitude", "wry", "zeitgeist",
        "acumen", "bombastic", "candor", "desultory", "ennui", "fecund", "gregarious", "histrionic",
        "impetuous", "jocular", "kinetic", "lithe", "moribund", "noisome", "obsequious", "paucity",
        "quandary", "ruminate", "somnolent", "truculent", "usurp", "vapid", "wizened", "abstruse",
        "beguile", "circumspect", "dilatory", "effervescent", "florid", "gambol", "hapless", "impunity",
        "labyrinthine", "melancholy", "nefarious", "oblique", "propitious", "redolent", "sublime", "temerity",
        "unfettered", "voracious", "waft", "ardent", "brusque", "cloying", "doleful", "enigmatic",
    ]
}

/// Word of the day, written on Home's paper the way a headword is written in a notebook: a quiet
/// line saying what it is, the word itself in the headword's hand with the pen underline the
/// wordmark wears, and what it means in Define's serif. No container — it's ink on the page; the
/// cards below it are the games. Three rows of the grid: label (1 rule), word (2), meaning (2).
///
/// `written` false means today's word hasn't been put on the page yet. Flipping it to true writes
/// it: the slash cuts the word in, the underline draws, the meaning comes up under it. Home flips it
/// once a day, the first time the paper is actually in view, and swings the knight with it.
struct WordOfTheDayEntry: View {
    let word: String
    /// The library's one-liner, when this word has been looked up before — no fetch needed.
    let known: String?
    let rule: CGFloat
    let written: Bool
    let action: () -> Void

    @State private var cut: CGFloat
    @State private var ink: CGFloat
    @State private var settled: Bool
    @State private var fetched: String?
    @State private var missing = false

    init(word: String, known: String?, rule: CGFloat, written: Bool, action: @escaping () -> Void) {
        self.word = word; self.known = known; self.rule = rule; self.written = written; self.action = action
        _cut = State(initialValue: written ? 1 : 0)
        _ink = State(initialValue: written ? 1 : 0)
        _settled = State(initialValue: written)
    }

    private var meaning: String? { known ?? fetched }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Word of the day · \(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                    .font(.footnote).foregroundStyle(Color.ink2)
                    .onRule(1, spacing: rule)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(word)
                        .font(.headword).foregroundStyle(Color.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .slashReveal(cut, edge: .pen)
                        .overlay(alignment: .bottom) {
                            DoodleStroke(progress: ink)
                                .stroke(Color.pen, style: .init(lineWidth: 2.5, lineCap: .round))
                                .frame(height: 8).offset(y: 3)
                        }
                    Spacer(minLength: 0)
                    Text(Image(systemName: "chevron.right"))
                        .font(.title3.weight(.semibold)).foregroundStyle(Color.ink2)
                        .opacity(settled ? 1 : 0)
                }
                .onRule(2, spacing: rule)
                meaningLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Word of the day: \(word)" + (meaning.map { ". \($0)" } ?? ""))
        .accessibilityHint("Opens its definition")
        .accessibilityAddTraits(.isButton)
        .task(id: word) {
            guard known == nil else { return }
            fetched = await WordOfTheDay.meaning(of: word)
            missing = fetched == nil
        }
        .onChange(of: written) { _, w in if w { write() } }
    }

    /// Two lines of Define's serif, each written on a rule: the leading is opened up until one line
    /// is exactly one rule, and the first baseline is put on the first rule under the word. Offline,
    /// it says what the tap will do instead — the line is never left blank.
    private var meaningLine: some View {
        let font = UIFont.preferredFont(forTextStyle: .callout)
        let serif = UIFont(descriptor: font.fontDescriptor.withDesign(.serif) ?? font.fontDescriptor, size: 0)
        return Text(meaning ?? (missing ? "Tap to find out what it means." : " "))
            .font(.system(.callout, design: .serif)).foregroundStyle(Color.ink2)
            .lineSpacing(max(0, rule - serif.lineHeight))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            // Padding, not a `.top` alignment guide: an explicit top guide leaks up to Home's
            // top-aligned ZStack and shifts the paper out from under the writing.
            .padding(.top, max(0, rule - serif.ascender))
            .frame(maxWidth: .infinity, minHeight: 2 * rule, alignment: .topLeading)
            .opacity(settled ? 1 : 0)
            .offset(y: settled ? 0 : 6)
            .animation(Motion.reveal, value: meaning)
    }

    /// The cut, then the pen goes under it, then the meaning comes up — Define's arrival in miniature.
    private func write() {
        cut = 0; ink = 0; settled = false
        withAnimation(Motion.slash) { cut = 1 }
        withAnimation(.easeOut(duration: 0.35).delay(0.3)) { ink = 1 }
        withAnimation(Motion.reveal.delay(0.5)) { settled = true }
    }
}
