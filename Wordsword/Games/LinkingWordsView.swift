import SwiftUI

/// Today's Linking words: sixteen word tiles on the paper, four groups to find, four strikes.
/// The game lives in `LinkingWords`; this screen draws it and reacts to it. A solved group becomes
/// a strip with a highlighter swept across it — the one colour on the page, and it marks a find.
struct LinkingWordsView: View {
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28
    @State private var game = LinkingWords()

    @State private var beat = 0
    @State private var beatKind = SensoryFeedback.success
    @State private var reaction: KnightPose = .idle
    @State private var shake: CGFloat = 0
    /// Tiles mid-hop on Submit.
    @State private var hopping: Set<String> = []
    /// Strips that were already on the board when the screen opened draw themselves in no time.
    @State private var drawn = 0
    @State private var showResults = false
    @State private var showRules = false
    /// Measured tile width, so at accessibility sizes one font size can be fitted to the longest word.
    @State private var tileWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            if game.puzzle != nil {
                ScrollView {
                    VStack(spacing: 0) {
                        captionRow
                        board.padding(.top, 10)
                        mistakesRow.padding(.top, 14)
                        controls.padding(.top, 14).padding(.bottom, 24)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollBounceBehavior(.basedOnSize)
                .allowsHitTesting(!showResults)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperScreen("Linking words") { trailing }
        .overlay(alignment: .bottom) { if showResults { results } }
        .animation(reduceMotion ? nil : Motion.reveal, value: showResults)
        .sheet(isPresented: $showRules) { HowToPlaySheet() }
        .task {
            await game.load()
            drawn = game.solved.count
            if !game.save.rulesSeen { showRules = true; game.markRulesSeen() }
        }
        .sensoryFeedback(trigger: beat) { _, _ in beatKind }
        .sensoryFeedback(trigger: game.selected.count) { old, new in new > old ? .selection : nil }
        .onChange(of: game.flash?.id) { _, _ in if let f = game.flash { react(f) } }
        .onChange(of: game.submitting) { _, on in if on { hop() } }
        .onChange(of: game.phase) { _, p in finish(p) }
        .onChange(of: game.caption) { _, c in if let c { UIAccessibility.post(notification: .announcement, argument: c) } }
    }

    // MARK: Layout
    private var captionRow: some View {
        Text(game.caption ?? (game.finished ? "Next puzzle at midnight" : LinkingWords.hint))
            .font(.pron).foregroundStyle(Color.ink2)
            .lineLimit(2).minimumScaleFactor(0.9)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .onRule(spacing: rule)
            .animation(reduceMotion ? nil : Motion.state, value: game.caption)
    }

    private var board: some View {
        VStack(spacing: 8) {
            ForEach(Array(game.solved.enumerated()), id: \.element) { i, g in
                SolvedStrip(group: g, drawn: i < drawn || reduceMotion) { w in router.path.append(.define(w)) }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
            }
            // Three columns at accessibility sizes: four won't hold a nine-letter word at that type
            // size without shrinking it back to the size the reader asked to leave behind.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 3 : 4), spacing: 8) {
                ForEach(game.remaining, id: \.self) { w in
                    let picked = game.selected.contains(w)
                    WordTile(word: w, selected: picked, tall: typeSize.isAccessibilitySize, font: boardFont,
                             lift: hopping.contains(w) ? -8 : 0, shake: picked ? shake : 0) {
                        game.tap(w)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { tileWidth = $0 }
                    .transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: game.remaining)
        .animation(reduceMotion ? nil : Motion.reveal, value: game.solved)
        .accessibilityElement(children: .contain)
    }

    /// At accessibility sizes every tile shares one size: the reader's caption size, or smaller only
    /// if the board's longest word needs it — so the long words never look shrunk beside the short.
    private var boardFont: Font {
        guard typeSize.isAccessibilitySize else { return .system(.subheadline, design: .rounded).weight(.bold) }
        let base = UIFont.preferredFont(forTextStyle: .caption1).pointSize
        let longest = CGFloat(game.remaining.map(\.count).max() ?? 8)
        let fit = tileWidth > 0 ? (tileWidth - 12) / (longest * 0.72) : base
        return .system(size: min(base, fit), weight: .bold, design: .rounded)
    }

    private var mistakesRow: some View {
        HStack(spacing: 10) {
            Text("Mistakes left").font(.pron).foregroundStyle(Color.ink2)
            TallyMarks(total: LinkingWords.maxMistakes, used: game.mistakes, animated: !reduceMotion)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(game.mistakesLeft) of \(LinkingWords.maxMistakes) mistakes left")
    }

    @ViewBuilder private var controls: some View {
        if game.finished {
            Button("Results") { showResults = true }
                .buttonStyle(CTAStyle(weight: .outlined))
        } else {
            // Three pills in a row; at accessibility sizes Submit takes its own row above the other two.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { shuffleButton; deselectButton; submitButton }
                VStack(spacing: 10) {
                    submitButton
                    HStack(spacing: 10) { shuffleButton; deselectButton }
                }
            }
            .animation(reduceMotion ? nil : Motion.state, value: game.selected.isEmpty)
            .animation(reduceMotion ? nil : Motion.state, value: game.canSubmit)
        }
    }

    private var shuffleButton: some View {
        Button { game.shuffle() } label: { chip("Shuffle", on: false) }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Shuffle the board")
    }
    private var deselectButton: some View {
        Button { game.deselectAll() } label: { chip("Deselect", on: false) }
            .buttonStyle(PressStyle())
            .opacity(game.selected.isEmpty ? 0.45 : 1)
            .disabled(game.selected.isEmpty)
            .accessibilityLabel("Deselect all")
    }
    private var submitButton: some View {
        Button { game.submit() } label: { chip("Submit", on: game.canSubmit) }
            .buttonStyle(PressStyle())
            .opacity(game.canSubmit ? 1 : 0.45)
            .disabled(!game.canSubmit)
            .accessibilityHint(game.canSubmit ? "" : "Pick four words first")
    }

    /// The game's pills: pen-wash at rest, the pen itself when it's the move to make.
    private func chip(_ text: String, on: Bool) -> some View {
        Text(text)
            .font(.pos).foregroundStyle(on ? Color.onPen : Color.ink)
            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(Capsule().fill(on ? Color.pen : Color.penWash))
            .contentShape(Capsule())
    }

    private var trailing: some View {
        HStack(spacing: 10) {
            KnightDoodle(pose: reaction, color: .ink, accent: .pen)
                .frame(width: 44, height: 44)
                .animation(reduceMotion ? nil : Motion.state, value: reaction)
            GlassIcon("questionmark", "How to play") { showRules = true }
        }
    }

    // MARK: Results
    private var results: some View {
        VStack(spacing: 12) {
            KnightDoodle(pose: game.phase == .won ? .cheer : .idle, color: .ink, accent: .pen)
                .frame(width: 96, height: 96)
            Text(game.verdict).font(.headword).foregroundStyle(Color.ink)
            Text(streakLine).font(.body).foregroundStyle(Color.ink2)
                .contentTransition(.numericText())
            ShareGrid(rows: game.shareRows)
                .padding(.vertical, 6)
            ShareLink(item: game.shareText) { Text("Share") }
                .buttonStyle(CTAStyle())
            TimelineView(.everyMinute) { ctx in
                Text("Next puzzle in \(countdown(from: ctx.date))")
                    .font(.pron).foregroundStyle(Color.ink2)
            }
        }
        .padding(.horizontal, 28).padding(.top, 20).padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            GlassIcon("xmark", "See the board") { showResults = false }
                .padding(.top, 12).padding(.trailing, 12)
        }
        .background {
            Color.clear.sheetSurface(corners: [.topLeft, .topRight])
                .ignoresSafeArea(edges: .bottom)
        }
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        // A bottom sheet goes down the way it came up: a flick down puts it away, like the ✕.
        .gesture(DragGesture(minimumDistance: 20).onEnded { g in
            if g.translation.height > 60 || g.predictedEndTranslation.height > 160 { showResults = false }
        })
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { showResults = false }
    }

    private var streakLine: String {
        switch (game.phase, game.streak) {
        case (.lost, _): "Back tomorrow"
        case (_, 1): "Day one of a streak"
        case (_, let n): "\(n)-day streak"
        }
    }

    private func countdown(from date: Date) -> String {
        let s = max(0, Int(LinkingPuzzle.nextPuzzle(after: date).timeIntervalSince(date)))
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: Reacting
    private func hop() {
        guard !reduceMotion else { return }
        for (i, w) in game.selected.enumerated() {
            Task {
                try? await Task.sleep(for: .milliseconds(80 * i))
                withAnimation(Motion.feedback) { _ = hopping.insert(w) }
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(Motion.state) { _ = hopping.remove(w) }
            }
        }
    }

    private func react(_ f: LinkingWords.Flash) {
        switch f.kind {
        case .solved:  pulse(.impact(flexibility: .rigid)); pose(.cheer)
        case .wrong:   pulse(.warning); pose(.slump); wobble(6)
        case .oneAway: pulse(.warning); pose(.slump); wobble(6)
        case .already: pulse(.impact(flexibility: .soft)); wobble(2)
        }
    }

    private func finish(_ p: LinkingWords.Phase) {
        // A finish replayed from the save when the screen opens is history, not news.
        guard game.justFinished else { return }
        switch p {
        case .won:
            pulse(.success); pose(.cheer, hold: 3)
            Task { try? await Task.sleep(for: .milliseconds(1000)); showResults = true }
        case .lost:
            Task { try? await Task.sleep(for: .milliseconds(600)); showResults = true }
        case .playing: break
        }
    }

    private func pulse(_ kind: SensoryFeedback) { beatKind = kind; beat += 1 }

    private func pose(_ p: KnightPose, hold seconds: Double = 0.9) {
        withAnimation(reduceMotion ? nil : Motion.state) { reaction = p }
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            withAnimation(reduceMotion ? nil : Motion.state) { reaction = .idle }
        }
    }

    private func wobble(_ amount: CGFloat) {
        guard !reduceMotion else { return }
        withAnimation(Motion.feedback.repeatCount(4, autoreverses: true)) { shake = amount }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            shake = 0
        }
    }
}

extension LinkTier {
    /// The highlighter for this tier.
    var color: Color {
        switch self { case .yellow: .highlighter; case .green: .highlighterGreen; case .blue: .highlighterBlue; case .pink: .highlighterPink }
    }
}

// MARK: - Pieces
/// One word on the board: a small sheet, the pen when picked. Game pieces are uppercase.
private struct WordTile: View {
    let word: String
    let selected: Bool
    /// Squarer at accessibility text sizes, so a long word still fits on one line.
    let tall: Bool
    let font: Font
    let lift: CGFloat
    let shake: CGFloat
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button(action: action) {
            // Clear colour, not the text, sets the tile's shape: a text's ideal width would shrink
            // the tile to the word, and the grid wants every tile the same size.
            Color.clear
                .aspectRatio(tall ? 1.15 : 1.3, contentMode: .fit)
                .overlay {
                    Text(word.uppercased())
                        .font(font)
                        .lineLimit(1).minimumScaleFactor(tall ? 0.9 : 0.5).allowsTightening(true)
                        .padding(.horizontal, 6)
                }
                .foregroundStyle(selected ? Color.onPen : Color.ink)
                .background(shape.fill(selected ? Color.pen : Color.sheet))
                .overlay(shape.strokeBorder(selected ? Color.pen : Color.edge, lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(PressStyle())
        .shadow(color: .shadow, radius: selected ? 10 : 0, y: selected ? 4 : 0)
        .offset(x: shake, y: lift)
        .animation(Motion.feedback, value: selected)
        .accessibilityLabel(word)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityHint(selected ? "Deselects" : "Selects")
    }
}

/// A found group: a strip of paper with the tier's highlighter swept across it, the headword on top
/// and the four words under it. Every word on it opens its definition.
private struct SolvedStrip: View {
    let group: LinkingPuzzle.Group
    let drawn: Bool
    let define: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep: CGFloat = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(spacing: 3) {
            Button { define(group.headword.lowercased()) } label: {
                Text(group.headword.uppercased())
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ink)
            }
            .buttonStyle(PressStyle())
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) { wordLinks(separator: ", ") }
                VStack(spacing: 2) { wordLinks(separator: "") }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background {
            ZStack {
                shape.fill(Color.sheet)
                shape.strokeBorder(Color.rule, lineWidth: 1)
                HighlighterSwipe(color: group.tier.color, progress: sweep)
            }
        }
        .onAppear {
            if drawn || reduceMotion { sweep = 1 } else { withAnimation(Motion.slash) { sweep = 1 } }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(group.tier.name) group, \(group.headword): \(group.words.joined(separator: ", "))")
    }

    @ViewBuilder private func wordLinks(separator: String) -> some View {
        ForEach(Array(group.words.enumerated()), id: \.element) { i, w in
            Button { define(w) } label: {
                Text(w + (i < group.words.count - 1 ? separator : ""))
                    .font(.subheadline).foregroundStyle(Color.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(w)
            .accessibilityHint("Opens the definition")
        }
    }
}

/// A highlighter stroke across a strip: one pass, left to right, through the middle of the text
/// rather than filling the paper — a band about three-quarters of the strip tall, soft where the
/// marker touched down and where it lifted, running a little past the strip's edges, a hair off
/// level. In light mode it multiplies over the page, so the ink and the sheet show through the way
/// they do under a real marker; dark paper has no highlighter, so there the tier colour just sits
/// at half strength. `progress` 0…1 draws it.
private struct HighlighterSwipe: View {
    let color: Color
    let progress: CGFloat
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { g in
            let w = g.size.width + 10, h = g.size.height * 0.74
            RoundedRectangle(cornerRadius: h * 0.28, style: .continuous)
                .fill(color)
                .frame(width: w, height: h)
                .mask {
                    HStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 14)
                        Rectangle().frame(width: max(0, (w + 28) * progress - 14 - 28))
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 28)
                        Spacer(minLength: 0)
                    }
                    .frame(width: w, alignment: .leading)
                }
                .rotationEffect(.degrees(-1.2))
                .blendMode(scheme == .dark ? .normal : .multiply)
                .opacity(scheme == .dark ? 1 : 0.9)
                .position(x: g.size.width / 2, y: g.size.height / 2)
        }
        .opacity(progress == 0 ? 0 : 1)
        .allowsHitTesting(false)
    }
}

/// Four pen tally marks; a mistake strikes one through, left to right.
private struct TallyMarks: View {
    let total: Int
    let used: Int
    let animated: Bool

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<total, id: \.self) { i in Tally(struck: i < used, animated: animated) }
        }
    }
}

