import SwiftUI

/// Today's Haikuzy: the haiku written on the paper with one word cut out, four guess lines under
/// it, and the field at the bottom. The game lives in `Haikuzy`; this draws it and reacts. Every
/// guess lands on its line with its score and a bar as long as the score; the best one so far is
/// in the pen. The only colour is the pink highlighter, and it only ever means "found".
struct HaikuzyView: View {
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28
    @State private var game = Haikuzy()
    @State private var input = ""
    @FocusState private var focused: Bool

    @State private var beat = 0
    @State private var beatKind = SensoryFeedback.success
    @State private var reaction: KnightPose = .idle
    @State private var shake: CGFloat = 0
    /// The guess that just landed: its bar draws in; the others are already drawn.
    @State private var fresh: Int?
    /// The word is being written into the blank on this screen, not reloaded already written.
    @State private var writing = false
    @State private var showResults = false
    @State private var showRules = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let h = game.haiku {
                        captionRow
                        HaikuPoem(haiku: h, font: .poem, rule: rule, reveal: reveal, animate: writing)
                            .padding(.top, rule)
                        Color.clear.frame(height: rule)
                        ForEach(0..<HaikuzyRules.maxGuesses, id: \.self) { i in
                            GuessLine(index: i,
                                      guess: i < game.guesses.count ? game.guesses[i] : nil,
                                      best: game.bestIndex == i,
                                      fresh: fresh == i,
                                      rule: rule)
                                .id(i)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, rule)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: game.guesses.count) { _, n in
                guard n > 0 else { return }
                withAnimation(reduceMotion ? nil : Motion.state) { proxy.scrollTo(n - 1, anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { if game.haiku != nil { bottomBar } }
        .allowsHitTesting(!showResults)
        .paperScreen("Haikuzy") { trailing }
        .overlay(alignment: .bottom) { if showResults { results } }
        .animation(reduceMotion ? nil : Motion.reveal, value: showResults)
        .animation(reduceMotion ? nil : Motion.state, value: game.choices)
        .sheet(isPresented: $showRules, onDismiss: focusField) { HaikuzyRulesSheet() }
        .task {
            await game.load()
            if !game.save.rulesSeen { showRules = true; game.markRulesSeen() } else { focusField() }
        }
        // Midnight passed while the app was away: back in the foreground means the new day's poem.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, game.isStale else { return }
            showResults = false; writing = false; fresh = nil; input = ""
            Task { await game.load(); focusField() }
        }
        .sensoryFeedback(trigger: beat) { _, _ in beatKind }
        .onChange(of: game.flash?.id) { _, _ in if let f = game.flash { react(f) } }
        .onChange(of: game.phase) { _, p in finish(p) }
        .onChange(of: game.caption) { _, c in if let c { UIAccessibility.post(notification: .announcement, argument: c) } }
    }

    private var reveal: HaikuPoem.Reveal { game.finished ? .written(found: game.phase == .won) : .hidden }

    // MARK: Caption
    private var captionText: String {
        if let c = game.caption { return c }
        switch game.phase {
        case .won:  return "Next haiku at midnight"
        case .lost: return "It was \u{201C}\(game.answer ?? "")\u{201D}"
        case .playing:
            let left = HaikuzyRules.maxGuesses - game.guesses.count
            return game.guesses.isEmpty ? Haikuzy.hint : left == 1 ? "Last guess" : "\(left) guesses left"
        }
    }

    private var captionRow: some View {
        Text(captionText)
            .font(.pron).foregroundStyle(Color.ink2)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onRule(spacing: rule)
            .animation(reduceMotion ? nil : Motion.state, value: captionText)
    }

    // MARK: The field
    @ViewBuilder private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if game.finished {
                Button("Results") { showResults = true }
                    .buttonStyle(CTAStyle(weight: .outlined))
            } else {
                if !game.choices.isEmpty { choicesRow.transition(.opacity.combined(with: .move(edge: .bottom))) }
                field.offset(x: shake)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    /// Home's search field, for a guess: system body type, `sheet` fill, the 1pt `rule` edge that
    /// turns `pen` while it has focus. Autocorrect is off — the game fixes typos itself and shows
    /// the fix, so iOS swapping the word first would hide it. Once there's a word, the trailing
    /// button is the pen: the move to make (the keyboard's Go does the same).
    private var field: some View {
        HStack(spacing: 8) {
            TextField("", text: $input, prompt: Text(placeholder).foregroundStyle(Color.ink2.opacity(0.8)))
                .font(.body).foregroundStyle(Color.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focused)
                .onSubmit(submit)
                .onChange(of: input) { _, _ in if !game.choices.isEmpty { game.dismissChoices() } }
                .accessibilityLabel("Your guess")
                .accessibilityHint("Guess \(game.guesses.count + 1) of \(HaikuzyRules.maxGuesses)")
            if !input.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.onPen)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.pen))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .disabled(game.busy)
                .accessibilityLabel("Guess")
                .transition(.opacity)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .frame(minHeight: 44)
        .background {
            Capsule().fill(Color.sheet)
                .overlay { Capsule().strokeBorder(focused ? Color.pen : Color.rule, lineWidth: 1) }
        }
        .animation(reduceMotion ? nil : Motion.state, value: focused)
        .animation(reduceMotion ? nil : Motion.state, value: input.isEmpty)
    }

