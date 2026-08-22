import SwiftUI
import SwiftData

/// The contained chat. No composer — every next step is a tap.
/// Layout (Natural-AI style): the query lives at the top as tappable tokens (the chain), the answer arrives on a
/// white sheet stacked over the ruled paper, follow-ups ride a carousel above one primary action.
struct DefineView: View {
    let word: String
    /// A chain being picked back up, oldest first, ending in `word`. Empty for a fresh lookup.
    var trail: [String] = []
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(Router.self) private var router

    @State private var chain: [String] = []
    @State private var messages: [Message] = []
    @State private var current: Definition?
    @State private var currentWord: Word?
    @State private var altsTried = 0
    @State private var synonymsShown = 4
    @State private var busy = false
    @State private var showLists = false
    @State private var chainSaved = false
    @State private var sheetUp = false

    struct Message: Identifiable {
        enum Kind { case headword(Definition), user(String), text(String), didYouMean([String]), synonyms([String]), loading, end(String), miss(String) }
        let id = UUID()
        let kind: Kind
    }

    var body: some View {
        ZStack(alignment: .top) {
            PaperBackground()
            VStack(spacing: 0) {
                header
                sheet
                    .offset(y: sheetUp ? 0 : 420)
            }
        }
        .safeAreaInset(edge: .bottom) { dock }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showLists) {
            if let w = currentWord { AddToWordlistSheet(word: w) }
        }
        .task {
            withAnimation(anim(Motion.reveal)) { sheetUp = true }
            // Restore the trail before the lookup, so the tokens are already right while it loads
            // rather than popping in behind the definition. `finish` sees its own word already at
            // the end of the chain and leaves it alone.
            if chain.isEmpty { chain = trail }
            if messages.isEmpty { await define(word) }
        }
        // Wherever the chain ends up — a synonym followed, a token jumped back to — that's where
        // Home offers to pick it up again.
        .onChange(of: chain) { _, c in LastSearch.chain = c }
        #if DEBUG
        .onChange(of: router.debug) { _, d in
            Task {
                switch d {
                case "sentence": await sentence()
                case "explain":  await explain()
                case "more":     await moreSynonyms()
                case "sheet":    showLists = true
                case "unsheet":  showLists = false
                case let s where s.hasPrefix("follow:"): await follow(String(s.dropFirst(7)))
                default: break
                }
            }
        }
        #endif
    }

    // MARK: - header: back pill + the chain as tokens + save
    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundStyle(Color.ink)
                    .frame(width: 38, height: 38).glassy(Circle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Back")

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(chain.enumerated()), id: \.offset) { i, w in
                            if i > 0 { Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(Color.ink2) }
                            token(w, current: i == chain.count - 1) { Task { await jump(to: i) } }
                                .id(i)
                        }
                        if chain.isEmpty { token(word.lowercased(), current: true) {} }
                    }
                    .padding(.vertical, 2)
                }
                // A resumed chain arrives fully formed, so there's nothing for the scrollTo below to
                // animate from — and at that point the tokens have no frames yet, so it silently does
                // nothing and the current word stays clipped off the trailing edge. Anchoring the
                // scroll view itself means it's *born* showing the end of the chain, at any length.
                // Only past one token: a lone word doesn't overflow, and anchoring it trailing just
                // strands it against "Save chain" with a hole after the back button.
                .defaultScrollAnchor(chain.count > 1 ? .trailing : .leading)
                .onChange(of: chain.count) { _, n in withAnimation(anim(Motion.state)) { proxy.scrollTo(max(0, n - 1), anchor: .trailing) } }
            }

            if chain.count > 1 {
                Button(chainSaved ? "Saved" : "Save chain") { saveChain() }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.pen)
                    .disabled(chainSaved)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 12)
        .animation(anim(Motion.state), value: chain.count)
    }

    private func token(_ w: String, current: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(w)
                .font(.system(.subheadline, design: .rounded).weight(current ? .bold : .semibold))
                .foregroundStyle(current ? Color.onPen : Color.pen)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(current ? Color.pen : Color.penWash, in: Capsule())
        }
        .buttonStyle(PressStyle())
        .disabled(current)
        .accessibilityLabel(current ? "\(w), current word" : "Back to \(w)")
    }

    /// Tap an earlier token: the chain is a breadcrumb — cut back to it and define it again in the same chat.
    private func jump(to i: Int) async {
        guard i < chain.count - 1 else { return }
        let w = chain[i]
        withAnimation(anim(Motion.state)) { chain = Array(chain.prefix(i + 1)); chainSaved = false }
        append(.user(w))
        await define(w)
    }

    private func saveChain() {
        let list = Wordlist(name: chain.joined(separator: " → "))
        context.insert(list)
        list.words = chain.compactMap { Word.find($0, in: context) }
        withAnimation(anim(Motion.state)) { chainSaved = true }
    }

    // MARK: - the sheet: the chat, on a white sheet over the paper
    private var sheet: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(messages) { m in bubble(m).id(m.id) }
                }
                .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 24)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(anim(Motion.state)) { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheetSurface(corners: [.topLeft, .topRight])
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - bubbles
    @ViewBuilder private func bubble(_ m: Message) -> some View {
        switch m.kind {
        case .headword(let d):
            HeadwordBubble(definition: d, reduceMotion: reduceMotion) { syn in
                Task { await follow(syn) }
            }
        case .user(let t):
            HStack { Spacer()
                Text(t).font(.subheadline.weight(.medium)).foregroundStyle(Color.onPen)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.pen, in: Capsule())
            }
            .transition(.scale(scale: 0.9, anchor: .bottomTrailing).combined(with: .opacity))
        case .text(let t):
            Text(t).font(.define).foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .offset(y: 6)))
        case .miss(let t):
            HStack(alignment: .top, spacing: 12) {
                KnightDoodle(pose: .slump, color: .ink, accent: .pen).frame(width: 52, height: 52)
                Text(t).font(.define).foregroundStyle(Color.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .offset(y: 6)))
        case .didYouMean(let s):
            VStack(alignment: .leading, spacing: 10) {
                Text("Not sure about that one. Did you mean:").font(.body).foregroundStyle(Color.ink2)
                FlowChips(items: s, style: .primary) { pick in Task { await follow(pick, asUser: false) } }
            }
        case .synonyms(let s):
            FlowChips(items: s, style: .quiet, staggered: !reduceMotion) { syn in Task { await follow(syn) } }
        case .loading:
            ThinkingKnight(reduceMotion: reduceMotion)
        case .end(let t):
            HStack(spacing: 8) {
                Image(systemName: "checkmark").font(.footnote.weight(.bold))
                Text(t).font(.footnote.weight(.medium))
            }
            .foregroundStyle(Color.ink2)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .transition(.opacity)
        }
    }

    // MARK: - dock: follow-ups carousel + the one primary action
    private var dock: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("Explain it differently") { await explain() }
                    chip("Use it in a sentence") { await sentence() }
                    chip("More synonyms") { await moreSynonyms() }
                }
                .padding(.horizontal, 16)
            }
            .disabled(busy || current == nil)
            .opacity(current == nil ? 0.5 : 1)

            HStack(spacing: 10) {
                Button { showLists = true } label: {
                    Label("Add to wordlist", systemImage: "text.badge.plus")
                        .font(.body.weight(.semibold)).foregroundStyle(Color.onPen)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.pen, in: Capsule())
                }
                .buttonStyle(PressStyle())
                .disabled(currentWord == nil)
                .opacity(currentWord == nil ? 0.5 : 1)

                Button { router.path = []; router.focusInput = true } label: {
                    Image(systemName: "checkmark").font(.title3.weight(.semibold)).foregroundStyle(Color.ink)
                        .frame(width: 50, height: 50).glassy(Circle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Look up a new word")
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8).padding(.bottom, 6)
        .background {
            LinearGradient(colors: [Color.sheet.opacity(0), Color.sheet, Color.sheet], startPoint: .top, endPoint: .bottom)
                .padding(.top, -20)
                .ignoresSafeArea()
        }
        .animation(anim(Motion.state), value: current == nil)
    }

    private func chip(_ title: String, _ action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Color.pen)
                .padding(.horizontal, 14).frame(minHeight: 40)
                .background(Color.penWash, in: Capsule())
        }
        .buttonStyle(PressStyle())
    }

    // MARK: - actions
    private func anim(_ a: Animation) -> Animation { reduceMotion ? .linear(duration: 0.12) : a }

    private func append(_ k: Message.Kind) {
        withAnimation(anim(Motion.reveal)) { messages.append(Message(kind: k)) }
    }
    private func dropLoading() { messages.removeAll { if case .loading = $0.kind { return true }; return false } }

    private func define(_ raw: String) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        busy = true; defer { busy = false }
        append(.loading)
        altsTried = 0; synonymsShown = 4

        // Already in the library → instant & offline.
        if let w = Word.find(text, in: context) {
            w.lastLookedUp = Date(); w.lookupCount += 1
            // Saved before pronunciation existed: fetch it once, capped at 2s so a slow or absent
            // network can't delay a word that's supposed to open instantly.
            if w.respelling == nil, let p = await Dictionary.pronunciation(for: text) {
                w.addTag("pron", p.respelling, in: context)
                if let a = p.audio { w.addTag("audio", a.absoluteString, in: context) }
            }
            let d = Definition(word: w.text, partOfSpeech: w.partOfSpeech, senses: [w.rawDefinition],
                               example: w.example, synonyms: w.synonyms,
                               respelling: w.respelling, audio: w.audioURL)
            finish(d, w)
            return
        }
        switch await Dictionary.lookup(text) {
        case .found(var d):
            d.word = text
            let simple = await Simplifier.simplify(d)
            let w = Word(text: text, partOfSpeech: d.partOfSpeech, definition: simple,
                         rawDefinition: d.senses.first ?? "", example: d.example)
            context.insert(w)
            w.addTag("pos", d.partOfSpeech, in: context)
            if let r = d.respelling { w.addTag("pron", r, in: context) }
            if let a = d.audio { w.addTag("audio", a.absoluteString, in: context) }
            for s in d.synonyms.prefix(12) { w.addTag("synonym", s, in: context) }
            finish(d, w)
        case .suggestions(let s):
            dropLoading(); append(.didYouMean(s))
        case .notFound:
            dropLoading(); append(.miss("I couldn't find \"\(text)\" anywhere. Try another spelling, or a different word."))
        case .offline:
            dropLoading(); append(.miss("You're offline — I can only show words already in your library right now."))
        }
    }

    private func finish(_ d: Definition, _ w: Word) {
        var d = d; d.simple = w.definition
        current = d; currentWord = w
        Speaker.shared.prefetch(d.audio)   // warm it while they read, so the tap plays instead of waiting
        if chain.last != d.word { withAnimation(anim(Motion.state)) { chain.append(d.word); chainSaved = false } }
        dropLoading(); append(.headword(d))
    }

    /// A synonym tap or a "did you mean" pick: continue in the same chat.
    private func follow(_ next: String, asUser: Bool = true) async {
        if asUser { append(.user(next)) }
        await define(next)
    }

    private func explain() async {
        guard let d = current else { return }
        append(.user("Explain it differently")); busy = true
        let t = await Simplifier.explainDifferently(d, tried: altsTried); altsTried += 1
        busy = false; append(.text(t))
    }

    private func sentence() async {
        guard let d = current else { return }
        append(.user("Use it in a sentence")); busy = true
        let t = await Simplifier.sentence(d)
        busy = false; append(.text(t))
    }

    private func moreSynonyms() async {
        guard let d = current, let w = currentWord else { return }
        append(.user("More synonyms")); busy = true
        var pool = d.synonyms
        if pool.count <= synonymsShown {
            let extra = await Dictionary.synonyms(for: d.word).filter { !pool.contains($0) && $0 != d.word }
            pool += extra
            for s in extra { w.addTag("synonym", s, in: context) }
            current?.synonyms = pool
        }
        busy = false
        let next = Array(pool.dropFirst(synonymsShown).prefix(6))
        if next.isEmpty { append(.end("That's everything I've got for \(d.word)")); return }
        synonymsShown += next.count
        append(.synonyms(next))   // tappable, so the chain can keep going
    }
}

