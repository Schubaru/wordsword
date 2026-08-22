import SwiftUI
import SwiftData

/// The grab handle's row. Also the sheet's minimum presence on screen: when Home pushes the sheet
/// down to make room for the keyboard, this is what's left of it.
private let sheetGrabber: CGFloat = 27

/// Home = a sheet of ruled paper with one giant ghost input, and a sheet you can pull up for what you already know
/// (word of the day, recent words). Natural-AI layout, wordsword content.
/// The input line does double duty: tap it to type, hold it to speak (see `Voice.swift`).
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Word.lastLookedUp, order: .reverse) private var words: [Word]
    @State private var input = ""
    @State private var limit = 10
    @State private var expanded = false
    @State private var sheetDown = false       // keyboard territory: only the grabber left on screen
    @State private var voice = VoiceListener()
    @State private var hint: String?
    @State private var hintOffersSettings = false
    @State private var alternates: [String] = []
    @State private var voiceText = ""          // what the mic put in the field; edits past this drop the chips
    @State private var pressing = false
    @State private var hintTask: Task<Void, Never>?
    @State private var beat = 0
    @State private var beatKind = SensoryFeedback.warning
    /// The chain from the last lookup, re-read on every return to Home. Oldest first.
    @State private var trail: [String] = []
    @FocusState private var focused: Bool

    /// The previous-word card plus the first recent word, at rest. A chain adds its "from …" line,
    /// so the peek grows with it rather than clipping that row out of view — and the whole number is
    /// scaled, because at accessibility sizes the card alone is taller than a fixed 220 ever was.
    @ScaledMetric(relativeTo: .body) private var peekBase: CGFloat = 220

    /// College rule, scaled with the text size — the writing grows, so the lines it sits on grow with
    /// it. Everything in the writing block is a whole number of these.
    @ScaledMetric(relativeTo: .body) private var rule: CGFloat = 28
    /// Where the writing starts, in screen coordinates. The rules are phased to it rather than the
    /// content being nudged onto them: the paper moves by up to a line and nobody sees it, whereas
    /// moving the input would show.
    @State private var gridTop: CGFloat = 0
    /// The previous-word card writes on the same paper at a smaller rule, inset by `cardPad` — which
    /// doubles as the phase, so line one lands on rule one.
    @ScaledMetric(relativeTo: .body) private var cardRule: CGFloat = 22
    private let cardPad: CGFloat = 18
    private var sheetPeek: CGFloat { trail.count > 1 ? peekBase + 20 : peekBase }

    /// Down leaves exactly the grab handle, which ends up sitting on the keyboard's top edge —
    /// enough to say the drawer is still there, little enough to stay out of the way.
    private var sheetOffset: CGFloat { sheetDown ? sheetPeek - sheetGrabber : 0 }

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
                    header.opacity(1 - 0.85 * toVoice)
                    ghostInput
                        .background(GeometryReader { g in
                            Color.clear.preference(key: GridTop.self, value: g.frame(in: .global).minY)
                        })
                        .padding(.top, 64)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .onPreferenceChange(GridTop.self) { gridTop = $0 }

                BottomSheet(expanded: $expanded, peek: sheetPeek) {
                    sheetContent
                } onGrab: {
                    // Reaching for the handle IS the request to stop typing: the sheet comes back
                    // with the finger rather than 200ms behind it.
                    focused = false
                    withAnimation(reduceMotion ? nil : Motion.sheet) { sheetDown = false }
                }
                    .opacity(1 - toVoice)
                    .offset(y: 160 * toVoice + sheetOffset)
                    .allowsHitTesting(toVoice == 0)
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .define(let w):        DefineView(word: w).id(w)   // fresh chat per word, even on in-place route swaps (deep links)
                case .resume(let saved):    DefineView(word: saved.last ?? "", trail: saved).id(saved.joined(separator: ">"))
                case .library:              LibraryView()
                case .wordlist(let id):     WordlistDetailView(listID: id)
                case .flashcards(let id):   FlashcardsView(listID: id)
                case .settings:             SettingsView()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        // The input is the home page, so it opens with the keyboard already up. Focus can't be taken
        // on the tick the view is inserted — the assignment is silently dropped and the keyboard never
        // comes up — so wait out the splash's reveal first. Same reason as AccountFlow's step focus.
        .task {
            trail = LastSearch.chain
            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }
            router.focusInput = false      // a deep link that landed before Home existed is satisfied here
            sheetDown = true               // unanimated: it was never on screen to slide off it
            focused = true
        }
        .onChange(of: router.focusInput) { _, f in if f { router.focusInput = false; raiseKeyboard() } }
        .onChange(of: router.path) { _, p in
            if p.isEmpty {
                input = ""; alternates = []; clearHint()
                withAnimation(reduceMotion ? nil : Motion.state) { trail = LastSearch.chain }
                // Back from a definition with no keyboard: the sheet is what you want to see next.
                withAnimation(reduceMotion ? nil : Motion.sheet) { sheetDown = false }
            }
        }
        .onChange(of: focused) { _, f in if !f { returnSheet() } }
        .onChange(of: input) { _, v in
            if !alternates.isEmpty, v != voiceText { withAnimation(Motion.state) { alternates = [] } }
        }
        // A call, or the app going away mid-hold: drop the mic, navigate nowhere.
        .onChange(of: scenePhase) { _, p in if p != .active { pressing = false; voice.abort() } }
        .onDisappear { voice.abort() }
        // The keyboard stays up through the whole arm: a press that turns out to be a tap must not
        // cost the user their keyboard. It leaves only when the mic actually commits.
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
        // Spacing 0: the caption already reserves a row for "Listening — release to define", so the
        // two items below set their own gap rather than inheriting one on top of that reserved space.
        // Rules, not gaps: every row below is a whole number of college rules tall with its baseline
        // on the rule that closes it, so the block reads as writing on the page rather than floating
        // over it. Spacing stays 0 — the rows already carry their own height.
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                inputLine.onRule(2, spacing: rule)
                caption
            }
            .overlay { holdCatcher }
            // The chips and the suggestion want the same slot, and the chips are the live task.
            if alternates.isEmpty {
                wordOfTheDay
                    .opacity(fadeOut(toVoice))
                    .allowsHitTesting(toVoice == 0)
            } else {
                didYouMean.padding(.top, 14)
            }
        }
    }

    /// Word of the day: a suggestion, not a task, so it stays at footnote weight and reads *after*
    /// "Hold to speak" rather than over it. The wash is what gives it an edge on a page with no other
    /// fills — a scrap laid on the paper, resting on a rule — and it's `pen` at 10%, so it's grey on
    /// white and grey on black instead of a colour that only works in one of them. Still no arrow and
    /// no solid fill: those belong to actions.
    private var wordOfTheDay: some View {
        Button { router.path.append(.define(WordOfTheDay.today)) } label: {
            // Side by side while it fits; stacked once the text size says it doesn't.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 7) { wotdLabel; wotdWord }
                VStack(alignment: .leading, spacing: 3) { wotdLabel; wotdWord }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.penWash))
            // The chip is small; the target isn't. Two rules tall with the chip sitting on the lower
            // one, so the 44pt grows up into blank page instead of lifting the chip off the line.
            .frame(height: 2 * rule, alignment: .bottom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Word of the day: \(WordOfTheDay.today)")
    }

    private var wotdLabel: some View {
        Text("Word of the day").font(.footnote).foregroundStyle(Color.ink2)
    }

    private var wotdWord: some View {
        Text(WordOfTheDay.today)
            .font(.system(.footnote, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.ink)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.ink2).frame(height: 1).offset(y: 3)
            }
    }

    /// One line, always legible: past ~11 characters the ghost type steps down rather than letting the
    /// field scroll its own beginning out of view.
    private var inputFont: Font {
        switch max(input.count, voice.heard.count) {
        case 17...: .system(size: 26, weight: .bold, design: .rounded)
        case 12...: .system(size: 31, weight: .bold, design: .rounded)
        default:    .ghost
        }
    }

    private var inputLine: some View {
        ZStack(alignment: .leading) {
            // The placeholder crossfades rather than swapping, so the line never blinks empty.
            if input.isEmpty, voice.heard.isEmpty {
                Text("type a word").font(.ghost).foregroundStyle(Color.ink2.opacity(0.8))
                    .opacity(fadeOut(toVoice))
                Text("say a word").font(.ghost).foregroundStyle(Color.ink2.opacity(0.8))
                    .opacity(fadeIn(toVoice))
            }
            // No submit button on the line: the keyboard's own "go" key already does it, and the
            // field is never live without the keyboard up.
            TextField("", text: $input)
                .font(inputFont).foregroundStyle(Color.ink)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focused)
                .onSubmit(go)
                .opacity(fadeOut(toVoice))
                .accessibilityLabel("Word to define")
                .accessibilityHint("Hold this line to speak the word instead")
                .accessibilityAction(named: "Speak a word", speakAction)
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

    /// The line under the input. Idle it's the invitation; held, it's the paper rule waking up — so
    /// the two share a guide: the hint's baseline and the wave's centre both sit on the same college
    /// rule, and one becomes the other in place, on the line, rather than near it.
    private var caption: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                // Side by side while it fits; stacked once the text size says it doesn't.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) { hintText; settingsLink }
                    VStack(alignment: .leading, spacing: 4) { hintText; settingsLink }
                }
                .opacity(input.isEmpty ? fadeOut(toVoice) : 0)
                .alignmentGuide(.bottom) { $0[.lastTextBaseline] }

                ListeningRule(levels: voice.levels, draw: reduceMotion ? 1 : CGFloat(fadeIn(toVoice, from: 0.35)))
                    .doodle(.pen, width: 2)
                    .frame(height: 22)        // a Shape is greedy; pin it or it grows the whole row
                    .opacity(fadeIn(toVoice, from: 0.35))
                    .allowsHitTesting(false)
                    .alignmentGuide(.bottom) { $0[VerticalAlignment.center] }
            }
            .onRule(spacing: rule)
            // Motion is never the only signal that the mic is live. Idle it's a blank rule of paper,
            // which is what keeps the word of the day from moving when the mic comes up.
            Text("Listening — release to define")
                .font(.caption).foregroundStyle(Color.ink2)
                .opacity(fadeIn(toVoice))
                .onRule(spacing: rule)
                .accessibilityHidden(toVoice == 0)
        }
    }

    private var hintText: some View {
        Text(hint ?? "Hold to speak").font(.footnote).foregroundStyle(Color.ink2)
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

    /// Tap to type, hold to speak. It sits over the input rather than on it: a long press on a live
    /// UITextField belongs to the loupe and the paste menu, and fighting those loses.
    private var holdCatcher: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressing { pressing = true; startHold() } }
                    .onEnded { _ in if pressing { pressing = false; endHold() } }
            )
            .allowsHitTesting(input.isEmpty)   // once there's text to edit, the field gets its gestures back
            .accessibilityHidden(true)
    }

    // MARK: - keyboard choreography
    // The sheet and the keyboard both live in the bottom 220pt. Moving them at once reads as two
    // things passing through each other, so they take turns: sheet out, then keyboard in, and the
    // reverse on the way back. The tap is ours to time — `holdCatcher` sets focus, not UIKit — so
    // the sequence is real rather than a guess at the keyboard's curve.

    private func raiseKeyboard() {
        guard !focused else { return }
        // Leaving is quicker than arriving: ease-out-quint, clear before the keyboard starts.
        withAnimation(reduceMotion ? nil : Motion.sheetExit) { sheetDown = true; expanded = false }
        guard !reduceMotion else { focused = true; return }
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            focused = true
        }
    }

    private func returnSheet() {
        Task {
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(200)) }   // let the keyboard land
            guard !focused, toVoice == 0 else { return }   // refocused mid-wait, or the mic has the screen
            withAnimation(reduceMotion ? nil : Motion.sheet) { sheetDown = false }
        }
    }

    private func go() {
        let w = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty else { return }
        alternates = []
        router.path.append(.define(w))
    }

    // MARK: - hold to speak
    private func startHold() {
        clearHint()
        withAnimation(Motion.state) { alternates = [] }
        voice.begin()
    }

    private func endHold() {
        Task { await handle(await voice.end()) }
    }

    /// VoiceOver can't long-press, so it gets the same feature hands-free: it listens until you stop.
    private func speakAction() {
        guard toVoice == 0 else { return }
        clearHint()
        alternates = []
        focused = false
        Task {
            UIAccessibility.post(notification: .announcement, argument: "Listening")
            await handle(await voice.listenHandsFree())
        }
    }

    private func handle(_ outcome: VoiceOutcome) {
        switch outcome {
        case .cancelled:
            break                                           // released too fast to be a hold: it was a tap
        case .word(let w):
            pulse(.impact(flexibility: .rigid))
            input = ""
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
            show("Didn't catch that — hold again and speak a little closer.")   // wraps to two lines on narrow screens
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

    // MARK: the sheet — where you left off, then recent words
    @ViewBuilder private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            previousWord
            history
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    /// Where the last lookup stopped. Tapping it reopens that chat with the whole trail restored, so a
    /// chain that wandered `sanguine › optimistic › rosy` comes back as those three tokens with `rosy`
    /// current — the same breadcrumb the user left, not a fresh lookup of the last word.
    ///
    /// The list below picks up from the next word down, so this word appears once: the card earns the slot
    /// by showing the chain, which a single row can't. Nothing here on a fresh install — the knight's empty
    /// state already teaches the drawer.
    @ViewBuilder private var previousWord: some View {
        if let last = trail.last {
            Button { router.path.append(.resume(trail)) } label: {
                HStack(alignment: .firstTextBaseline) {
                    // Same grid as the page above, one size down: each line closes on one of the card's
                    // own rules. `cardPad` is both the inset and the rules' phase, which is what puts
                    // the first rule under the first line instead of through it.
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Your previous word").font(.subheadline.weight(.medium)).foregroundStyle(Color.pen)
                            .onRule(spacing: cardRule)
                        Text(last).font(.system(.title, design: .rounded).weight(.bold)).foregroundStyle(Color.ink)
                            .onRule(2, spacing: cardRule)
                        if trail.count > 1 {
                            // Truncate from the head: the words nearest this one are the ones that explain it.
                            Text("from " + trail.dropLast().joined(separator: " › "))
                                .font(.footnote).foregroundStyle(Color.ink2)
                                .lineLimit(1).truncationMode(.head)
                                .onRule(spacing: cardRule)
                        }
                    }
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.right").font(.body.weight(.semibold)).foregroundStyle(Color.pen)
                }
                .padding(cardPad)
                .frame(maxWidth: .infinity, alignment: .leading)
                // A scrap of the same ruled paper, lying on the sheet: the card is the page, not a tint.
                .background {
                    Paper(page: .sheet, rule: .paperRule, margin: .clear, spacing: cardRule,
                          topInset: cardPad, fillsSafeArea: false)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.rule, lineWidth: 1)
                        }
                }
            }
            .buttonStyle(SurfacePressStyle(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)))
            .accessibilityLabel(accessibleTrail(last))
            .accessibilityHint("Opens where you left off")
        }
    }

    private func accessibleTrail(_ last: String) -> String {
        trail.count > 1
            ? "Your previous word: \(last), from \(trail.dropLast().joined(separator: ", "))"
            : "Your previous word: \(last)"
    }

    /// Newest first, minus the newest itself — that one is the card above, and repeating it a row
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
            .padding(.top, 4)
        } else if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(recent.prefix(limit)) { w in
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
                    .onAppear { if w == recent.prefix(limit).last, limit < recent.count { limit += 10 } }
                }
                allWords
            }
        }
    }

    /// The list's last line, not a control sitting above it: same left edge, same rhythm, one step
    /// quieter than a word (no `.ruled()` — the row above already drew the hairline, and this is where
    /// the paper ends). The count is of everything, the previous word included, because "all" means all.
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

