import SwiftUI

/// Choose → identify → verify → name yourself.
///
/// Used in two places with the same code: as the last step of onboarding (where the quiet third
/// option is "Maybe later"), and as a sheet from Settings or the flashcards gate (where it's
/// "Cancel"). One implementation means the sign-up you get from the flashcards prompt is the same
/// one you'd have got on day one.
struct AccountFlow: View {
    /// Title for the quiet opt-out on the choice screen. Nil in a sheet, which gets Cancel instead.
    var laterTitle: String?
    var onFinish: () -> Void

    private enum Step { case choice, identifier, code, username }
    private enum Intent { case signUp, signIn }
    /// The two ways someone lands on the wrong screen. Neither is a dead end — each offers the
    /// other door rather than just refusing.
    private enum Crossover { case alreadyHaveOne, noAccountYet }

    @Environment(Auth.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step = .choice
    @State private var intent: Intent = .signUp
    @State private var raw = ""
    @State private var contact: Contact?
    @State private var code = ""
    @State private var name = ""
    @State private var error: String?
    @State private var crossover: Crossover?
    @State private var busy = false
    @State private var shake: CGFloat = 0
    @State private var resendIn = 0
    @State private var resendToken = 0

    @FocusState private var focus: Field?
    private enum Field { case identifier, code, name }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                Group {
                    switch step {
                    case .choice:     choice
                    case .identifier: identifier
                    case .code:       codeStep
                    case .username:   usernameStep
                    }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(PaperBackground())
        .animation(reduceMotion ? nil : Motion.state, value: step)
        // Focus belongs to the step, not to the five places that change it. A field that is being
        // inserted this same tick can't take focus — the assignment is silently dropped and the
        // keyboard never comes up. Waiting out the transition also stops the keyboard racing it.
        .task(id: step) {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 50 : 260))
            guard !Task.isCancelled else { return }
            switch step {
            case .choice:     focus = nil
            case .identifier: focus = .identifier
            case .code:       focus = .code
            case .username:   focus = .name
            }
        }
        #if DEBUG
        .onChange(of: router.debug) { _, d in
            let demo = Contact.email("alex@example.com")
            switch d {
            case "acct:choice": step = .choice
            case "acct:id":     raw = demo.display; step = .identifier
            case "acct:code":   raw = demo.display; contact = demo; code = ""
                                Task { await auth.sendCode(to: demo); resendToken += 1; step = .code }
            case "acct:bad":    contact = demo; code = ""; step = .code
                                error = AuthError.badCode.errorDescription
            case "acct:name":   contact = demo; name = "alex"; step = .username
            default: break
            }
        }
        #endif
    }
    @Environment(Router.self) private var router

    // MARK: - top bar: a way back out of every step that has one

    @ViewBuilder private var topBar: some View {
        HStack {
            switch step {
            case .choice, .username:
                EmptyView()
            case .identifier:
                back { step = .choice; error = nil; crossover = nil }
            case .code:
                back { step = .identifier; code = ""; error = nil }
            }
            Spacer()
            // In a sheet the way out stays in one place. It used to live on the first step only,
            // which put the exit from the code screen three taps away — an exit nobody takes.
            // Gone on the last step: the account already exists by then, so there's nothing to cancel.
            if laterTitle == nil, step != .username {
                Button("Cancel") { dismiss() }
                    .font(.body).foregroundStyle(Color.ink2)
                    .frame(minHeight: 44)
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 16)
    }

    private func back(_ action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : Motion.state, action)
        } label: {
            Label("Back", systemImage: "chevron.left").font(.body).foregroundStyle(Color.ink2)
        }
        .labelStyle(.iconOnly)
        .frame(width: 44, height: 44)
        .accessibilityLabel("Back")
    }

    // MARK: - 1. choice

    private var choice: some View {
        VStack(alignment: .leading, spacing: 0) {
            KnightDoodle(pose: .idle, color: .ink, accent: .pen)
                .frame(width: 84, height: 84)
                .padding(.bottom, 18)

            // No antecedent problem: two of the three ways in (Settings row, flashcards gate) give
            // "them" nothing to point at. This also leads with the thing that works today —
            // the old headline sold backup, which the footnote two lines down takes back.
            Text("Make your words stick.")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 10) {
                perk("Flashcards, and word games later")
                perk("Your words, backed up")
                perk("The same words on every device")
                perk("A username that's yours")
            }
            .padding(.bottom, 12)

            // The account is real; the sync behind it isn't yet. Saying so here is cheaper than
            // someone trusting a backup that doesn't exist.
            Text("Flashcards work right now. Backup and sync land in a later update — today your words live on this phone.")
                .font(.footnote).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 28)

            VStack(spacing: 10) {
                Button("Create an account") { go(.signUp) }
                    .buttonStyle(CTAStyle())
                Button("I already have one") { go(.signIn) }
                    .buttonStyle(CTAStyle(weight: .outlined))
                if let laterTitle {
                    Button(laterTitle) { onFinish() }
                        .buttonStyle(CTAStyle(weight: .quiet))
                }
            }
            .padding(.bottom, 8)

            if laterTitle != nil {
                Text("Skipping keeps every word you look up — right here on this phone.")
                    .font(.footnote).foregroundStyle(Color.ink2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 32)
    }

    private func perk(_ s: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.footnote.weight(.bold)).foregroundStyle(Color.pen)
            Text(s).font(.body).foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func go(_ i: Intent) {
        intent = i
        error = nil
        crossover = nil
        raw = auth.identifier   // signing back in? it's already filled in
        withAnimation(reduceMotion ? nil : Motion.state) { step = .identifier }
    }

    // MARK: - 2. identifier

    private var identifier: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(intent == .signUp ? "Where should we send your code?" : "What did you sign up with?")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)

            Text("Email or phone — whichever you like. We'll send a 6-digit code, so there's no password to remember.")
                .font(.subheadline).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 20)

            // One example, not a restatement: the line above already says either works, and it
            // stays put — a placeholder is gone the moment anyone types. The old one also ran the
            // full width of the field and truncated on a small phone.
            TextField("you@email.com", text: $raw)
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(Color.ink)
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .focused($focus, equals: .identifier)
                .onSubmit { Task { await send() } }
                .onChange(of: raw) { _, _ in
                    if error != nil || crossover != nil {
                        withAnimation(Motion.state) { error = nil; crossover = nil }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.sheet)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(error != nil ? .red : (focus == .identifier ? Color.pen : Color.rule),
                                              lineWidth: (error != nil || focus == .identifier) ? 2 : 1)
                        }
                }
                .animation(Motion.state, value: focus)

            if let error {
                message(error, bad: true).padding(.top, 10)
            }

            if let crossover {
                crossoverPrompt(crossover).padding(.top, 14)
            }

            Button {
                Task { await send() }
            } label: {
                if busy { ProgressView().tint(Color.onPen) } else { Text("Send code") }
            }
            .buttonStyle(CTAStyle())
            .disabled(busy)
            .padding(.top, 24)
        }
        .padding(.bottom, 32)
    }

    /// The wrong-door recovery. The user's contact is fine; they just picked the other button.
    @ViewBuilder private func crossoverPrompt(_ c: Crossover) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(c == .alreadyHaveOne
                 ? "You've already got an account with that."
                 : "There's no account for that on this phone yet.")
                .font(.subheadline).foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Button(c == .alreadyHaveOne ? "Sign in instead" : "Create an account with it") {
                intent = c == .alreadyHaveOne ? .signIn : .signUp
                crossover = nil
                Task { await send(force: true) }
            }
            .buttonStyle(CTAStyle(weight: .outlined))
        }
        .padding(16)
        .background(Color.penWash, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func send(force: Bool = false) async {
        guard !busy else { return }
        guard let c = Contact.parse(raw) else {
            withAnimation(Motion.state) {
                error = raw.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Pop in your email or phone number first."
                    : "That's not quite an email or a phone number yet."
            }
            return
        }
        if !force {
            if intent == .signUp, auth.knownAccount(c) {
                withAnimation(Motion.state) { crossover = .alreadyHaveOne }; return
            }
            if intent == .signIn, !auth.knownAccount(c) {
                withAnimation(Motion.state) { crossover = .noAccountYet }; return
            }
        }
        focus = nil
        busy = true
        await auth.sendCode(to: c)
        busy = false
        contact = c
        code = ""
        error = nil
        crossover = nil
        resendToken += 1
        withAnimation(reduceMotion ? nil : Motion.state) { step = .code }
    }

    // MARK: - 3. the code

    @ViewBuilder private var codeStep: some View {
        if let c = contact {
            VStack(alignment: .leading, spacing: 0) {
                Text("Check your \(c.inbox).")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.ink)
                    .padding(.bottom, 8)

                // Restated verbatim: a typo here is the likeliest way to end up waiting forever
                // for a code that went somewhere else.
                (Text("We sent a 6-digit code to ").foregroundStyle(Color.ink2)
                 + Text(c.display).foregroundStyle(Color.ink).fontWeight(.semibold))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Change it") {
                    withAnimation(reduceMotion ? nil : Motion.state) { step = .identifier }
                    code = ""; error = nil
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.pen)
                .padding(.top, 6)
                .padding(.bottom, 24)

                codeBoxes
                    .modifier(Shake(animatableData: shake))
                    .padding(.bottom, 14)

                if busy {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Checking…").font(.subheadline).foregroundStyle(Color.ink2)
                    }
                } else if let error {
                    message(error, bad: true)
                }

                resendRow.padding(.top, 20)

                if let pending = auth.pendingCode {
                    // There's no server behind this build, so the code has to come from somewhere.
                    // Visible on purpose: a placeholder you can see beats one that strands you.
                    Label("No server yet — your code is \(pending)", systemImage: "wrench.and.screwdriver")
                        .font(.footnote).foregroundStyle(Color.ink2)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.penWash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 24)
                }
            }
            .padding(.bottom, 32)
            .task(id: resendToken) {
                resendIn = 30
                while resendIn > 0 {
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled { return }
                    resendIn -= 1
                }
            }
        }
    }

    /// Six boxes over one real text field: the boxes show how far along you are, the field keeps
    /// iOS's one-time-code autofill (and paste, and VoiceOver) working normally.
    private var codeBoxes: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focus, equals: .code)
                .frame(maxWidth: .infinity, minHeight: 58)
                .opacity(0.01)
                .accessibilityLabel("Verification code, 6 digits")
                .onChange(of: code) { _, v in
                    let digits = String(v.filter(\.isNumber).prefix(6))
                    if digits != code { code = digits; return }
                    if !digits.isEmpty, error != nil { withAnimation(Motion.state) { error = nil } }
                    if digits.count == 6 { Task { await verify() } }
                }
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { box($0) }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)   // the field above is the accessible element
        }
        .contentShape(Rectangle())
        .onTapGesture { focus = .code }
    }

    private func box(_ i: Int) -> some View {
        let chars = Array(code)
        let filled = i < chars.count
        let isNext = i == chars.count && !busy
        let bad = error != nil
        // Four states, because the keyboard can be dismissed mid-code (the scroll dismisses it).
        // The ring used to need focus, so a dismissed keyboard left six identical inert boxes with
        // no caret and nothing saying they were still the input.
        let border: Color = bad ? .red
            : isNext ? (focus == .code ? Color.pen : Color.ink2)
            : filled ? Color.pen.opacity(0.35)
            : Color.rule
        let heavy = bad || (isNext && focus == .code)
        return Text(filled ? String(chars[i]) : " ")
            .font(.system(size: 24, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.sheet)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(border, lineWidth: heavy ? 2 : 1)
                    }
            }
            .animation(Motion.feedback, value: filled)
            .animation(Motion.feedback, value: heavy)
    }

    private var resendRow: some View {
        HStack(spacing: 6) {
            Text("Didn't get it?").font(.subheadline).foregroundStyle(Color.ink2)
            if resendIn > 0 {
                Text("Resend in \(resendIn)s").font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink2)
            } else {
                Button("Resend code") {
                    Task {
                        guard let c = contact else { return }
                        code = ""
                        withAnimation(Motion.state) { error = nil }
                        await auth.sendCode(to: c)
                        resendToken += 1
                        focus = .code
                    }
                }
                .font(.subheadline.weight(.semibold)).foregroundStyle(Color.pen)
            }
        }
    }

    private func verify() async {
        guard let c = contact, !busy else { return }
        busy = true
        focus = nil
        do {
            try await auth.verify(code, for: c)
            busy = false
            if auth.username.isEmpty {
                name = c.suggestedName
                withAnimation(reduceMotion ? nil : Motion.state) { step = .username }
            } else {
                onFinish()
            }
        } catch {
            busy = false
            code = ""
            if !reduceMotion { withAnimation(.linear(duration: 0.4)) { shake += 1 } }
            withAnimation(Motion.state) {
                self.error = (error as? AuthError)?.errorDescription ?? "That didn't work. Try again."
            }
            focus = .code
        }
    }

    // MARK: - 4. name yourself (and the close)

    private var usernameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The consequential thing already happened — say so before asking for anything else.
            Label("\(contact?.display ?? auth.identifier) verified", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.pen)
                .padding(.bottom, 20)

            Text("Pick a name.")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.ink)
                .padding(.bottom, 8)

            Text("Just how the app says hi. You can change it any time in Settings.")
                .font(.subheadline).foregroundStyle(Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 20)

            TextField("username", text: $name)
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(Color.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
                .submitLabel(.done)
                .focused($focus, equals: .name)
                .onSubmit(finishWithName)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.sheet)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(focus == .name ? Color.pen : Color.rule,
                                              lineWidth: focus == .name ? 2 : 1)
                        }
                }
                .animation(Motion.state, value: focus)

            Button("Start looking up words", action: finishWithName)
                .buttonStyle(CTAStyle())
                .padding(.top, 24)
        }
        .padding(.bottom, 32)
    }

    private func finishWithName() {
        let n = name.trimmingCharacters(in: .whitespaces)
        // Nothing rides on this being filled in, so an empty box shouldn't block the door.
        auth.username = n.isEmpty ? (contact?.suggestedName ?? "") : n
        onFinish()
    }

    // MARK: - bits

    private func message(_ s: String, bad: Bool) -> some View {
        Label(s, systemImage: bad ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(bad ? .red : Color.pen)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(bad ? .isStaticText : [])
    }
}

/// Sideways nudge for a rejected code — the message says what's wrong, this says *that* something
/// is wrong before you've finished reading. Suppressed under reduced motion.
private struct Shake: GeometryEffect {
    var amount: CGFloat = 7
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: amount * sin(animatableData * .pi * shakes), y: 0))
    }
}
