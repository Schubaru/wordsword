import SwiftUI

/// One level of Word Wheel: the board you're filling, the wheel you spell from, and the coins in
/// between. The game itself lives in `WordWheel`; this screen draws it and reacts to it.
struct WordWheelView: View {
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28
    @State private var game = WordWheel()
    @State private var beat = 0
    @State private var beatKind = SensoryFeedback.success
    @State private var reaction: KnightPose = .idle
    @State private var shake: CGFloat = 0
    @State private var showBonus = false
    @State private var typing = false
    @State private var typed = ""

    var body: some View {
        GeometryReader { g in
            if let level = game.level { content(level, in: g.size) }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperScreen("Level \(game.save.level)") { trailing }
        .overlay(alignment: .bottom) { if game.completed { done } }
        .animation(reduceMotion ? nil : Motion.reveal, value: game.completed)
        .sheet(isPresented: $showBonus) {
            BonusWordsSheet(words: game.save.foundBonus) { w in
                showBonus = false
                router.path.append(.define(w))
            }
        }
        .alert("Type a word", isPresented: $typing) {
            TextField("Letters from the wheel", text: $typed)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Submit") { game.submit(typed: typed); typed = "" }
            Button("Cancel", role: .cancel) { typed = "" }
        }
        .task { await game.load() }
        .sensoryFeedback(trigger: beat) { _, _ in beatKind }
        .sensoryFeedback(trigger: game.selection.count) { _, n in n > 0 ? .selection : nil }
        .onChange(of: game.flash?.id) { _, _ in if let f = game.flash { react(f) } }
        .onChange(of: game.completed) { _, done in if done { pulse(.success); pose(.cheer, hold: 3) } }
        .onChange(of: game.caption) { _, c in if let c { UIAccessibility.post(notification: .announcement, argument: c) } }
        #if DEBUG
        // `SIMCTL_CHILD_WHEEL_POSE=1 simctl launch …` holds a half-spelled word for screenshots.
        .onChange(of: game.level == nil) { _, empty in
            if !empty, ProcessInfo.processInfo.environment["WHEEL_POSE"] != nil { game.debugSelect(3) }
        }
        #endif
    }

    // MARK: Layout
    private func content(_ level: Level, in size: CGSize) -> some View {
        let gap: CGFloat = 4
        let tile = min((size.width - gap * CGFloat(level.cols - 1)) / CGFloat(level.cols),
                       (size.height * 0.32 - gap * CGFloat(level.rows - 1)) / CGFloat(level.rows), 48)
        let boardH = tile * CGFloat(level.rows) + gap * CGFloat(level.rows - 1)
        return VStack(spacing: 0) {
            BoardView(level: level, tile: tile, gap: gap, picking: game.picking,
                      letter: game.letter(at:), revealed: game.isRevealed(_:), delay: delay(for:)) { tap($0) }
                .frame(maxWidth: .infinity)
                .frame(height: max(boardH, size.height * 0.2))
                .contentShape(Rectangle())
                .onTapGesture { game.cancelHint() }
            Text(game.caption ?? " ")
                .font(.pron).foregroundStyle(Color.ink2)
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .onRule(spacing: rule)
                .animation(reduceMotion ? nil : Motion.state, value: game.caption)
            capsuleRow
                .frame(height: 60)
                .padding(.top, 4)
            WheelView(letters: level.letters, order: game.order, selection: game.selection,
                      onEnter: game.enter(_:), onRelease: game.release)
                .frame(maxWidth: 320)   // a short board leaves more room than a wheel should take
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 8).padding(.bottom, 12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Letter wheel: \(level.letters.map { String($0).uppercased() }.joined(separator: ", "))")
                .accessibilityHint("Drag across letters to spell a word")
                .accessibilityAction(named: "Type a word") { typing = true }
                .overlay(alignment: .bottomLeading) { GlassIcon("shuffle", "Shuffle letters") { game.shuffle() } }
                .overlay(alignment: .bottomTrailing) { hintButton }
        }
    }

    private var capsuleRow: some View {
        ZStack {
            HStack {
                if !game.save.foundBonus.isEmpty {
                    Button { showBonus = true } label: {
                        chip("\(game.save.foundBonus.count) bonus")
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("\(game.save.foundBonus.count) bonus words")
                }
                Spacer()
                if game.multiplier > 1 {
                    chip("×\(game.multiplier.formatted())")
                        .accessibilityLabel("Streak bonus, times \(game.multiplier.formatted())")
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : Motion.state, value: game.multiplier)
            if let word = displayed {
                Text(word.uppercased())
                    .font(.headword).foregroundStyle(Color.onPen)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.horizontal, 22).padding(.vertical, 4)
                    .background(Capsule().fill(Color.pen))
                    .offset(x: shake, y: lift)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .accessibilityHidden(true)
            }
        }
        .animation(reduceMotion ? nil : Motion.feedback, value: displayed)
    }

    /// The word being connected, or the one just released, held for a beat.
    private var displayed: String? { game.current.isEmpty ? game.flash?.word : game.current }
    private var lift: CGFloat {
        guard game.current.isEmpty, let f = game.flash, !reduceMotion else { return 0 }
        switch f.kind { case .board, .bonus: return -8; case .already, .invalid: return 0 }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.pos).foregroundStyle(Color.pen)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.penWash, in: Capsule())
    }

