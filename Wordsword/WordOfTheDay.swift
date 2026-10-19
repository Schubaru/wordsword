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
        if let kept = kept(word) { return kept }
        guard case .found(let d) = await Dictionary.lookup(word) else { return nil }
        let m = await Simplifier.simplify(d)
        UserDefaults.standard.set(m, forKey: "wotd.meaning.\(word)")
        return m
    }

    /// The sentence already fetched for this word, if any. Preferred over the library's one-liner,
    /// which is whatever Define first showed and can be a raw dictionary sense.
    static func kept(_ word: String) -> String? { UserDefaults.standard.string(forKey: "wotd.meaning.\(word)") }

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

/// Word of the day, as a quiet banner floating at the top of Home: the word, how it's said, what it
/// means. A tap anywhere looks it up the way a typed word is looked up; the speaker says it; the ✕ —
/// or a flick up — puts it away until tomorrow's word. It's a sheet lying over the page: `sheet`
/// fill, the 1pt `rule` edge, and a two-layer shadow (a tight contact edge, a soft lift) so it reads
/// as floating rather than printed.
struct WordOfTheDayBanner: View {
    let word: String
    /// The library's one-liner, when this word has been looked up before — no fetch needed.
    let known: String?
    let open: () -> Void
    let dismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fetched: String?
    @State private var missing = false
    @State private var pron: Pronunciation?
    @State private var pronLooked = false
    @State private var lift: CGFloat = 0
    @State private var speaker = Speaker.shared
    /// Room the word's line leaves for the two icons in the corner; the meaning runs full width under them.
    @ScaledMetric(relativeTo: .body) private var iconRoom: CGFloat = 64

    private var meaning: String? { fetched ?? WordOfTheDay.kept(word) ?? known }
    private var respelling: String? { Pronunciation.worthShowing(pron?.respelling, for: word) }
    private var playing: Bool { speaker.speaking == word }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        Button(action: open) {
            VStack(alignment: .leading, spacing: 2) {
                Text(word)
                    .font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.trailing, iconRoom)
                // The line is held while the respelling is on its way, so the banner doesn't grow
                // under the finger; it only closes up when there's nothing worth showing.
                if respelling != nil || !pronLooked {
                    Text(respelling ?? " ").font(.pron).foregroundStyle(Color.ink2)
                }
                Text(meaning ?? (missing ? "Tap to find out what it means." : " "))
                    .font(.system(.subheadline, design: .serif)).foregroundStyle(Color.ink2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(shape.fill(Color.sheet))
            .overlay(shape.strokeBorder(Color.rule, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(SurfacePressStyle(shape: shape))
        .accessibilityLabel("Word of the day: \(word)" + (respelling.map { ", pronounced \($0)" } ?? "") + (meaning.map { ". \($0)" } ?? ""))
        .accessibilityHint("Looks it up")
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 0) {
                icon(playing ? "speaker.wave.2.fill" : "speaker.wave.2", "Hear \(word)", tint: playing ? .pen : .ink2) {
                    speaker.say(word, recording: pron?.audio)
                }
                icon("xmark", "Dismiss word of the day", tint: .ink2, action: dismiss)
            }
            .padding(.top, 4).padding(.trailing, 4)
            .animation(Motion.feedback, value: playing)
        }
        .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        .shadow(color: .shadow, radius: 20, y: 8)
        .offset(y: lift)
        // A flick up puts it away, the way a notification goes. Down does nothing: there's nowhere to go.
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .onChanged { v in lift = min(0, v.translation.height) }
                .onEnded { v in
                    if v.predictedEndTranslation.height < -40 { dismiss() }
                    else { withAnimation(reduceMotion ? nil : Motion.sheet) { lift = 0 } }
                }
        )
        .task(id: word) {
            async let p = Dictionary.pronunciation(for: word, within: 4)
            if known == nil {
                let m = await WordOfTheDay.meaning(of: word)
                withAnimation(Motion.reveal) { fetched = m; missing = m == nil }
            }
            let got = await p
            withAnimation(Motion.reveal) { pron = got; pronLooked = true }
            speaker.prefetch(got?.audio)
        }
    }

    private func icon(_ name: String, _ label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.subheadline.weight(.semibold)).foregroundStyle(tint)
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}
