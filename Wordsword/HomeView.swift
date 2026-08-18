import SwiftUI
import SwiftData

/// Home = a sheet of ruled paper with one giant ghost input, and a sheet you can pull up for what you already know
/// (word of the day, recent words). Natural-AI layout, wordsword content.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Word.lastLookedUp, order: .reverse) private var words: [Word]
    @State private var input = ""
    @State private var limit = 10
    @State private var expanded = false
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            ZStack(alignment: .top) {
                PaperBackground()
                    .contentShape(Rectangle())
                    .onTapGesture { focused = false }
                    .ignoresSafeArea(.keyboard)

                VStack(alignment: .leading, spacing: 0) {
                    header
                    ghostInput.padding(.top, 64)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)

                BottomSheet(expanded: $expanded, peek: focused ? 140 : 220) {
                    sheetContent
                } onDragBegan: { focused = false }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .define(let w):        DefineView(word: w).id(w)   // fresh chat per word, even on in-place route swaps (deep links)
                case .library:              LibraryView()
                case .wordlist(let id):     WordlistDetailView(listID: id)
                case .flashcards(let id):   FlashcardsView(listID: id)
                case .settings:             SettingsView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { focused = true }
        .onChange(of: router.focusInput) { _, f in if f { focused = true; router.focusInput = false } }
        .onChange(of: router.path) { _, p in if p.isEmpty { input = "" } }
        .onChange(of: focused) { _, f in if f { withAnimation(Motion.sheet) { expanded = false } } }
    }

    // MARK: header — wordmark, library, settings
    private var header: some View {
        HStack {
            Wordmark()
            Spacer()
            iconButton("books.vertical", "Library") { router.path.append(.library) }
            iconButton("gearshape", "Settings") { router.path.append(.settings) }
        }
        .padding(.top, 8)
    }

    private func iconButton(_ name: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.title3.weight(.medium)).foregroundStyle(Color.ink)
                .frame(width: 44, height: 44)
                .glassy(Circle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }

    // MARK: the input — giant ghost text on the paper, no box. The whole point of the home page.
    private var ghostInput: some View {
        HStack(alignment: .center, spacing: 12) {
            TextField("", text: $input, prompt: Text("type a word").foregroundStyle(Color.ink2.opacity(0.8)))
                .font(.ghost).foregroundStyle(Color.ink)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focused)
                .onSubmit(go)
                .accessibilityLabel("Word to define")
            if !input.isEmpty {
                Button(action: go) {
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 36)).foregroundStyle(Color.pen)
                }
                .buttonStyle(PressStyle())
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .accessibilityLabel("Define \(input)")
            }
        }
        .animation(reduceMotion ? nil : Motion.state, value: input.isEmpty)
    }

    private func go() {
        let w = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else { return }
        router.path.append(.define(w))
    }

    // MARK: the sheet — word of the day, then recent words
    @ViewBuilder private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            wordOfTheDay
            history
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private var wordOfTheDay: some View {
        Button { router.path.append(.define(WordOfTheDay.today)) } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Word of the day").font(.subheadline.weight(.medium)).foregroundStyle(Color.pen)
                    Text(WordOfTheDay.today).font(.system(.title, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                }
                Spacer()
                Image(systemName: "arrow.right").font(.body.weight(.semibold)).foregroundStyle(Color.pen)
            }
            .padding(18)
            // A scrap of the same ruled paper, lying on the sheet: the card is the page, not a tint.
            .background {
                Paper(page: .sheet, rule: .paperRule, margin: .clear, spacing: 22, fillsSafeArea: false)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.rule, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(SurfacePressStyle(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)))
        .accessibilityLabel("Word of the day: \(WordOfTheDay.today)")
    }

    @ViewBuilder private var history: some View {
        if words.isEmpty {
            HStack(alignment: .top, spacing: 14) {
                KnightDoodle(pose: .idle, color: .ink, accent: .pen).frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your words will collect here.").font(.body.weight(.medium)).foregroundStyle(Color.ink)
                    Text("Every word you look up is saved to All — no more losing them in your search history.")
                        .font(.subheadline).foregroundStyle(Color.ink2)
                }
            }
            .padding(.top, 4)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Recent").font(.headline).foregroundStyle(Color.ink)
                    Spacer()
                    Button("All \(words.count)") { router.path.append(.wordlist(nil)) }
                        .font(.subheadline.weight(.medium))
                }
                .padding(.bottom, 8)
                ForEach(words.prefix(limit)) { w in
                    Button { router.path.append(.define(w.text)) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(w.text).font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Color.ink)
                            Text(w.partOfSpeech).font(.caption).foregroundStyle(Color.ink2)
                            Spacer(minLength: 8)
                            Text(w.definition).font(.subheadline).foregroundStyle(Color.ink2)
                                .lineLimit(1).frame(maxWidth: 170, alignment: .trailing)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .ruled()
                    .onAppear { if w == words.prefix(limit).last, limit < words.count { limit += 10 } }
                }
            }
        }
    }
}

// MARK: - Bottom sheet (Natural-style): peeks at the bottom, drag up to expand, scrolls when expanded.
struct BottomSheet<Content: View>: View {
    @Binding var expanded: Bool
    var peek: CGFloat
    @ViewBuilder var content: Content
    var onDragBegan: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var drag: CGFloat = 0
    @State private var dragging = false

    var body: some View {
        GeometryReader { g in
            let h = g.size.height
            let fullH = h - 72
            let restY = expanded ? h - fullH : h - peek          // top edge of the sheet
            let y = clamp(restY + drag, lower: h - fullH - 24, upper: h - 56)

            VStack(spacing: 0) {
                Capsule().fill(Color.rule).frame(width: 40, height: 5)
                    .padding(.top, 10).padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(h: h, fullH: fullH))
                    .accessibilityLabel(expanded ? "Collapse" : "Expand")
                    .accessibilityAddTraits(.isButton)
                    .onTapGesture { withAnimation(anim) { expanded.toggle() } }
                ScrollView {
                    content
                }
                .scrollDisabled(!expanded)
                .scrollDismissesKeyboard(.interactively)
            }
            .frame(height: fullH + 24, alignment: .top)
            .frame(maxWidth: .infinity)
            .sheetSurface(corners: [.topLeft, .topRight])
            .overlay(alignment: .top) {
                // Fade-out at the peek edge (Natural's "there's more below" cue). Gone once expanded.
                LinearGradient(colors: [Color.sheet.opacity(0), Color.sheet], startPoint: .top, endPoint: .bottom)
                    .frame(height: 72)
                    .offset(y: peek - 72)
                    .opacity(expanded || dragging ? 0 : 1)
                    .allowsHitTesting(false)
            }
            .offset(y: y)
            .simultaneousGesture(dragGesture(h: h, fullH: fullH), including: expanded ? .subviews : .all)
            .animation(dragging ? nil : anim, value: y)
            .animation(anim, value: peek)
        }
        .ignoresSafeArea(.container, edges: .bottom)   // sit on the screen edge, but still rise above the keyboard
    }

    private var anim: Animation? { reduceMotion ? .linear(duration: 0.12) : Motion.sheet }

    private func dragGesture(h: CGFloat, fullH: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($drag) { v, s, _ in
                s = v.translation.height
            }
            .onChanged { _ in
                if !dragging { dragging = true; onDragBegan() }
            }
            .onEnded { v in
                dragging = false
                let projected = v.predictedEndTranslation.height
                withAnimation(anim) {
                    if projected < -60 { expanded = true } else if projected > 60 { expanded = false }
                }
            }
    }

    private func clamp(_ x: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat { min(max(x, lower), upper) }
}