    private var hintButton: some View {
        VStack(spacing: 2) {
            GlassIcon("lightbulb", "Hint, \(WordWheelRules.hintPrice) coins") { game.hint() }
                .overlay { Circle().strokeBorder(Color.pen, lineWidth: game.picking ? 2 : 0).allowsHitTesting(false) }
            Text("\(WordWheelRules.hintPrice)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(game.canHint ? Color.ink : Color.ink2)
                .accessibilityHidden(true)
        }
    }

    private var trailing: some View {
        HStack(spacing: 10) {
            KnightDoodle(pose: reaction, color: .ink, accent: .pen)
                .frame(width: 44, height: 44)
                .animation(reduceMotion ? nil : Motion.state, value: reaction)
            CoinPill(coins: game.save.coins)
        }
    }

    private var done: some View {
        VStack(spacing: 12) {
            KnightDoodle(pose: .cheer, color: .ink, accent: .pen).frame(width: 96, height: 96)
            Text("Level \(game.save.level) done").font(.headword).foregroundStyle(Color.ink)
            Text(summary).font(.body).foregroundStyle(Color.ink2)
            Button("Next level") { game.nextLevel() }
                .buttonStyle(CTAStyle())
                .padding(.top, 8)
        }
        .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        // The content stays above the home indicator; the sheet itself runs on to the screen's edge.
        // `ignoresSafeArea` on the content's own frame does nothing (it's sized by its content), so
        // the surface is a background, which is free to grow into the safe area it touches.
        .background {
            Color.clear.sheetSurface(corners: [.topLeft, .topRight])
                .ignoresSafeArea(edges: .bottom)
        }
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityAddTraits(.isModal)
    }

    private var summary: String {
        let b = game.save.foundBonus.count
        return "+\(game.save.levelCoins) coins" + (b == 0 ? "" : " · \(b) bonus word\(b == 1 ? "" : "s")")
    }

    // MARK: Reacting
    private func tap(_ cell: Level.Cell) {
        if game.picking {
            game.reveal(cell)
            pulse(.impact(flexibility: .rigid))
        } else if let w = game.foundWord(at: cell) {
            router.path.append(.define(w))
        }
    }

    private func delay(for cell: Level.Cell) -> Double {
        guard let i = game.lastFound?.cells.firstIndex(of: cell) else { return 0 }
        return Double(min(i, 8)) * 0.04
    }

    private func react(_ f: WordWheel.Flash) {
        switch f.kind {
        case .board:   pulse(.impact(flexibility: .rigid)); pose(.cheer)
        case .bonus:   pulse(.impact(flexibility: .soft));  pose(.cheer)
        case .already: pulse(.impact(flexibility: .soft));  wobble(2)
        case .invalid: pulse(.warning);                     pose(.slump); wobble(6)
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

/// Coins, counted on a pen-wash capsule. The coin is drawn, like everything else here.
struct CoinPill: View {
    let coins: Int
    var body: some View {
        HStack(spacing: 6) {
            CoinDoodle().frame(width: 16, height: 16)
            Text("\(coins)").font(.pos).contentTransition(.numericText())
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Capsule().fill(Color.penWash))
        .animation(Motion.state, value: coins)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(coins) coins")
    }
}

struct CoinDoodle: View {
    var body: some View {
        ZStack {
            Circle().doodle(.ink, width: 1.6)
            Circle().inset(by: 3.5).doodle(.ink, width: 1)
        }
        .accessibilityHidden(true)
    }
}

/// The bonus words found on this level. Each one opens its definition — a word you found is a word
/// you can look up.
struct BonusWordsSheet: View {
    let words: [String]
    let pick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(Array(words.enumerated()), id: \.element) { i, w in
                    Button { pick(w) } label: {
                        HStack {
                            Text(w).font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Color.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.ink2)
                        }
                    }
                    .sheetRowButton(i, of: words.count)
                }
            } footer: {
                Text("Real words that aren't on the board. Tap one to look it up.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .paperScreen("Bonus words", back: false) {
            GlassIcon("xmark", "Done") { dismiss() }
        }
        .presentationDetents([.medium, .large])
    }
}
