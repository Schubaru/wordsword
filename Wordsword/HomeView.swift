import SwiftUI
import SwiftData

/// The grab handle's row. Also the sheet's minimum presence on screen: when Home pushes the sheet
/// down to make room for the keyboard, this is what's left of it.
private let sheetGrabber: CGFloat = 27

/// Home = a sheet of ruled paper (the word of the day, and whatever else gets written on the page)
/// with a sheet you can pull up from the bottom. The sheet is where words are looked up: a search
/// field pinned at its top, your recent words under it. Natural-AI layout, wordsword content.
/// The mic in the search field listens for a spoken word instead (see `Voice.swift`).
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Word.lastLookedUp, order: .reverse) private var words: [Word]
    @State private var input = ""
    @State private var limit = 10
    /// Home is born expanded: the field is focused on launch, and the sheet is the search surface.
    @State private var expanded = true
    @State private var voice = VoiceListener()
    @State private var hint: String?
    @State private var hintOffersSettings = false
    @State private var alternates: [String] = []
    @State private var voiceText = ""          // what the mic put in the field; edits past this drop the chips
    @State private var hintTask: Task<Void, Never>?
    @State private var beat = 0
    @State private var beatKind = SensoryFeedback.warning
    /// The chain from the last lookup, re-read on every return to Home. Oldest first.
    @State private var trail: [String] = []
    @FocusState private var focused: Bool

    /// How much list shows under the search field at rest: the previous word and the next one down.
    /// A chain adds its "from …" line, so the peek grows with it rather than clipping that row out of
    /// view — and the whole number is scaled, so two rows stay two rows at accessibility sizes.
    @ScaledMetric(relativeTo: .body) private var rowsPeek: CGFloat = 100
    @ScaledMetric(relativeTo: .body) private var chainLine: CGFloat = 20

    /// College rule, scaled with the text size — the writing grows, so the lines it sits on grow with
    /// it. Everything written on the paper is a whole number of these.
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28
    /// The knight swings when you come back from a word you typed or said — not from a tap on a word
    /// you already had. Set on the way out, spent on the way home.
    @State private var swingOnReturn = false
    @State private var swing = 0
    /// Where the writing starts, in screen coordinates. The rules are phased to it rather than the
    /// content being nudged onto them: the paper moves by up to a line and nobody sees it, whereas
    /// moving the writing would show.
    @State private var gridTop: CGFloat = 0
    /// The day the word-of-the-day banner was put away (✕, a flick up, or a tap that looked it up).
    /// It comes back with the next day's word.
    @AppStorage("wotd.dismissedOn") private var wotdDismissedOn = ""
    /// Today, re-read whenever the app comes back, so a banner put away last night returns this morning.
    @State private var day = Self.today
    /// The banner slides in once Home is up, not on the tick it's inserted under the splash.
    @State private var bannerIn = false
    @State private var bannerHeight: CGFloat = 0
    private var showBanner: Bool { bannerIn && wotdDismissedOn != day }
    private var sheetPeek: CGFloat { trail.count > 1 ? rowsPeek + chainLine : rowsPeek }

    /// 0 → typing, 1 → mic committed. Everything that recedes for voice reads this directly, so the
    /// whole transition tracks the finger instead of snapping when a timer fires.
    private var toVoice: CGFloat { voice.hold }

    /// Two strings share the input slot and the line below it. Fading them linearly leaves both
    /// half-lit on top of each other in the middle of every hold, so they dissolve out of phase:
    /// the old one is gone before the new one starts.
    private func fadeOut(_ t: CGFloat, by end: CGFloat = 0.4) -> Double { Double(1 - min(1, t / end)) }
    private func fadeIn(_ t: CGFloat, from start: CGFloat = 0.55) -> Double {
        Double(max(0, (t - start) / (1 - start)))
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            ZStack(alignment: .top) {
                PaperBackground(spacing: rule, topInset: gridTop.truncatingRemainder(dividingBy: rule) - rule)
                    .contentShape(Rectangle())
                    .onTapGesture { focused = false }
                    .ignoresSafeArea(.keyboard)

                VStack(alignment: .leading, spacing: 0) {
                    // Under the banner the header is hidden, not just covered: the knight's plume
                    // rides above his frame and would peek over the banner's edge.
                    header.opacity(showBanner ? 0 : 1 - 0.85 * toVoice)
                        .allowsHitTesting(!showBanner)
                    paperContent
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { gridTop = $0 }
                        // Clear of the banner too, when it's floating over the header (52pt tall).
                        .padding(.top, showBanner ? max(16, 8 + bannerHeight + 12 - 52) : 16)
                        .opacity(fadeOut(toVoice))
                        .allowsHitTesting(toVoice == 0)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)

                // The sheet holds the search: the field is pinned under the grabber and the list
                // scrolls beneath it. It rides above the keyboard on its own (the container shrinks),
                // so typing never has to push it out of the way.
                // While the banner floats over the header the expanded sheet starts under it, so the
                // search field is never covered; it rises back when the banner goes.
                BottomSheet(expanded: $expanded, peek: sheetPeek,
                            top: showBanner ? max(72, 8 + bannerHeight + 12) : 72) {
                    searchBlock
                } content: {
                    sheetContent
                        // Voice gets the sheet: the list recedes and only the field and its line stay.
                        .opacity(1 - toVoice)
                        .allowsHitTesting(toVoice == 0)
                } onGrab: {
                    // Reaching for the handle IS the request to stop typing.
                    focused = false
                }

                if showBanner {
                    wordOfTheDay
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bannerHeight = $0 }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .opacity(fadeOut(toVoice))
                        .allowsHitTesting(toVoice == 0)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .define(let w):        DefineView(word: w).id(w)   // fresh chat per word, even on in-place route swaps (deep links)
                case .resume(let saved):    DefineView(word: saved.last ?? "", trail: saved).id(saved.joined(separator: ">"))
                case .library:              LibraryView()
                case .wordlist(let id):     WordlistDetailView(listID: id)
                case .flashcards(let id):   FlashcardsView(listID: id)
                case .settings:             SettingsView()
                case .games:                GamesHubView()
                case .wordWheel:            WordWheelView()
                case .linkingWords:         LinkingWordsView()
                case .wordsFound:           WordsFoundView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        // The search is the home page, so it opens with the keyboard already up. Focus can't be taken
        // on the tick the view is inserted — the assignment is silently dropped and the keyboard never
        // comes up — so wait out the splash's reveal first. Same reason as AccountFlow's step focus.
        .task {
            trail = LastSearch.chain
            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }
            router.focusInput = false      // a deep link that landed before Home existed is satisfied here
            focused = true
            withAnimation(reduceMotion ? nil : Motion.sheet) { bannerIn = true }
        }
        .onChange(of: router.focusInput) { _, f in if f { router.focusInput = false; raiseKeyboard() } }
        .onChange(of: router.path) { _, p in
            if p.isEmpty {
                if swingOnReturn {
                    swingOnReturn = false
                    // Wait out the pop so the swing lands on a page that's already there.
                    if !reduceMotion { Task { try? await Task.sleep(for: .milliseconds(320)); swing += 1 } }
                }
                input = ""; alternates = []; clearHint()
                withAnimation(reduceMotion ? nil : Motion.state) { trail = LastSearch.chain }
                // Back from a definition with no keyboard: the page, with the sheet at rest.
                withAnimation(reduceMotion ? nil : Motion.sheet) { expanded = false }
            }
        }
        // Typing opens the sheet all the way, whichever way focus arrived (a tap on the field, a deep
        // link, a voice miss): the field moves up under the header and the list fills what's left
        // above the keyboard. Losing focus leaves the sheet where it is — a scroll that dismissed
        // the keyboard mid-list must not snap the list away from under the finger; the handle is
        // how the sheet goes down.
        .onChange(of: focused) { _, f in if f { withAnimation(reduceMotion ? nil : Motion.sheet) { expanded = true } } }
        .onChange(of: input) { _, v in
            if !alternates.isEmpty, v != voiceText { withAnimation(Motion.state) { alternates = [] } }
        }
        // A call, or the app going away mid-listen: drop the mic, navigate nowhere.
        // Back after midnight: a new day, so tomorrow's banner is today's.
        .onChange(of: scenePhase) { _, p in
            if p != .active { voice.abort() } else { withAnimation(reduceMotion ? nil : Motion.sheet) { day = Self.today } }
        }
        .onDisappear { voice.abort() }
        // The keyboard leaves only when the mic actually commits.
        .onChange(of: voice.live) { _, live in if live { focused = false } }
        .sensoryFeedback(trigger: voice.live) { _, live in live ? .impact(flexibility: .soft) : nil }
        .sensoryFeedback(trigger: beat) { _, _ in beatKind }
        #if DEBUG
        .onChange(of: router.debug) { _, d in
            switch d {
            case "voice:idle":      voice.debugPose(hold: 0); clearHint(); alternates = []; input = ""
            case "voice:arming":    voice.debugPose(hold: 0.45); focused = false
            case "voice:listening": voice.debugPose(hold: 1, loud: true); focused = false
            case "voice:speaking":  voice.debugPose(hold: 1, heard: "ephemeral", loud: true); focused = false
            case "voice:settled":   voice.debugPose(hold: 1, heard: "ephemeral", settled: true, loud: true); focused = false
            case "voice:uncertain": voice.debugPose(hold: 0); handle(.uncertain("cognitive dissonance", ["cognitive", "dissonance", "dissonant"]))
            case "voice:nothing":   voice.debugPose(hold: 0); input = ""; handle(.nothing)
            case "voice:denied":    voice.debugPose(hold: 0); input = ""; handle(.blocked(.micOff))
            default: break
            }
        }
        #endif
    }

    // MARK: header — the knight, library, settings
    private var header: some View {
        HStack {
            KnightMark(swing: swing).frame(width: 44, height: 44)
            Spacer()
            GlassIcon("books.vertical", "Library") { router.path.append(.library) }
            GlassIcon("gearshape", "Settings") { router.path.append(.settings) }
        }
        .padding(.top, 8)
    }

    // MARK: the paper — what's written on the page under the header
    /// The search moved into the sheet and the word of the day floats above as a banner, so the page
    /// opens on the games. Rows go on the grid with `.onRule(_:spacing: rule)`. One block, not a
    /// group: the padding and the grid probe hung on it must land on the whole column, or each row
    /// gets its own padding and the rules phase to the last one.
    private var paperContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            GamesEntry(rule: rule)
        }
    }

    // MARK: the search — pinned at the top of the sheet. The whole point of the home page.
    /// The field, then whatever it has to say: the listening line, a voice hint, did-you-mean.
    /// At rest that's nothing — the recent words start right under the field.
    private var searchBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
            caption
            if !alternates.isEmpty { didYouMean.padding(.top, 10).padding(.bottom, 6) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
    }

    /// A search field at the system's size: body type, `sheet` fill with the 1pt `rule` edge every
    /// container wears, and the edge turns `pen` while the field has focus — pen marks focus,
    /// nothing else does. No submit button: the keyboard's "go" already does it. Trailing is the mic
    /// while the field is empty and the clear button once it isn't, like the system search bar.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.body).foregroundStyle(Color.ink2)
                .accessibilityHidden(true)
            inputLine
            if input.isEmpty {
                micButton.transition(.opacity)
            } else {
                Button {
                    input = ""; alternates = []
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.body).foregroundStyle(Color.ink2)
                        .frame(width: 36, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
                .transition(.opacity)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(minHeight: 44)
        .background {
            Capsule().fill(Color.sheet)
                .overlay {
                    Capsule()
                        .strokeBorder(focused ? Color.pen : Color.rule, lineWidth: 1)
                }
        }
        .animation(reduceMotion ? nil : Motion.state, value: focused)
        .animation(reduceMotion ? nil : Motion.state, value: input.isEmpty)
    }

    /// Word of the day, floating over the header (`WordOfTheDayBanner`). The meaning comes from your
    /// library when you've looked the word up before, so a known word never costs a fetch. A tap is
    /// a search like any typed word (the knight swings on the way back), and puts the banner away.
    private var wordOfTheDay: some View {
        let word = WordOfTheDay.today
        return WordOfTheDayBanner(word: word,
                                  known: words.first { $0.text.caseInsensitiveCompare(word) == .orderedSame }?.definition) {
            swingOnReturn = true
            router.path.append(.define(word))
            wotdDismissedOn = day
        } dismiss: {
            withAnimation(reduceMotion ? nil : Motion.sheet) { wotdDismissedOn = day }
        }
        .id(word)       // a new day is a new word
    }

    private static var today: String { Date.now.formatted(.iso8601.year().month().day()) }

    /// The system search bar's type: body, regular. A long phrase scrolls inside the field.
    private let inputFont = Font.body

    private var inputLine: some View {
        ZStack(alignment: .leading) {
            // The placeholder crossfades rather than swapping, so the line never blinks empty.
            if input.isEmpty, voice.heard.isEmpty {
                Text("type a word").font(inputFont).foregroundStyle(Color.ink2.opacity(0.8))
                    .opacity(fadeOut(toVoice))
                Text("say a word").font(inputFont).foregroundStyle(Color.ink2.opacity(0.8))
                    .opacity(fadeIn(toVoice))
            }
            TextField("", text: $input)
                .font(inputFont).foregroundStyle(Color.ink)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focused)
                .onSubmit(go)
                .opacity(fadeOut(toVoice))
                .accessibilityLabel("Word to define")
            // What the mic has so far, in the same hand as the typed line. Grey while it's still a
            // guess, ink once the recogniser commits — the ink firming up is the "I got that" cue.
            if !voice.heard.isEmpty {
                Text(voice.heard)
                    .font(inputFont).foregroundStyle(voice.settled ? Color.ink : Color.ink2)
                    .lineLimit(1).minimumScaleFactor(0.55)
                    .opacity(fadeIn(toVoice))
                    .animation(reduceMotion ? nil : Motion.feedback, value: voice.settled)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .animation(reduceMotion ? nil : Motion.state, value: input.isEmpty)
    }

    /// Tap to speak; tap again when you're done (or just stop talking). Pen while it's listening —
    /// pen marks the live thing, the same way it marks the focused field.
    private var micButton: some View {
        Button {
            if toVoice > 0 { voice.finish() } else { listen() }
        } label: {
            Image(systemName: toVoice > 0 ? "mic.fill" : "mic")
                .font(.body).foregroundStyle(toVoice > 0 ? Color.pen : Color.ink2)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(toVoice > 0 ? "Stop listening" : "Speak a word")
    }

    /// What the field has to say, under it. Listening, it's the pen line that moves with your voice
    /// plus a caption that says so — motion is never the only signal the mic is live. A voice miss or
    /// a blocked mic puts its hint here for a few seconds. At rest it's nothing at all.
    @ViewBuilder private var caption: some View {
        if toVoice > 0 {
            VStack(alignment: .leading, spacing: 4) {
                ListeningRule(levels: voice.levels, draw: reduceMotion ? 1 : CGFloat(fadeIn(toVoice, from: 0.35)))
                    .doodle(.pen, width: 2)
                    .frame(height: 22)        // a Shape is greedy; pin it or it grows the whole row
                    .opacity(fadeIn(toVoice, from: 0.35))
                Text("Listening — tap the mic when you're done")
                    .font(.caption).foregroundStyle(Color.ink2)
                    .opacity(fadeIn(toVoice))
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .transition(.opacity)
        } else if let hint {
            // Side by side while it fits; stacked once the text size says it doesn't.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) { hintText(hint); settingsLink }
                VStack(alignment: .leading, spacing: 4) { hintText(hint); settingsLink }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .transition(.opacity)
        }
    }

    private func hintText(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(Color.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var settingsLink: some View {
        if hintOffersSettings {
            Button("Open Settings", action: openSettings)
                .font(.footnote.weight(.semibold)).foregroundStyle(Color.pen)
                .fixedSize()
        }
    }

    /// Speech that didn't come back as one clean word: the text lands in the input, and whatever
    /// else was in there is offered rather than guessed at. Same language as the chat's did-you-mean.
    private var didYouMean: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Not sure I caught that. Did you mean:").font(.body).foregroundStyle(Color.ink2)
            FlowChips(items: alternates, style: .primary) { pick in
                input = pick
                alternates = []
                go()
            }
        }
        .transition(.opacity.combined(with: .offset(y: 6)))
    }

    // MARK: - keyboard
    // The sheet sits above the keyboard by itself (its container shrinks with it), so there is no
    // choreography left: focus the field, and `onChange(of: focused)` opens the sheet with it.
    private func raiseKeyboard() { focused = true }

    private func go() {
        let w = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else { return }
        alternates = []
        swingOnReturn = true
        router.path.append(.define(w))
    }

    // MARK: - voice
    /// The mic button. Listens until you stop talking or tap it again.
    private func listen() {
        guard toVoice == 0 else { return }
        clearHint()
        withAnimation(Motion.state) { alternates = [] }
        focused = false
        Task {
            UIAccessibility.post(notification: .announcement, argument: "Listening")
            handle(await voice.listenHandsFree())
        }
    }

    private func handle(_ outcome: VoiceOutcome) {
        switch outcome {
        case .cancelled:
            break                                           // stopped before the mic came up
        case .word(let w):
            pulse(.impact(flexibility: .rigid))
            input = ""
            swingOnReturn = true
            router.path.append(.define(w))
            return                                          // the chat takes over; nothing to type into here
        case .uncertain(let text, let picks):
            pulse(.warning)
            voiceText = text
            input = text
            withAnimation(Motion.state) { alternates = picks }
            UIAccessibility.post(notification: .announcement, argument: "Heard \(text). Check it, or pick another.")
        case .nothing:
            pulse(.warning)
            show("Didn't catch that — tap the mic and speak a little closer.")   // wraps to two lines on narrow screens
        case .blocked(let b):
            pulse(.warning)
            show(b.message, settings: b.offersSettings)
        }
        // Every outcome that stays on this screen hands the line back, keyboard and all. Without this,
        // a denied mic left the input looking live with no way to type into it.
        raiseKeyboard()
    }

    private func show(_ text: String, settings: Bool = false) {
        hintTask?.cancel()
        withAnimation(Motion.state) { hint = text; hintOffersSettings = settings }
        UIAccessibility.post(notification: .announcement, argument: text)
        hintTask = Task {
            try? await Task.sleep(for: .seconds(settings ? 8 : 3.4))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.state) { hint = nil; hintOffersSettings = false }
        }
    }

    private func clearHint() {
        hintTask?.cancel()
        hint = nil
        hintOffersSettings = false
    }

    private func pulse(_ kind: SensoryFeedback) { beatKind = kind; beat += 1 }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: the sheet — recent words under the search, where you left off first
    @ViewBuilder private var sheetContent: some View {
        history
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 40)
    }

    private func accessibleTrail(_ last: String) -> String {
        trail.count > 1
            ? "Your previous word: \(last), from \(trail.dropLast().joined(separator: ", "))"
            : "Your previous word: \(last)"
    }

    /// Newest first, minus the newest itself — that one is the first row, and repeating it a row
    /// later just reads as a duplicate. Matched by word rather than dropping the first row, so an
    /// empty trail (nothing to resume) still lists everything.
    private var recent: [Word] {
        words.filter { $0.text.caseInsensitiveCompare(trail.last ?? "") != .orderedSame }
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
            .padding(.top, 16)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Where the last lookup stopped, as the first row: same row as every other word, plus
                // the chain it came from when there is one. Tapping it reopens that chat with the whole
                // trail restored, so `sanguine › optimistic › rosy` comes back as those three tokens
                // with `rosy` current — the breadcrumb the user left, not a fresh lookup.
                if let last = trail.last {
                    wordRow(last, words.first { $0.text.caseInsensitiveCompare(last) == .orderedSame },
                            // Truncated from the head: the words nearest this one are the ones that explain it.
                            subline: trail.count > 1 ? "from " + trail.dropLast().joined(separator: " › ") : nil) {
                        router.path.append(.resume(trail))
                    }
                    .accessibilityLabel(accessibleTrail(last))
                    .accessibilityHint("Opens where you left off")
                }
                ForEach(recent.prefix(limit)) { w in
                    wordRow(w.text, w) { router.path.append(.define(w.text)) }
                        .onAppear { if w == recent.prefix(limit).last, limit < recent.count { limit += 10 } }
                }
                allWords
            }
        }
    }

    /// One recent word: the word, its part of speech, and the start of its definition pushed to the
    /// trailing edge. `record` is nil only when a word in the trail never made it into the library.
    private func wordRow(_ text: String, _ record: Word?, subline: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(text).font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Color.ink)
                    if let record {
                        Text(record.partOfSpeech).font(.caption).foregroundStyle(Color.ink2)
                        Spacer(minLength: 8)
                        Text(record.definition).font(.subheadline).foregroundStyle(Color.ink2)
                            .lineLimit(1).frame(maxWidth: 170, alignment: .trailing)
                    } else {
                        Spacer(minLength: 8)
                    }
                }
                if let subline {
                    Text(subline).font(.footnote).foregroundStyle(Color.ink2)
                        .lineLimit(1).truncationMode(.head)
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The list's last line, not a control sitting above it: same left edge, same rhythm, one step
    /// quieter than a word. The count is of everything, the previous word included, because "all" means all.
    private var allWords: some View {
        Button { router.path.append(.wordlist(nil)) } label: {
            HStack(spacing: 6) {
                Text("All ^[\(words.count) word](inflect: true)")
                    .font(.subheadline.weight(.medium)).foregroundStyle(Color.pen)
                Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(Color.ink2)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens your full word list")
    }
}

// MARK: - Bottom sheet (Natural-style): peeks at the bottom, drag up to expand, scrolls when expanded.
/// `pinned` sits under the grabber and never scrolls — the search field lives there; `content` is
/// the list beneath it. `peek` is how much of the *content* shows at rest; the grabber and the
/// pinned block are measured and always show.
struct BottomSheet<Pinned: View, Content: View>: View {
    @Binding var expanded: Bool
    var peek: CGFloat
    /// Where the expanded sheet's top edge stops, below the top safe area: just under the header.
    var top: CGFloat = 72
    @ViewBuilder var pinned: Pinned
    @ViewBuilder var content: Content
    /// The handle was touched — dragged or tapped. Either way the user is done with the keyboard.
    var onGrab: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var drag: CGFloat = 0
    @State private var dragging = false
    @State private var pinnedHeight: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            let h = g.size.height
            let fullH = h - top
            let rest = sheetGrabber + pinnedHeight + peek         // what shows at rest
            let restY = expanded ? h - fullH : h - rest           // top edge of the sheet
            let y = clamp(restY + drag, lower: h - fullH - 24, upper: max(h - 56, restY))

            VStack(spacing: 0) {
                Capsule().fill(Color.rule).frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity, minHeight: sheetGrabber)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(h: h, fullH: fullH))
                    .accessibilityLabel(expanded ? "Collapse" : "Expand")
                    .accessibilityAddTraits(.isButton)
                    .onTapGesture { onGrab(); withAnimation(anim) { expanded.toggle() } }
                pinned
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pinnedHeight = $0 }
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
                    .offset(y: rest - 72)
                    .opacity(expanded || dragging || peek < 72 ? 0 : 1)
                    .allowsHitTesting(false)
            }
            .offset(y: y)
            .simultaneousGesture(dragGesture(h: h, fullH: fullH), including: expanded ? .subviews : .all)
            .animation(dragging ? nil : anim, value: y)
            .animation(anim, value: rest)
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
                if !dragging { dragging = true; onGrab() }
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