private struct Tally: View {
    let struck: Bool
    let animated: Bool
    @State private var strike: CGFloat = 0
    @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 14
    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 22
    @ScaledMetric(relativeTo: .footnote) private var pen: CGFloat = 2.2

    var body: some View {
        ZStack {
            TallyBar().doodle(struck ? Color.ink2 : Color.pen, width: pen)
            TallyStrike().trim(from: 0, to: strike)
                .stroke(Color.pen, style: .init(lineWidth: pen, lineCap: .round))
        }
        .frame(width: width, height: height)
        .onAppear { strike = struck ? 1 : 0 }
        .onChange(of: struck) { _, s in
            if animated { withAnimation(Motion.state) { strike = s ? 1 : 0 } } else { strike = s ? 1 : 0 }
        }
    }
}

private struct TallyBar: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.55, y: r.minY + r.height * 0.05))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.45, y: r.minY + r.height * 0.95))
        return p
    }
}

private struct TallyStrike: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX - 2, y: r.minY + r.height * 0.78))
        p.addLine(to: CGPoint(x: r.maxX + 2, y: r.minY + r.height * 0.22))
        return p
    }
}

/// The guesses as rows of highlighter squares — what gets shared, drawn in the real colours.
private struct ShareGrid: View {
    let rows: [[LinkTier]]

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, t in
                        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(t.color).frame(width: 20, height: 20)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rows.enumerated().map { i, row in "Guess \(i + 1): \(row.map(\.name).joined(separator: ", "))" }.joined(separator: ". "))
    }
}