// MARK: - loading: the knight thinks (jabs) while we look it up
private struct ThinkingKnight: View {
    let reduceMotion: Bool
    @State private var jab = false
    var body: some View {
        HStack(spacing: 12) {
            KnightDoodle(pose: jab ? .jab : .idle, color: .ink, accent: .pen)
                .frame(width: 52, height: 52)
                .animation(Motion.state, value: jab)
            Text("…").font(.title3.weight(.bold)).foregroundStyle(Color.ink2)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Color.penWash, in: Capsule())
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(420))
                jab.toggle()
            }
        }
        .accessibilityLabel("Looking it up")
        .transition(.opacity)
    }
}

// MARK: - the hero bubble
private struct HeadwordBubble: View {
    let definition: Definition
    let reduceMotion: Bool
    let onSynonym: (String) -> Void
    @State private var slash: CGFloat = 0
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(definition.word)
                        .font(.headword).foregroundStyle(Color.ink)
                    Text(definition.partOfSpeech).font(.pos).foregroundStyle(Color.ink2)
                }
                .accessibilityElement(children: .combine)
                // Rides the slash in with the headword rather than fading with the definition:
                // it's part of the word, not part of the answer.
                PronunciationLine(word: definition.word, respelling: definition.respelling, audio: definition.audio)
            }
            Text(simple).font(.define).foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 6)
            if !definition.synonyms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Similar").font(.caption.weight(.semibold)).foregroundStyle(Color.ink2)
                    FlowChips(items: Array(definition.synonyms.prefix(4)), style: .quiet, staggered: !reduceMotion, action: onSynonym)
                }
                .opacity(shown ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .slashReveal(slash, edge: .pen)   // the sword slash: the answer is cut into the page
        .task {
            if reduceMotion { slash = 1; shown = true; return }
            withAnimation(Motion.slash) { slash = 1 }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(Motion.reveal) { shown = true }
        }
    }

    private var simple: String { definition.simple ?? Simplifier.heuristic(definition.senses.first ?? "") }
}