    private var placeholder: String { "Guess \(game.guesses.count + 1) of \(HaikuzyRules.maxGuesses)" }

    /// A typo that could be more than one word. Same words and chips as Home's did-you-mean; a
    /// pick is the guess, and nothing is spent until then.
    private var choicesRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Did you mean").font(.pron).foregroundStyle(Color.ink2)
            HStack(spacing: 8) {
                ForEach(game.choices, id: \.self) { w in
                    Button {
                        Task { await game.pick(w); input = "" }
                    } label: {
                        Text(w).font(.pos).foregroundStyle(Color.ink)
                            .padding(.horizontal, 14).frame(minHeight: 36)
                            .background(Capsule().fill(Color.penWash))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Did you mean")
    }

    private func submit() {
        let text = input
        let before = game.guesses.count
        Task {
            await game.submit(text)
            // A guess that counted clears the field; a miss or a repeat leaves it to fix.
            if game.guesses.count > before { input = "" }
            if !game.finished { focused = true }
        }
    }

    private func focusField() {
        guard !game.finished else { return }
        // Focus can't be taken on the tick the view appears; wait out the push.
        Task { try? await Task.sleep(for: .milliseconds(450)); focused = true }
    }

    private var trailing: some View {
        HStack(spacing: 10) {
            KnightDoodle(pose: reaction, color: .ink, accent: .pen)
                .frame(width: 44, height: 44)
                .animation(reduceMotion ? nil : Motion.state, value: reaction)
                .accessibilityHidden(true)
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
            GlassIcon("xmark", "See the poem") { showResults = false }
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
    }

    private var resultsBody: some View {
        VStack(spacing: 12) {
            KnightDoodle(pose: game.phase == .won ? .cheer : .idle, color: .ink, accent: .pen)
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text(game.verdict).font(.headword).foregroundStyle(Color.ink)
            if let h = game.haiku {
                HaikuPoem(haiku: h, font: .define, rule: rule, reveal: .written(found: game.phase == .won), ruled: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            }
            Text(game.guesses.map { "\($0.score)" }.joined(separator: "  ·  "))
                .font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
                .foregroundStyle(Color.ink2)
                .accessibilityLabel("Scores: " + game.guesses.map { "\($0.word) \($0.score)" }.joined(separator: ", "))
            // The point of every game here: the word you found is a word you can look up.
            if let a = game.answer {
                Button("Look up \u{201C}\(a)\u{201D}") { router.path.append(.define(a)) }
                    .buttonStyle(CTAStyle())
            }
            ShareLink(item: game.shareText) { Text("Share") }
                .buttonStyle(CTAStyle(weight: .outlined))
            TimelineView(.everyMinute) { ctx in
                Text("Next haiku in \(countdown(from: ctx.date))")
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
    private func react(_ f: Haikuzy.Flash) {
        switch f.kind {
        case .invalid:
            pulse(.warning); pose(.slump); wobble(6)
        case .repeated:
            pulse(.impact(flexibility: .soft)); wobble(2)
        case .scored(let best):
            fresh = game.guesses.count - 1
            let score = game.guesses.last?.score ?? 0
            if best { pulse(.impact(flexibility: .rigid)); if score >= 70 { pose(.cheer) } }
            else { pulse(.impact(flexibility: .soft)); if score < 40 { pose(.slump) } }
        case .won:
            fresh = game.guesses.count - 1
        }
    }

    private func finish(_ p: Haikuzy.Phase) {
        // A finish replayed from the save when the screen opens is history, not news.
        guard game.justFinished else { return }
        focused = false
        writing = !reduceMotion
        switch p {
        case .won:
            pulse(.success); pose(.cheer, hold: 3)
            Task { try? await Task.sleep(for: .milliseconds(1600)); showResults = true }
        case .lost:
            pose(.slump, hold: 1.5)
            Task { try? await Task.sleep(for: .milliseconds(1400)); showResults = true }
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

extension Font {
    /// The poem on the game screen: Define's serif, a size up — it's the page you're reading.
    static let poem = Font.system(.title2, design: .serif)
}

// MARK: - The poem
/// A haiku written on the rules. Each line is a flow of words in rows one rule tall, every row's
/// baseline on its rule, so a line that wraps at a large text size wraps onto the next rule the
/// way handwriting would. The hidden word is a pen line — always the same length, so it gives
/// nothing away — until the day is done; then the word is written in, cut in by the slash and
/// swept with the pink highlighter when it was found, the grey pen wash when it wasn't.
struct HaikuPoem: View {
    enum Reveal: Equatable { case hidden, written(found: Bool) }

    let haiku: Haiku
    let font: Font
    let rule: CGFloat
    var reveal: Reveal = .hidden
    /// Write the word in now (slash, then the highlighter) rather than show it already written.
    var animate = false
    /// Draw its own hairlines — on a card, where the paper's rules are covered.
    var ruled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(haiku.lines.enumerated()), id: \.offset) { _, text in
                RuledFlow(rule: rule, spacing: rule * 0.22) {
                    ForEach(Array(text.split(separator: " ").enumerated()), id: \.offset) { _, t in token(String(t)) }
                }
                .background { if ruled { Hairlines(rule: rule) } }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken(text))
            }
        }
        .font(font)
        .foregroundStyle(Color.ink)
    }

    @ViewBuilder private func token(_ t: String) -> some View {
        if let r = t.range(of: Haiku.blank) {
            let before = String(t[..<r.lowerBound]), after = String(t[r.upperBound...])
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                if !before.isEmpty { Text(before) }
                HiddenWord(word: haiku.answer, reveal: reveal, animate: animate)
                if !after.isEmpty { Text(after) }
            }
        } else {
            Text(t)
        }
    }

    private func spoken(_ text: String) -> String {
        switch reveal {
        case .hidden:  text.replacingOccurrences(of: Haiku.blank, with: "blank")
        case .written: text.replacingOccurrences(of: Haiku.blank, with: haiku.answer)
        }
    }
}

/// The gap in the poem. Hidden: a hand-drawn pen line on the baseline, the same length whatever
/// the word. Written: the word, cut in by the slash when `animate`, then swept with the pink
/// highlighter if it was found, the grey pen wash if not.
private struct HiddenWord: View {
    let word: String
    let reveal: HaikuPoem.Reveal
    let animate: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title3) private var width: CGFloat = 76
    @State private var cut: CGFloat = 0
    @State private var sweep: CGFloat = 0

    var body: some View {
        Group {
            switch reveal {
            case .hidden:
                // An invisible letter keeps the baseline and the height of the words around it.
                Text("M").hidden()
                    .frame(width: width, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        DoodleStroke(progress: 1)
                            .stroke(Color.pen, style: .init(lineWidth: 2, lineCap: .round))
                            .frame(height: 6)
                    }
            case .written(let found):
                Text(word)
                    // Pink only ever means found; a missed word gets the quiet pen wash.
                    .background { HighlighterSwipe(color: found ? .highlighterPink : .penWash, progress: sweep) }
                    .slashReveal(cut, edge: .pen)
                    .onAppear { write() }
            }
        }
    }

    private func write() {
        guard animate, !reduceMotion else { cut = 1; sweep = 1; return }
        cut = 0; sweep = 0
        withAnimation(Motion.slash) { cut = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(Motion.slash) { sweep = 1 }
        }
    }
}

/// Words in rows exactly one rule tall, each word's baseline on its row's rule. The block is a
/// whole number of rules, so whatever follows it stays on the grid.
private struct RuledFlow: Layout {
    let rule: CGFloat
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let widest = rows.map(\.width).max() ?? 0
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? widest
        return CGSize(width: width, height: CGFloat(max(1, rows.count)) * rule)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (r, row) in arrange(subviews, width: bounds.width).enumerated() {
            let baseline = bounds.minY + CGFloat(r + 1) * rule
            var x = bounds.minX
            for i in row.items {
                let d = subviews[i].dimensions(in: .unspecified)
                subviews[i].place(at: CGPoint(x: x, y: baseline - d[VerticalAlignment.lastTextBaseline]), proposal: .unspecified)
                x += d.width + spacing
            }
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let w = subviews[i].sizeThatFits(.unspecified).width
            let needed = rows[rows.count - 1].items.isEmpty ? w : rows[rows.count - 1].width + spacing + w
            if needed > width, !rows[rows.count - 1].items.isEmpty {
                rows.append(Row(items: [i], width: w))
            } else {
                rows[rows.count - 1].items.append(i)
                rows[rows.count - 1].width = needed
            }
        }
        return rows
    }
}

/// The paper's rule, drawn once per row at the baseline, for a poem lying on a sheet.
private struct Hairlines: View {
    let rule: CGFloat
    var body: some View {
        GeometryReader { g in
            Path { p in
                var y = rule
                while y <= g.size.height + 0.5 {
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: g.size.width, y: y))
                    y += rule
                }
            }
            .stroke(Color.paperRule, lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - A guess, on its line
/// Two rules: the word (and the typo it was fixed from, struck through) with its score, then a bar
/// as long as the score. The best so far is in the pen; the rest in `ink-2`. The word itself gets
/// the pink highlighter. An empty slot is just paper.
private struct GuessLine: View {
    let index: Int
    let guess: HaikuzySave.Guess?
    let best: Bool
    let fresh: Bool
    let rule: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fill: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let g = guess {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(g.word)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .background { if g.score == 100 { HighlighterSwipe(color: .highlighterPink, progress: fill) } }
                    if let typo = g.typed {
                        Text(typo).font(.pron).strikethrough(color: .ink2).foregroundStyle(Color.ink2)
                    }
                    Spacer(minLength: 8)
                    Text("\(g.score)")
                        .font(.system(.title3, design: .rounded).weight(best ? .bold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(best ? Color.ink : Color.ink2)
                }
                .onRule(spacing: rule)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.rule)
                        Capsule().fill(best ? Color.pen : Color.ink2)
                            .frame(width: max(5, geo.size.width * CGFloat(g.score) / 100 * fill))
                    }
                }
                .frame(height: 5)
                .padding(.top, 7)
                .frame(height: rule, alignment: .top)
            } else {
                Color.clear.frame(height: 2 * rule)
            }
        }
        .animation(Motion.state, value: best)
        .onAppear { if !fresh { fill = guess == nil ? 0 : 1 } }
        .onChange(of: guess) { _, g in
            guard g != nil else { fill = 0; return }
            fill = 0
            withAnimation(reduceMotion ? nil : Motion.reveal.delay(0.05)) { fill = 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: String {
        guard let g = guess else { return "Guess \(index + 1), not yet" }
        var s = "Guess \(index + 1), \(g.word)"
        if let t = g.typed { s += ", fixed from \(t)" }
        s += ", \(g.score) of 100"
        if best && g.score < 100 { s += ", best so far" }
        return s
    }
}

// MARK: - How to play
struct HaikuzyRulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                line("One word is missing from today's haiku. Guess it in four tries.")
                line("Every guess scores 1 to 100 for how close it is in meaning. The word itself scores 100.")
                line("Only real words count, and a typo gets fixed for you.")
                line("A new haiku every midnight, and every word is one you can look up.")
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

// MARK: - The featured card on Home
/// Haikuzy on Home, above the other games and bigger than them: the card *is* today's haiku. Its
/// header is the one every game card has — doodle, name, where you are, chevron — and under it
/// the poem in Define's serif, written on ruled hairlines with the blank in it. Once the day is
/// done the word is written in (swept pink if you found it). The whole card is one tap. It's a
/// sheet lying on the paper like the others, and a whole number of rules tall with its bottom
/// edge resting on a rule.
struct HaikuzyCard: View {
    let rule: CGFloat
    let save: HaikuzySave
    let action: () -> Void
    @ScaledMetric(relativeTo: .headline) private var mark: CGFloat = 48

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let state = Haikuzy.cardState(save)
        let haiku = HaikuzyBank.haiku(number: HaikuzyBank.number())
        let detail = Haikuzy.cardDetail(save)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    HaikuDoodle(color: .ink, accent: .highlighterPink).frame(width: mark, height: mark)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Haikuzy").font(.system(.headline, design: .rounded)).foregroundStyle(Color.ink)
                        Text(detail).font(.subheadline).foregroundStyle(Color.ink2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Color.ink2)
                }
                if let haiku {
                    HaikuPoem(haiku: haiku, font: .define, rule: rule,
                              reveal: state.finished ? .written(found: state.solved) : .hidden, ruled: true)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(Color.sheet))
            .overlay(shape.strokeBorder(Color.rule, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(SurfacePressStyle(shape: shape))
        .shadow(color: .shadow, radius: 16, y: 6)
        .modifier(OnRules(rule: rule))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(haiku, state: state, detail: detail))
        .accessibilityHint("Opens the game")
        .accessibilityAddTraits(.isButton)
    }

    private func accessibilityText(_ h: Haiku?, state: (finished: Bool, solved: Bool), detail: String) -> String {
        guard let h else { return "Haikuzy, \(detail)" }
        let poem = h.lines.map { $0.replacingOccurrences(of: Haiku.blank, with: state.finished ? h.answer : "blank") }
        return "Haikuzy, today's haiku: " + poem.joined(separator: ", ") + ". " + detail
    }
}

/// Rounds a block up to a whole number of rules and sets it on the bottom one, leaving the gap
/// above it — the way `GameCard` sits on the grid, for a card whose height isn't known ahead.
private struct OnRules: ViewModifier {
    let rule: CGFloat
    func body(content: Content) -> some View { RuleSnap(rule: rule) { content } }
}

private struct RuleSnap: Layout {
    let rule: CGFloat
    /// The gap above the card, under whatever was written on the line before.
    var gap: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let s = subviews.first?.sizeThatFits(proposal) else { return .zero }
        return CGSize(width: proposal.width ?? s.width, height: ((s.height + gap) / rule).rounded(.up) * rule)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let v = subviews.first else { return }
        let s = v.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
        v.place(at: CGPoint(x: bounds.minX, y: bounds.maxY - s.height), proposal: ProposedViewSize(width: bounds.width, height: s.height))
    }
}
