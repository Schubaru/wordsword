import SwiftUI
import WidgetKit

// Home Screen widgets. Each one is a scrap of the app's paper — college rules, the red margin, ink —
// and a tap that lands somewhere specific: the search with the keyboard up, a game, or the word of
// the day's definition. Every link is handled by `onOpenURL` in WordswordApp.swift.
//
// Shared with the app target: Theme.swift (tokens), Doodles.swift (the knight, the game doodles,
// Paper) and WordOfTheDaySchedule.swift (the day's word, and the meanings the app wrote ahead).

@main
struct WordswordWidgets: WidgetBundle {
    var body: some Widget {
        SearchWidget()
        WordOfTheDayWidget()
        HaikluWidget()
        LinkingWordsWidget()
        PlexiconWidget()
        WordWheelWidget()
    }
}

// MARK: - Links

enum WidgetLink {
    static let search = URL(string: "wordsword://define")!
    static func define(_ word: String) -> URL {
        var c = URLComponents(string: "wordsword://define")!
        c.queryItems = [URLQueryItem(name: "word", value: word)]
        return c.url!
    }
    /// The `game` names are `Route(game:)`'s.
    static func play(_ game: String) -> URL { URL(string: "wordsword://play?game=\(game)")! }
}

// MARK: - The paper

/// The ruled paper behind every widget, phased from the bottom: the last rule sits `bottom` above the
/// widget's lower edge and the rest stack up from it. The writing is laid out bottom-up on the same
/// grid, so it lands on the rules whatever height the widget is on this phone.
private struct WidgetPaper: View {
    let rule: CGFloat
    var body: some View {
        GeometryReader { g in
            let firstRule = (g.size.height - WidgetLayout.bottom).truncatingRemainder(dividingBy: rule)
            Paper(page: .page, rule: .paperRule, margin: .margin, spacing: rule,
                  topInset: firstRule - rule, fillsSafeArea: false)
        }
    }
}

private enum WidgetLayout {
    /// The last rule's distance from the bottom edge: room for descenders and the corner's curve.
    static let bottom: CGFloat = 16
    /// Writing starts past the red margin (x = 14), never on it.
    static let leading: CGFloat = 26
    static let trailing: CGFloat = 14
}

/// What every widget's view sits in: the paper behind, the content laid out on its grid.
private struct OnPaper<Content: View>: View {
    let rule: CGFloat
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(.leading, WidgetLayout.leading)
            .padding(.trailing, WidgetLayout.trailing)
            .padding(.bottom, WidgetLayout.bottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .containerBackground(for: .widget) { WidgetPaper(rule: rule) }
    }
}

/// The launchers never change, so their timeline is one entry, forever.
struct StillProvider: TimelineProvider {
    struct Entry: TimelineEntry { let date: Date }
    func placeholder(in context: Context) -> Entry { Entry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

// MARK: - Search (small)

/// The knight, and the search field as it looks on Home. A tap opens Home with the field focused.
struct SearchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Search", provider: StillProvider()) { _ in SearchWidgetView() }
            .configurationDisplayName("Look up a word")
            .description("Opens wordsword with the keyboard up.")
            .supportedFamilies([.systemSmall])
            .contentMarginsDisabled()
    }
}

struct SearchWidgetView: View {
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var knight: CGFloat = 60

    var body: some View {
        OnPaper(rule: rule) {
            VStack(alignment: .leading, spacing: 0) {
                KnightDoodle(color: .ink, accent: .pen)
                    .frame(width: knight, height: knight)
                    .padding(.top, 14)
                Spacer(minLength: 8)
                // The field lies on the paper with its bottom edge on the last rule, like a card.
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.ink2)
                    Text("type a word").foregroundStyle(Color.ink2.opacity(0.8))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .font(.callout)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: rule + 12, alignment: .leading)
                .background {
                    Capsule().fill(Color.sheet).overlay { Capsule().strokeBorder(Color.rule, lineWidth: 1) }
                }
                // Outdent a little: the capsule's curve, not its text, meets the margin's side.
                .padding(.leading, -4)
            }
        }
        .widgetURL(WidgetLink.search)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Look up a word")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Word of the day (medium)

struct WordOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WordOfTheDay", provider: DayProvider()) { WordOfTheDayWidgetView(entry: $0) }
            .configurationDisplayName("Word of the day")
            .description("Today's word and what it means. Tap to look it up.")
            .supportedFamilies([.systemMedium])
            .contentMarginsDisabled()
    }
}

/// One entry per midnight for the week ahead — as far as the app has written meanings. The app
/// reloads this whenever it writes more (`WordOfTheDay.shareWeek()`).
struct DayProvider: TimelineProvider {
    struct Entry: TimelineEntry {
        let date: Date
        let word: String
        let meaning: String?
    }

