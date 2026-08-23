import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(Router.self) private var router
    @Environment(Auth.self) private var auth
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.lastLookedUp, order: .reverse) private var words: [Word]
    @Query(sort: \Wordlist.createdAt, order: .reverse) private var lists: [Wordlist]
    @State private var newName = ""
    @State private var naming = false
    @FocusState private var namingFocused: Bool

    private var due: Int { words.filter { $0.dueAt <= Date() }.count }

    /// Says the state of the row before you tap it, so the gate and the empty screen are never a
    /// surprise: no account → the ask, no words → the reason, otherwise what's waiting.
    private var flashcardsDetail: String {
        if !auth.isSignedIn { "needs an account" }
        else if words.isEmpty { "no words yet" }
        else if due > 0 { "\(due) due" }
        else { "practice" }
    }

    var body: some View {
        List {
            Section {
                row("All words", detail: "\(words.count)", icon: "tray.full", edge: .first) { router.path.append(.wordlist(nil)) }
                // Never disabled: the detail says what's in the way and the screen behind it says
                // what to do about it. A greyed row swallows the tap and explains neither.
                row("Flashcards", detail: flashcardsDetail, icon: "rectangle.on.rectangle.angled", edge: .last) {
                    router.path.append(.flashcards(nil))
                }
            }
            Section("Wordlists") {
                ForEach(Array(lists.enumerated()), id: \.element.persistentModelID) { i, l in
                    row(l.name, detail: "\(l.words.count)", icon: "list.bullet",
                        edge: .at(i, of: lists.count + 1)) { router.path.append(.wordlist(l.persistentModelID)) }
                }
                .onDelete { idx in idx.map { lists[$0] }.forEach(context.delete) }
                if naming {
                    HStack {
                        TextField("Wordlist name", text: $newName).submitLabel(.done).onSubmit(create)
                            .focused($namingFocused)
                        Button("Add", action: create).disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .sheetRow(lists.isEmpty ? .only : .last)
                } else {
                    Button { withAnimation(Motion.state) { naming = true } } label: { Label("New wordlist", systemImage: "plus") }
                        .sheetRowButton(lists.isEmpty ? .only : .last)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .paperScreen("Library")
        // Tapping "New wordlist" should leave you typing, not looking at an empty box. A field being
        // inserted this same tick can't take focus, so wait out the row's insertion first.
        .task(id: naming) {
            guard naming else { return }
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            namingFocused = true
        }
    }

    private func create() {
        let n = newName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        context.insert(Wordlist(name: n)); newName = ""; naming = false
    }

    private func row(_ title: String, detail: String, icon: String, edge: SheetRowEdge, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon).foregroundStyle(Color.ink)
                Spacer()
                Text(detail).font(.subheadline).foregroundStyle(Color.ink2)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Color.ink2)
            }
        }
        .sheetRowButton(edge)
    }
}

/// A wordlist (or All when listID is nil): ruled list, swipe to remove, practice button.
struct WordlistDetailView: View {
    let listID: PersistentIdentifier?
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Query(sort: \Word.lastLookedUp, order: .reverse) private var all: [Word]

    private var list: Wordlist? { listID.flatMap { context.model(for: $0) as? Wordlist } }
    private var words: [Word] { list.map { $0.words.sorted { $0.lastLookedUp > $1.lastLookedUp } } ?? all }

    var body: some View {
        List {
            if words.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    KnightDoodle(pose: .idle, color: .ink, accent: .pen).frame(width: 56, height: 56)
                    Text(list == nil ? "Look up a word and it'll land here." : "Empty so far. Open any word and tap Add to wordlist to file it here.")
                        .foregroundStyle(Color.ink2)
                }
                .listRowBackground(Color.clear)
            }
            Section {
            ForEach(Array(words.enumerated()), id: \.element.persistentModelID) { i, w in
                Button { router.path.append(.define(w.text)) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(w.text).font(.system(.body, design: .rounded).weight(.semibold)).foregroundStyle(Color.ink)
                            Text(w.partOfSpeech).font(.caption).foregroundStyle(Color.ink2)
                        }
                        Text(w.definition).font(.subheadline).foregroundStyle(Color.ink2).lineLimit(2)
                    }
                }
                .listRowSeparatorTint(Color.rule)
                .sheetRowButton(i, of: words.count)
            }
            .onDelete { idx in
                let picked = idx.map { words[$0] }
                if let list { list.words.removeAll { picked.contains($0) } } else { picked.forEach(context.delete) }
            }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .paperScreen(list?.name ?? "All words") {
            // Same glyph as Library's Flashcards row, so the icon is learned in one place.
            if !words.isEmpty {
                GlassIcon("rectangle.on.rectangle.angled", "Practice") { router.path.append(.flashcards(listID)) }
            }
        }
    }
}

/// Spotify "add to playlist": toggle any wordlist, or make a new one inline.
struct AddToWordlistSheet: View {
    let word: Word
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Wordlist.createdAt, order: .reverse) private var lists: [Wordlist]
    @State private var newName = ""

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("New wordlist", text: $newName).submitLabel(.done).onSubmit(create)
                    Button("Create", action: create).disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .sheetRow(.only)
            }
            Section {
                ForEach(Array(lists.enumerated()), id: \.element.persistentModelID) { i, l in
                    let on = l.words.contains(word)
                    Button {
                        withAnimation(Motion.state) { on ? l.words.removeAll { $0 == word } : l.words.append(word) }
                    } label: {
                        HStack {
                            Text(l.name).foregroundStyle(Color.ink)
                            Spacer()
                            Text("\(l.words.count)").font(.subheadline).foregroundStyle(Color.ink2)
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? Color.pen : Color.rule).font(.title3)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                    .sheetRowButton(i, of: lists.count)
                }
            } footer: {
                Text("\"\(word.text)\" is already in All. Wordlists are your playlists.")
            }
        }
        .scrollContentBackground(.hidden)
        // No navigation stack behind it any more: nothing pushes, and the one control commits
        // nothing — every toggle is already saved — so it just closes the sheet.
        .paperScreen("Add to wordlist", back: false) {
            GlassIcon("xmark", "Done") { dismiss() }
        }
        .presentationDetents([.medium, .large])
    }

    private func create() {
        let n = newName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        let l = Wordlist(name: n); l.words = [word]
        context.insert(l); newName = ""
    }
}
