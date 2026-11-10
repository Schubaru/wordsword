import SwiftUI

/// Today's Plexicon: six rows of five tiles on the paper and a keyboard under them. The game lives
/// in `Plexicon`; this draws it and reacts. The marks are the pen's — a ring round a letter in the
/// right spot, an underline under one in the wrong spot, a faded letter for one that isn't in the
/// word — shapes, not colours, so the board reads in ink alone.
struct PlexiconView: View {
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var keyBase: CGFloat = 52
    @State private var game = Plexicon()

    @State private var beat = 0
    @State private var beatKind = SensoryFeedback.success
    @State private var reaction: KnightPose = .idle
    @State private var shake: CGFloat = 0
    /// Columns of the winning row mid-hop.
    @State private var hopping: Set<Int> = []
    @State private var showResults = false
    @State private var showRules = false
    /// Today's word in one plain sentence, for the results; nil offline.
    @State private var meaning: String?
    @FocusState private var keysFocused: Bool

    private var keyHeight: CGFloat { min(keyBase, 64) }

    var body: some View {
        VStack(spacing: 0) {
            if game.answer != nil {
                captionRow.padding(.horizontal, 20)
                GeometryReader { g in board(in: g.size).frame(width: g.size.width, height: g.size.height) }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                bottom
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(!showResults)
        // A hardware keyboard types straight onto the board.
        .focusable()
        .focused($keysFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { handle($0) }
        .paperScreen("Plexicon") { trailing }
        .overlay(alignment: .bottom) { if showResults { results } }
        .animation(reduceMotion ? nil : Motion.reveal, value: showResults)
        .sheet(isPresented: $showRules) { PlexiconRulesSheet() }
        .task {
            await game.load()
            if !game.save.rulesSeen { showRules = true; game.markRulesSeen() }
            keysFocused = true
        }
        // Midnight passed while the app was away: back in the foreground means the new day's word.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, game.isStale else { return }
            showResults = false
            Task { await game.load() }
        }
        .sensoryFeedback(trigger: beat) { _, _ in beatKind }
        .sensoryFeedback(trigger: game.typed.count) { old, new in new > old ? .selection : nil }
        .onChange(of: game.flash?.id) { _, _ in if let f = game.flash { react(f) } }
        .onChange(of: game.phase) { _, p in finish(p) }
        .onChange(of: game.caption) { _, c in if let c { UIAccessibility.post(notification: .announcement, argument: c) } }
    }

    // MARK: Layout
    private var captionText: String {
        if let c = game.caption { return c }
        switch game.phase {
        case .lost:    return "It was \(game.answer?.uppercased() ?? "")"
        case .won:     return "Next word at midnight"
        case .playing: return Plexicon.hint
        }
    }

    private var captionRow: some View {
        Text(captionText)
            .font(.pron).foregroundStyle(Color.ink2)
            .lineLimit(2).minimumScaleFactor(0.9)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .onRule(spacing: rule)
            .animation(reduceMotion ? nil : Motion.state, value: captionText)
    }

    /// Six rows of five, as large as the room between the caption and the keyboard allows.
    private func board(in size: CGSize) -> some View {
        let gap: CGFloat = 6
        let tile = max(24, min(64, (size.width - 4 * gap) / 5, (size.height - 5 * gap) / 6)).rounded(.down)
        return VStack(spacing: gap) {
            ForEach(0..<Plexicon.maxGuesses, id: \.self) { r in row(r, tile: tile, gap: gap) }
        }
    }

    private func row(_ r: Int, tile: CGFloat, gap: CGFloat) -> some View {
        let guesses = game.guesses
        let guessed = r < guesses.count
        let current = r == guesses.count && game.phase == .playing
        let letters: [Character] = guessed ? Array(guesses[r]) : current ? Array(game.typed) : []
        let marks: [PlexMark]? = guessed ? game.marks(guesses[r]) : nil
        let winning = game.phase == .won && r == guesses.count - 1
        return HStack(spacing: gap) {
            ForEach(0..<PlexiconWords.length, id: \.self) { c in
                PlexTile(letter: c < letters.count ? letters[c] : nil,
                         mark: marks.flatMap { c < $0.count ? $0[c] : nil },
                         cursor: current && !game.revealing && c == letters.count,
                         size: tile, delay: Double(c) * Plexicon.stagger)
                    .offset(y: winning && hopping.contains(c) ? -8 : 0)
            }
        }
        .offset(x: current ? shake : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowLabel(r, letters: letters, marks: marks, current: current))
    }

    private func rowLabel(_ r: Int, letters: [Character], marks: [PlexMark]?, current: Bool) -> String {
        let word = String(letters).uppercased()
        if let marks { return "Guess \(r + 1), \(word): " + spoken(letters, marks) }
        if current, !letters.isEmpty { return "Guess \(r + 1), typing \(word), \(PlexiconWords.length - letters.count) to go" }
        return "Guess \(r + 1), empty"
    }

    private func spoken(_ letters: [Character], _ marks: [PlexMark]) -> String {
        zip(letters, marks).map { "\(String($0).uppercased()) \($1.spoken)" }.joined(separator: ", ")
    }

    @ViewBuilder private var bottom: some View {
        if game.finished {
            Button("Results") { showResults = true }
                .buttonStyle(CTAStyle(weight: .outlined))
                .padding(.horizontal, 20).padding(.bottom, 16)
        } else {
            keyboard.padding(.horizontal, 6).padding(.bottom, 6)
        }
    }

    // MARK: Keyboard
    private var keyboard: some View {
        let marks = game.keyMarks
        let gap: CGFloat = 6
        return GeometryReader { g in
            let w = ((g.size.width - 9 * gap) / 10).rounded(.down)
            VStack(spacing: 8) {
                HStack(spacing: gap) { ForEach(Array("qwertyuiop"), id: \.self) { letterKey($0, marks[$0], width: w) } }
                HStack(spacing: gap) { ForEach(Array("asdfghjkl"), id: \.self) { letterKey($0, marks[$0], width: w) } }
                HStack(spacing: gap) {
                    actionKey("return", "Enter", width: w * 1.5 + gap / 2, ready: game.typed.count == PlexiconWords.length) { game.enter() }
                    ForEach(Array("zxcvbnm"), id: \.self) { letterKey($0, marks[$0], width: w) }
                    actionKey("delete.left", "Delete", width: w * 1.5 + gap / 2, ready: false) { game.delete() }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: keyHeight * 3 + 16)
    }

    private func letterKey(_ ch: Character, _ mark: PlexMark?, width: CGFloat) -> some View {
        Button { game.type(ch) } label: {
            PlexKeyFace(letter: ch, mark: mark, width: width, height: keyHeight)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(String(ch).uppercased())
        .accessibilityValue(mark?.spoken ?? "")
    }

    /// Enter and Delete. Enter becomes the pen once five letters are down — the move to make.
    private func actionKey(_ symbol: String, _ label: String, width: CGFloat, ready: Bool, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ready ? Color.onPen : Color.ink)
                .frame(width: width, height: keyHeight)
                .background(shape.fill(ready ? Color.pen : Color.penWash))
                .contentShape(shape)
        }
        .buttonStyle(PressStyle())
        .animation(Motion.state, value: ready)
        .accessibilityLabel(label)
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        guard !showResults, !showRules else { return .ignored }
        if press.key == .return { game.enter(); return .handled }
        if press.key == .delete || press.key == .deleteForward { game.delete(); return .handled }
        if let c = press.characters.first, c.isLetter, c.isASCII { game.type(c); return .handled }
        return .ignored
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
        ViewThatFits(in: .vertical) {
            resultsBody
            ScrollView { resultsBody }
        }
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
        .gesture(DragGesture(minimumDistance: 20).onEnded { g in
            if g.translation.height > 60 || g.predictedEndTranslation.height > 160 { showResults = false }
        })
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { showResults = false }
        .task(id: game.answer) {
            guard let a = game.answer else { return }
            let m = await WordOfTheDay.meaning(of: a)
            withAnimation(reduceMotion ? nil : Motion.state) { meaning = m }
        }
    }

    private var resultsBody: some View {
        VStack(spacing: 12) {
            KnightDoodle(pose: game.phase == .won ? .cheer : .idle, color: .ink, accent: .pen)
                .frame(width: 96, height: 96)
            Text(game.verdict).font(.headword).foregroundStyle(Color.ink)
            // The game ends where the app begins: the word, and what it means.
            if let a = game.answer {
                VStack(spacing: 4) {
                    Text(a).font(.system(.title3, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                    if let meaning {
                        Text(meaning)
                            .font(.subheadline).fontDesign(.serif).foregroundStyle(Color.ink2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.bottom, 4)
                .accessibilityElement(children: .combine)
            }
            PlexStats(save: game.save, streak: game.streak)
            GuessBars(counts: game.save.distribution, today: game.phase == .won ? game.guesses.count : nil)
                .padding(.bottom, 4)
            // The point of the whole game: the word you found is a word you can look up.
            if let a = game.answer {
                Button("Look up \u{201C}\(a)\u{201D}") { router.path.append(.define(a)) }
                    .buttonStyle(CTAStyle())
            }
            ShareLink(item: game.shareText) { Text("Share") }
                .buttonStyle(CTAStyle(weight: .outlined))
            TimelineView(.everyMinute) { ctx in
                Text("Next word in \(countdown(from: ctx.date))")
                    .font(.pron).foregroundStyle(Color.ink2)
            }
        }
        .padding(.horizontal, 28).padding(.top, 20).padding(.bottom, 16)
    }

    private func countdown(from date: Date) -> String {
        let s = max(0, Int(LinkingPuzzle.nextPuzzle(after: date).timeIntervalSince(date)))
        let h = s / 3600, m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: Reacting
    private func react(_ f: Plexicon.Flash) {
        switch f.kind {
        case .invalid:
            pulse(.warning); pose(.slump); wobble(6)
        case .landed:
            if let g = game.guesses.last {
                UIAccessibility.post(notification: .announcement, argument: spoken(Array(g), game.marks(g)))
            }
            if game.phase == .playing { pulse(.impact(flexibility: .rigid)) }
        }
    }

    private func finish(_ p: Plexicon.Phase) {
        // A finish replayed from the save when the screen opens is history, not news.
        guard game.justFinished else { return }
        switch p {
        case .won:
            pulse(.success); pose(.cheer, hold: 3); hop()
            Task { try? await Task.sleep(for: .milliseconds(1200)); showResults = true }
        case .lost:
            pose(.slump, hold: 1.5)
            Task { try? await Task.sleep(for: .milliseconds(1000)); showResults = true }
        case .playing: break
        }
    }

    private func hop() {
        guard !reduceMotion else { return }
        for c in 0..<PlexiconWords.length {
            Task {
                try? await Task.sleep(for: .milliseconds(80 * c))
                withAnimation(Motion.feedback) { _ = hopping.insert(c) }
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(Motion.state) { _ = hopping.remove(c) }
            }
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

// MARK: - Pieces
/// One letter on the board: a small sheet. The mark draws in when the row is entered — a pen
/// ring or underline for the found letters, a pen-wash and a faded letter for the ones that aren't
/// in the word — staggered by `delay` so a row reads left to right. Marks already there when the
/// tile appears are simply there.
private struct PlexTile: View {
    let letter: Character?
    let mark: PlexMark?
    var cursor = false
    let size: CGFloat
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0…1: how far the mark has drawn.
    @State private var ink: CGFloat = 0
    @State private var pop = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(6, size * 0.19), style: .continuous)
        ZStack {
            shape.fill(Color.sheet)
            if mark == .absent { shape.fill(Color.penWash).opacity(ink) }
            if let mark, mark != .absent {
                PenMark(mark: mark, progress: reduceMotion ? 1 : ink).opacity(reduceMotion ? ink : 1)
            }
            Text(letter.map { String($0).uppercased() } ?? "")
                .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                .foregroundStyle(mark == .absent && ink > 0 ? Color.ink2 : Color.ink)
        }
        .frame(width: size, height: size)
        .overlay(shape.strokeBorder(edge, lineWidth: cursor ? 2 : 1))
        .scaleEffect(pop ? 1.06 : 1)
        .animation(Motion.feedback, value: cursor)
        .onAppear { ink = mark == nil ? 0 : 1 }
        .onChange(of: mark) { _, m in
            guard m != nil else { ink = 0; return }
            withAnimation(reduceMotion ? Motion.state.delay(delay) : Motion.slash.delay(delay)) { ink = 1 }
        }
        .onChange(of: letter) { old, new in
            guard old == nil, new != nil, mark == nil, !reduceMotion else { return }
            withAnimation(Motion.feedback) { pop = true }
            Task {
                try? await Task.sleep(for: .milliseconds(120))
                withAnimation(Motion.state) { pop = false }
            }
        }
    }

    /// The pen marks where the next letter goes; a typed letter firms its tile's edge.
    private var edge: Color {
        if cursor { return .pen }
        if mark == .absent && ink > 0 { return .rule }
        return letter != nil && mark == nil ? .ink2 : .edge
    }
}

/// A key: the same small sheet as a tile, carrying the best mark its letter has earned.
private struct PlexKeyFace: View {
    let letter: Character
    let mark: PlexMark?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        ZStack {
            shape.fill(Color.sheet)
            if mark == .absent { shape.fill(Color.penWash) }
            if let mark, mark != .absent { PenMark(mark: mark, progress: 1) }
            Text(String(letter).uppercased())
                .font(.system(size: min(20, width * 0.6), weight: .semibold, design: .rounded))
                .foregroundStyle(mark == .absent ? Color.ink2 : Color.ink)
        }
        .frame(width: width, height: height)
        .overlay(shape.strokeBorder(mark == .absent ? Color.rule : Color.edge, lineWidth: 1))
        .contentShape(shape)
        .animation(Motion.state, value: mark)
    }
}

/// The pen on a letter. Right spot: a ring drawn round it in one loop that starts up on the left and
/// runs a little past where it began, the way a hand-drawn circle never quite closes. Wrong spot: an
/// underline, a hair off level. Two shapes and no colour, so neither mark leans on hue to be read.
/// `progress` 0…1 draws the stroke.
private struct PenMark: View {
    let mark: PlexMark
    let progress: CGFloat

    var body: some View {
        GeometryReader { g in
            let line = max(1.5, min(g.size.width, g.size.height) * 0.042)
            (mark == .correct ? AnyShape(PenRing()) : AnyShape(PenUnderline()))
                .trim(from: 0, to: progress)
                .stroke(Color.pen, style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
        }
        .opacity(progress == 0 ? 0 : 1)
        .allowsHitTesting(false)
    }
}

/// A loop round the middle, widening as it goes so the overshoot rides just outside the start.
private struct PenRing: Shape {
    func path(in r: CGRect) -> Path {
        let rx = r.width * 0.4, ry = min(r.height * 0.4, r.width * 0.46)
        let start = -2.3, sweep = 2 * Double.pi + 0.45
        var p = Path()
        for i in 0...64 {
            let t = Double(i) / 64, a = start + sweep * t, grow = 0.95 + 0.1 * t
            let pt = CGPoint(x: r.midX + CGFloat(cos(a) * grow) * rx, y: r.midY + CGFloat(sin(a) * grow) * ry)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

/// One stroke under the letter, sagging a touch and rising off to the right.
private struct PenUnderline: Shape {
    func path(in r: CGRect) -> Path {
        let y = r.minY + r.height * 0.8
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.2, y: y))
        p.addQuadCurve(to: CGPoint(x: r.maxX - r.width * 0.18, y: y - r.height * 0.03),
                       control: CGPoint(x: r.midX, y: y + r.height * 0.05))
        return p
    }
}

/// Days · Solved · Streak · Best, between two ruled hairlines.
private struct PlexStats: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let save: PlexiconSave
    let streak: Int

    private var items: [(value: String, label: String)] {
        [("\(save.played)", "Days"), ("\(save.won)", "Solved"),
         ("\(streak)", "Streak"), ("\(save.bestStreak)", "Best")]
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                Grid(horizontalSpacing: 8, verticalSpacing: 14) {
                    GridRow { stat(items[0]); stat(items[1]) }
                    GridRow { stat(items[2]); stat(items[3]) }
                }
            } else {
                HStack(alignment: .top, spacing: 4) { ForEach(items, id: \.label, content: stat) }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) { Rectangle().fill(Color.rule).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Color.rule).frame(height: 1) }
    }

    private func stat(_ item: (value: String, label: String)) -> some View {
        VStack(spacing: 2) {
            Text(item.value)
                .font(.system(.title, design: .rounded).weight(.regular))
                .monospacedDigit()
                .foregroundStyle(Color.ink)
            Text(item.label)
                .font(.pron).foregroundStyle(Color.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// How many guesses each solve took: a bar per count, today's in the pen.
private struct GuessBars: View {
    let counts: [Int]
    let today: Int?

    var body: some View {
        let top = max(1, counts.max() ?? 0)
        VStack(alignment: .leading, spacing: 4) {
            Text("Guesses it took").font(.pron).foregroundStyle(Color.ink2)
            ForEach(Array(counts.prefix(Plexicon.maxGuesses).enumerated()), id: \.offset) { i, n in
                let mine = today == i + 1
                HStack(spacing: 8) {
                    Text("\(i + 1)").font(.pron).monospacedDigit().foregroundStyle(Color.ink2).frame(width: 12)
                    GeometryReader { g in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(mine ? Color.pen : Color.penWash)
                            .frame(width: max(26, g.size.width * CGFloat(n) / CGFloat(top)))
                            .overlay(alignment: .trailing) {
                                Text("\(n)").font(.pron).monospacedDigit()
                                    .foregroundStyle(mine ? Color.onPen : Color.ink)
                                    .padding(.trailing, 7)
                            }
                    }
                    .frame(height: 18)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Guesses it took: " + counts.enumerated().map { "\($0 + 1): \($1)" }.joined(separator: ", "))
    }
}

/// How to play: three lines and a tile for each mark. Shown once on first open, and from the `?`.
struct PlexiconRulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var sample: CGFloat = 40

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                line("Find today's five-letter word. You get six guesses, and each one has to be a real word.")
                line("The pen marks every letter of a guess:")
                legend("S", .correct, "Circled: in the word, in the right spot").padding(.top, 10)
                legend("A", .present, "Underlined: in the word, in another spot").padding(.top, 8)
                legend("L", .absent, "Faded: not in the word").padding(.top, 8)
                line("At the end you'll see what the word means. A new word every midnight.")
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .paperScreen("How to play", back: false) {
            GlassIcon("xmark", "Done") { dismiss() }
        }
        .presentationDetents([.medium, .large])
    }

    private func legend(_ letter: Character, _ mark: PlexMark, _ text: String) -> some View {
        HStack(spacing: 14) {
            PlexTile(letter: letter, mark: mark, size: sample)
            Text(text).font(.body).foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(letter): \(text)")
    }

    private func line(_ text: String) -> some View {
        Text(text).font(.body).foregroundStyle(Color.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onRule(2, spacing: rule)
    }
}
