import AuthenticationServices
import SwiftUI

/// Choose → Sign in with Apple → name yourself.
///
/// Used in two places with the same code: as the last step of onboarding (where the quiet third
/// option is "Maybe later"), and as a sheet from Settings or the flashcards gate (where it's
/// "Cancel"). One implementation means the sign-up you get from the flashcards prompt is the same
/// one you'd have got on day one.
struct AccountFlow: View {
    /// Title for the quiet opt-out on the choice screen. Nil in a sheet, which gets Cancel instead.
    var laterTitle: String?
    var onFinish: () -> Void

    private enum Step { case choice, username }

    @Environment(Auth.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step = .choice
    @State private var name = ""
    @State private var error: String?

    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                Group {
                    switch step {
                    case .choice:   choice
                    case .username: usernameStep
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
        // A field inserted this same tick can't take focus — the assignment is silently dropped
        // and the keyboard never comes up. Waiting out the transition also stops it racing.
        .task(id: step) {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 50 : 260))
            guard !Task.isCancelled else { return }
            nameFocused = step == .username
        }
        #if DEBUG
        .onChange(of: router.debug) { _, d in
            switch d {
            case "acct:choice": step = .choice; error = nil
            case "acct:error":  step = .choice; error = Self.failed
            case "acct:name":   name = "alex"; step = .username
            default: break
            }
        }
        #endif
    }
    @Environment(Router.self) private var router

    // MARK: - top bar

    @ViewBuilder private var topBar: some View {
        HStack {
            Spacer()
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

            // One button for both doors: Apple doesn't distinguish sign up from sign in, so the
            // old "Create an account" / "I already have one" pair (and the wrong-door recovery it
            // needed) has nothing left to choose between.
            VStack(spacing: 10) {
                SignInWithAppleButton(.continue) { request in
                    // Name only, to suggest a username. No email: nothing here would use it, and
                    // not asking means there's no contact info to declare anywhere.
                    request.requestedScopes = [.fullName]
                } onCompletion: { result in
                    finish(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(Capsule())   // the same silhouette as every CTAStyle beside it

                if let error {
                    message(error, bad: true).padding(.top, 4)
                }

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

    private static let failed = "Couldn't reach Apple. Check your connection and try again."

    private func finish(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let a):
            guard let cred = a.credential as? ASAuthorizationAppleIDCredential else {
                error = Self.failed; return
            }
            error = nil
            // Coming back to an account that already has a name: straight in, nothing to ask.
            let returning = cred.user == auth.identifier && !auth.username.isEmpty
            auth.signIn(userID: cred.user, givenName: cred.fullName?.givenName)
            if returning { onFinish(); return }
            name = auth.username   // Apple's first name when it sent one, otherwise empty
            withAnimation(reduceMotion ? nil : Motion.state) { step = .username }
        case .failure(let e):
            // Backing out of Apple's sheet is a choice, not an error — say nothing.
            if (e as? ASAuthorizationError)?.code == .canceled { return }
            withAnimation(Motion.state) { error = Self.failed }
        }
    }

    // MARK: - 2. name yourself (and the close)

    private var usernameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The consequential thing already happened — say so before asking for anything else.
            Label("Signed in with Apple", systemImage: "checkmark.circle.fill")
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
                .focused($nameFocused)
                .onSubmit(finishWithName)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.sheet)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(nameFocused ? Color.pen : Color.rule,
                                              lineWidth: nameFocused ? 2 : 1)
                        }
                }
                .animation(Motion.state, value: nameFocused)

            Button("Start looking up words", action: finishWithName)
                .buttonStyle(CTAStyle())
                .padding(.top, 24)
        }
        .padding(.bottom, 32)
    }

    private func finishWithName() {
        let n = name.trimmingCharacters(in: .whitespaces)
        // Nothing rides on this being filled in, so an empty box shouldn't block the door.
        auth.username = n
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
