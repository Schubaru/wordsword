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

/// Home's one line about games: a pen-wash scrap written on the paper in the same hand as the word
/// of the day — label in ink-2, the thing itself in rounded ink — two rules tall with the chip on
/// the lower one, so the 44pt target grows up into blank page instead of lifting it off the line.
struct GamesEntry: View {
    let rule: CGFloat
    @Environment(Router.self) private var router
    @State private var save = WordWheelSave.load()

    var body: some View {
        Button { router.path.append(.games) } label: {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 7) { label; detail }
                VStack(alignment: .leading, spacing: 3) { label; detail }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.penWash))
            .frame(height: 2 * rule, alignment: .bottom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Games: Word Wheel, level \(save.level)")
        .onAppear { save = WordWheelSave.load() }
    }

    private var label: some View { Text("Games").font(.footnote).foregroundStyle(Color.ink2) }
    private var detail: some View {
        Text("Word Wheel, level \(save.level)")
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.ink)
    }
}
