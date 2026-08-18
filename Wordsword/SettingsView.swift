import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(Auth.self) private var auth
    @Environment(\.modelContext) private var context
    @Query private var words: [Word]
    @State private var confirmClear = false
    @State private var confirmSignOut = false
    @State private var showAccount = false

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
                    // Middle truncation: a long address still shows whose account this is.
                    LabeledContent("Signed in as") {
                        Text(auth.identifier).lineLimit(1).truncationMode(.middle)
                    }
                    .sheetRow(.middle)
                    // Signing out locks flashcards until you sign back in, and on a build with
                    // no delivery behind it that means another code. Worth one tap of confirming.
                    Button { confirmSignOut = true } label: {
                        Text("Sign out").foregroundStyle(Color.pen)
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
                     ? "Signing out keeps every word on this phone."
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
        .background(PaperBackground())
        .navigationTitle("Settings")
        .sheet(isPresented: $showAccount) { AccountFlow { showAccount = false } }
        .confirmationDialog("Sign out of \(auth.identifier)?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { auth.signOut() }
        } message: {
            Text("Every word stays on this phone. Flashcards lock until you sign back in.")
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
