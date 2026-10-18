import SwiftUI

/// Games: one row per game, and the words they've turned up. Word Wheel is the first.
struct GamesHubView: View {
    @Environment(Router.self) private var router
    @State private var save = WordWheelSave.load()

    var body: some View {
        List {
            Section {
                row("Word Wheel", detail: "Level \(save.level) · \(save.coins) coins", icon: "a.circle", edge: .only) {
                    router.path.append(.wordWheel)
                }
            } footer: {
                Text("Drag across a wheel of letters to spell words. Every word you find is one you can look up.")
            }
            Section {
                row("Words found", detail: "\(save.history.count)", icon: "text.badge.checkmark", edge: .only) {
                    router.path.append(.wordsFound)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .paperScreen("Games")
        .onAppear { save = WordWheelSave.load() }
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
    @State private var words = WordWheelSave.load().history

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
        .onAppear { words = WordWheelSave.load().history }
    }
}

/// Home's games: a "Games" line written on the paper — it opens the hub, where Words found lives —
/// then one `GameCard` per game, full width, stacked. A new game is one more card here.
struct GamesEntry: View {
    let rule: CGFloat
    @Environment(Router.self) private var router
    @State private var save = WordWheelSave.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { router.path.append(.games) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Games").font(.footnote.weight(.medium))
                    Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                }
                .foregroundStyle(Color.ink2)
                .onRule(2, spacing: rule)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("All games")

            GameCard(title: "Word Wheel", detail: "Level \(save.level)", rule: rule) {
                WheelDoodle(color: .ink)
            } action: {
                router.path.append(.wordWheel)
            }
        }
        .onAppear { save = WordWheelSave.load() }
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