    private func entry(on date: Date) -> Entry {
        let word = WordOfTheDay.word(on: date)
        return Entry(date: date, word: word, meaning: WidgetShare.meaning(of: word))
    }

    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, word: "ephemeral", meaning: "Lasting for a very short time.")
    }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let today = entry(on: .now)
        // The gallery shows a word with its meaning, even before the app has written one.
        completion(context.isPreview && today.meaning == nil ? placeholder(in: context) : today)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        completion(Timeline(entries: days.map(entry(on:)), policy: .atEnd))
    }
}

/// The banner from Home, written straight onto the paper: the word in rounded bold on its own two
/// rules, the meaning in Define's serif on the two under it. No label, no date — like the banner.
struct WordOfTheDayWidgetView: View {
    let entry: DayProvider.Entry
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28
    /// The serif body's own line height; the gap to the next rule is added as line spacing, so a
    /// meaning that wraps writes its second line on the next rule too.
    @ScaledMetric(relativeTo: .body) private var bodyLine: CGFloat = 22

    private var meaning: String { entry.meaning ?? "Tap to find out what it means." }

    var body: some View {
        OnPaper(rule: rule) {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.word)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .onRule(2, spacing: rule)
                // Hung from its first baseline, so a one-line meaning sits on the rule right under the
                // word instead of dropping to the lower one.
                Text(meaning)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color.ink2)
                    .lineSpacing(max(0, rule - bodyLine))
                    .lineLimit(2)
                    .alignmentGuide(.top) { $0[.firstTextBaseline] - rule }
                    .frame(maxWidth: .infinity, minHeight: 2 * rule, maxHeight: 2 * rule, alignment: .topLeading)
            }
            // One empty rule under the writing, so the block sits in the middle of the widget
            // rather than on its floor.
            .padding(.bottom, rule)
        }
        .widgetURL(WidgetLink.define(entry.word))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Word of the day: \(entry.word). \(meaning)")
        .accessibilityHint("Looks it up")
    }
}

// MARK: - Games (small)

/// One game: its doodle from Home's game card, and its name written on the last rule.
private struct GameWidgetView<Doodle: View>: View {
    let name: String
    @ViewBuilder var doodle: Doodle
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var mark: CGFloat = 60

    var body: some View {
        OnPaper(rule: rule) {
            VStack(alignment: .leading, spacing: 0) {
                doodle.frame(width: mark, height: mark).padding(.top, 14)
                Spacer(minLength: 8)
                Text(name)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .onRule(1, spacing: rule)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityHint("Opens the game")
    }
}

private func gameWidget<Doodle: View>(kind: String, name: String, game: String,
                                      @ViewBuilder doodle: @escaping () -> Doodle) -> some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StillProvider()) { _ in
        GameWidgetView(name: name, doodle: doodle).widgetURL(WidgetLink.play(game))
    }
    .configurationDisplayName(name)
    // A plain String: an interpolated literal becomes a localized format, which WidgetKit traps on.
    .description("Opens " + name + ".")
    .supportedFamilies([.systemSmall])
    .contentMarginsDisabled()
}

struct HaikluWidget: Widget {
    var body: some WidgetConfiguration {
        gameWidget(kind: "Haiklu", name: "Haiklu", game: "haiklu") {
            HaikuDoodle(color: .ink, accent: .highlighterPink)
        }
    }
}

struct LinkingWordsWidget: Widget {
    var body: some WidgetConfiguration {
        gameWidget(kind: "LinkingWords", name: "Linking words", game: "linking-words") {
            LinkDoodle(color: .ink, highlighter: .highlighter)
        }
    }
}

struct PlexiconWidget: Widget {
    var body: some WidgetConfiguration {
        gameWidget(kind: "Plexicon", name: "Plexicon", game: "plexicon") {
            PlexDoodle(color: .ink, accent: .highlighterGreen, hint: .highlighter)
        }
    }
}

struct WordWheelWidget: Widget {
    var body: some WidgetConfiguration {
        gameWidget(kind: "WordWheel", name: "Word Wheel", game: "word-wheel") {
            WheelDoodle(color: .ink)
        }
    }
}

// MARK: - Previews

#Preview("Search", as: .systemSmall) { SearchWidget() } timeline: { StillProvider.Entry(date: .now) }
#Preview("Plexicon", as: .systemSmall) { PlexiconWidget() } timeline: { StillProvider.Entry(date: .now) }
#Preview("Word of the day", as: .systemMedium) { WordOfTheDayWidget() } timeline: {
    DayProvider.Entry(date: .now, word: "ephemeral", meaning: "Lasting for a very short time.")
}