/// Wrapping row of tappable chips. `.quiet` = synonym tags (low-priority), `.primary` = did-you-mean picks.
struct FlowChips: View {
    enum Style { case quiet, primary }
    let items: [String]
    var style: Style = .quiet
    var staggered = false
    let action: (String) -> Void
    @State private var visible = 0

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.element) { i, s in
                Button { action(s) } label: {
                    Text(s)
                        .font(style == .quiet ? .footnote : .subheadline.weight(.semibold))
                        .foregroundStyle(style == .quiet ? Color.ink2 : Color.pen)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(style == .quiet ? Color.clear : Color.penWash, in: Capsule())
                        .overlay(Capsule().strokeBorder(style == .quiet ? Color.rule : Color.clear))
                }
                .buttonStyle(PressStyle())
                .opacity(!staggered || i < visible ? 1 : 0)
                .accessibilityHint(style == .quiet ? "Define \(s) in this chat" : "")
            }
        }
        .task(id: items.count) {
            guard staggered else { return }
            for i in 0...min(items.count, 8) {   // cap the stagger at 8 × 40ms
                withAnimation(Motion.state) { visible = i + 1 }
                try? await Task.sleep(for: .milliseconds(40))
            }
            visible = items.count
        }
    }
}

/// Minimal wrapping layout (no dependency needed).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal.width ?? 0, subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, p) in arrange(bounds.width, subviews).points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }
    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var pts: [CGPoint] = []; var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            pts.append(CGPoint(x: x, y: y)); x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        return (CGSize(width: width, height: y + rowH), pts)
    }
}
