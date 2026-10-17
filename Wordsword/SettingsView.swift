import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(Auth.self) private var auth
    @Environment(\.modelContext) private var context
    @Query private var words: [Word]
    @State private var confirmClear = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var showAccount = false

    /// There's no server to revoke Apple's link from our side, so the delete dialog hands the user
    /// the one switch that does. Path per Apple support article 102571, read 2026-10-17.
    private static let disconnect = "To also disconnect wordsword from your Apple ID: Settings → your name → Sign in with Apple → wordsword → Delete."

    var body: some View {
        @Bindable var auth = auth
        // Rows sit on white sheets over the paper: every row carries `.sheetRow(_:)` with its place
        // in the section, so the section's hairline outline closes at the top and bottom rows.
        Form {
            Section {
                if auth.isSignedIn {
                    // Labelled, not a bare box: a prefilled placeholder-only field leaves no
                    // way to tell what the value is once it's filled in.
                    LabeledContent("Username") {
                        TextField("username", text: $auth.username)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    .sheetRow(.first)
                    // Says *how* you're signed in, not *as whom*: Apple's user ID is opaque and
                    // means nothing to a person, so it's never shown.
                    LabeledContent("Signed in with", value: "Apple")
                        .sheetRow(.middle)
                    // Signing out locks flashcards until you sign back in. Worth one tap of confirming.
                    Button { confirmSignOut = true } label: {
                        Text("Sign out").foregroundStyle(Color.pen)
                    }
                    .sheetRowButton(.middle)
                    // Required in-app by App Store guideline 5.1.1(v) for any app that offers
                    // account creation. It sits under Sign out rather than somewhere safer:
                    // deletion people can't find is the thing the guideline exists to prevent.
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Text("Delete account").foregroundStyle(.red)
                    }
                    .sheetRowButton(.last)
                } else {
                    Button { showAccount = true } label: {
                        Text("Create an account or sign in").foregroundStyle(Color.pen)
                    }
                    .sheetRowButton(.only)
                }
            } header: {
                Text("You")
            } footer: {
                Text(auth.isSignedIn
                     // Covers both buttons above it. Saying only "signing out" while a red
                     // Delete account sits alongside invites the reader to assume the opposite.
                     ? "Signing out or deleting your account keeps every word on this phone."
                     : "No account yet — your words are saved on this phone. An account adds flashcards, and backup once sync ships.")
            }
            Section {
                LabeledContent("Words saved", value: "\(words.count)").sheetRow(.first)
                LabeledContent("Word of the day", value: WordOfTheDay.today).sheetRow(.last)
            }
            Section {
                Button { auth.hasSeenStory = false } label: {
                    Text("Replay how it works").foregroundStyle(Color.pen)
                }
                .sheetRowButton(.first)
                Button(role: .destructive) { confirmClear = true } label: {
                    Text("Clear all my words").foregroundStyle(words.isEmpty ? Color.ink2 : .red)
                }
                .disabled(words.isEmpty)
                .sheetRowButton(.last)
            }
            Section("About") {
                Text("Definitions from the Free Dictionary API (dictionaryapi.dev). Spelling help and extra synonyms from Datamuse.")
                    .font(.footnote).foregroundStyle(Color.ink2)
                    .sheetRow(.first)
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .sheetRow(.last)
            }
        }
        .scrollContentBackground(.hidden)
        .paperScreen("Settings")
        .sheet(isPresented: $showAccount) { AccountFlow { showAccount = false } }
        .confirmationDialog("Sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { auth.signOut() }
        } message: {
            Text("Every word stays on this phone. Flashcards lock until you sign back in.")
        }
        // Names what survives, not just what goes: the fear this dialog has to answer is "am I
        // about to lose my library", and the answer is no.
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { auth.deleteAccount() }
        } message: {
            Text(words.isEmpty
                 ? "Your account is removed from this phone and can't be restored. \(Self.disconnect)"
                 : "Your account is removed from this phone and can't be restored. Your \(words.count) saved words stay — clear them separately if you want those gone too. \(Self.disconnect)")
        }
        .confirmationDialog("Delete all \(words.count) words and every wordlist?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                try? context.delete(model: Word.self)
                try? context.delete(model: Wordlist.self)
                try? context.delete(model: Tag.self)
            }
        }
    }
}