/// Where the writing block starts on screen, so the paper's rules can be phased to it.
private struct GridTop: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Bottom sheet (Natural-style): peeks at the bottom, drag up to expand, scrolls when expanded.
struct BottomSheet<Content: View>: View {
    @Binding var expanded: Bool
    var peek: CGFloat
    @ViewBuilder var content: Content
    /// The handle was touched — dragged or tapped. Either way the user is done with the keyboard.
    var onGrab: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var drag: CGFloat = 0
    @State private var dragging = false

    var body: some View {
        GeometryReader { g in
            let h = g.size.height
            let fullH = h - 72
            let restY = expanded ? h - fullH : h - peek          // top edge of the sheet
            let y = clamp(restY + drag, lower: h - fullH - 24, upper: max(h - 56, restY))

            VStack(spacing: 0) {
                Capsule().fill(Color.rule).frame(width: 40, height: 5)
                    .frame(maxWidth: .infinity, minHeight: sheetGrabber)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(h: h, fullH: fullH))
                    .accessibilityLabel(expanded ? "Collapse" : "Expand")
                    .accessibilityAddTraits(.isButton)
                    .onTapGesture { onGrab(); withAnimation(anim) { expanded.toggle() } }
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
                    .opacity(expanded || dragging || peek < 72 ? 0 : 1)
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