/// How to play, in three lines and one example strip. Shown once on first open, and from the `?`.
struct HowToPlaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28
    private let example = LinkingPuzzle.Group(tier: .yellow, headword: "HAPPY", words: ["glad", "cheerful", "merry", "upbeat"])

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                line("Sixteen words. Four groups of four that mean the same thing.")
                line("Tap four, then Submit. A right group gets highlighted and named.")
                line("Four mistakes and the board shows itself. A new one every midnight.")
                SolvedStrip(group: example, drawn: true) { _ in }
                    .padding(.top, 10)
                    .accessibilityHidden(true)
                HStack(spacing: 14) {
                    ForEach(LinkTier.allCases, id: \.self) { t in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(t.color).frame(width: 14, height: 14)
                            Text(t == .yellow ? "easiest" : t == .pink ? "trickiest" : " ")
                                .font(.pron).foregroundStyle(Color.ink2)
                        }
                    }
                }
                .padding(.top, 8)
                .onRule(spacing: rule)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Groups go from yellow, the easiest, through green and blue to pink, the trickiest")
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .paperScreen("How to play", back: false) {
            GlassIcon("xmark", "Done") { dismiss() }
        }
        .presentationDetents([.medium, .large])
    }

    private func line(_ text: String) -> some View {
        Text(text).font(.body).foregroundStyle(Color.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onRule(2, spacing: rule)
    }
}
