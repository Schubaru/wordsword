import SwiftUI

/// Games: one row per game, and the words they've turned up. Word Wheel is the first.
struct GamesHubView: View {
    @Environment(Router.self) private var router
    @State private var save = WordWheelSave.load()
    @State private var linking = LinkingWordsSave.load()

    var body: some View {
        List {
            Section {
                row("Word Wheel", detail: "Level \(save.level) · \(save.coins) coins", icon: "a.circle", edge: .first) {
                    router.path.append(.wordWheel)
                }
                row("Linking words", detail: LinkingWords.cardDetail(linking), icon: "square.grid.2x2", edge: .last) {
                    router.path.append(.linkingWords)
                }
            } footer: {
                Text("Drag across a wheel of letters to spell words, or sort sixteen words into four groups that mean the same thing. Every word you find is one you can look up.")
            }
            Section {
                row("Words found", detail: "\(WordsFoundView.all().count)", icon: "text.badge.checkmark", edge: .only) {
                    router.path.append(.wordsFound)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .paperScreen("Games")
        .onAppear { save = WordWheelSave.load(); linking = LinkingWordsSave.load() }
    }

    private func row(_ title: String, detail: String, icon: String, edge: SheetRowEdge, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon).foregroundStyle(Color.ink)
                Spacer()
                Text(detail).font(.subheadline).foregroundStyle(Color.ink2)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.ink2)
            }
        }
        .sheetRowButton(edge)
    }
}

/// Every word found in a game, newest first. Tap one to define it.
struct WordsFoundView: View {
    @Environment(Router.self) private var router
    @State private var words = WordsFoundView.all()

    /// Both games' finds, newest first within each, without repeats.
    static func all() -> [String] {
        var seen = Set<String>()
        return (LinkingWordsSave.load().history + WordWheelSave.load().history).filter { seen.insert($0).inserted }
    }

    var body: some View {
        List {
            if words.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    KnightDoodle(pose: .idle, color: .ink, accent: .pen).frame(width: 56, height: 56)
                    Text("Words you find in a game land here, ready to look up.")
                        .foregroundStyle(Color.ink2)
                }
                .listRowBackground(Color.clear)
            }
            Section {
                ForEach(Array(words.enumerated()), id: \.element) { i, w in
                    Button { router.path.append(.define(w)) } label: {
                        HStack {
                            Text(w).font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Color.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.ink2)
                        }
                    }
                    .listRowSeparatorTint(Color.rule)
                    .sheetRowButton(i, of: words.count)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .paperScreen("Words found")
        .onAppear { words = Self.all() }
    }
}

/// Home's games, the first thing on the paper: a "Play with words" header written on a rule, then
/// one `GameCard` per game, full width, stacked. A new game is one more card here. The hub
/// (`GamesHubView`, with Words found) is hidden for now — the header is a plain label; make it a
/// button to `.games` to bring the hub back.
struct GamesEntry: View {
    let rule: CGFloat
    @Environment(Router.self) private var router
    @State private var save = WordWheelSave.load()
    @State private var linking = LinkingWordsSave.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Play with words").font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.ink)
                .onRule(2, spacing: rule)
                .accessibilityAddTraits(.isHeader)

            GameCard(title: "Word Wheel", detail: "Level \(save.level)", rule: rule) {
                WheelDoodle(color: .ink)
            } action: {
                router.path.append(.wordWheel)
            }
            GameCard(title: "Linking words", detail: LinkingWords.cardDetail(linking), rule: rule) {
                LinkDoodle(color: .ink, highlighter: .highlighter)
            } action: {
                router.path.append(.linkingWords)
            }
        }
        .onAppear { save = WordWheelSave.load(); linking = LinkingWordsSave.load() }
    }
}

/// One game on Home: its doodle, its name, where you are in it. Every game wears this card, so
/// "the white card with a drawing is a game" is learned once. It's a sheet lying on the paper —
/// `sheet` fill, the 1pt `rule` edge, a soft lift — three rules tall with its bottom edge resting on
/// a rule, so it sits on the grid the way the word of the day does.
struct GameCard<Doodle: View>: View {
    let title: String
    let detail: String
    let rule: CGFloat
    @ViewBuilder var doodle: Doodle
    let action: () -> Void
    @ScaledMetric(relativeTo: .headline) private var mark: CGFloat = 48

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        Button(action: action) {
            HStack(spacing: 14) {
                doodle.frame(width: mark, height: mark)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(.headline, design: .rounded)).foregroundStyle(Color.ink)
                    Text(detail).font(.subheadline).foregroundStyle(Color.ink2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.ink2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 3 * rule - 10)
            .background(shape.fill(Color.sheet))
            .overlay(shape.strokeBorder(Color.rule, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(SurfacePressStyle(shape: shape))
        .shadow(color: .shadow, radius: 16, y: 6)
        // The card lies on the paper with its bottom edge on a rule; the 10pt above it is the gap
        // under whatever was written on the line before.
        .frame(minHeight: 3 * rule, alignment: .bottom)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityHint("Opens the game")
    }
}
