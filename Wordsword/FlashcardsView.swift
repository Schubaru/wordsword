import SwiftUI
import SwiftData

/// Spaced-repetition flashcards. Due words first; if nothing's due, practice the whole set anyway.
struct FlashcardsView: View {
    let listID: PersistentIdentifier?
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var all: [Word]

    @State private var deck: [Word] = []
    @State private var index = 0
    @State private var flipped = false
    @State private var right = 0
    @State private var total = 0
    @State private var slide: CGFloat = 0
    @State private var reaction: KnightPose = .idle   // cheer / slump right after an answer, then back to idle
    @Environment(Auth.self) private var auth
    @State private var showAccount = false

    var body: some View {
        VStack(spacing: 24) {
            if !auth.isSignedIn {
                locked
            } else if deck.isEmpty {
                VStack(spacing: 12) {
                    KnightDoodle(pose: .idle, color: .ink, accent: .pen).frame(width: 96, height: 96)
                    Text("Nothing to practice yet").font(.title3.weight(.semibold)).foregroundStyle(Color.ink)
                    Text("Cards are made from words you've looked up.").font(.body).foregroundStyle(Color.ink2)
                    // An empty state without a way out is a dead end; this is the only thing to do next.
                    Button("Look up a word") { router.path = [] }
                        .buttonStyle(CTAStyle())
                        .padding(.top, 8)
                }
            } else if index >= deck.count {
                done
            } else {
                HStack {
                    Text("\(index + 1) of \(deck.count)").font(.subheadline.weight(.medium)).foregroundStyle(Color.ink2)
                        .contentTransition(.numericText())
                    Spacer()
                    KnightDoodle(pose: reaction, color: .ink, accent: .pen).frame(width: 44, height: 44)
                        .animation(reduceMotion ? nil : Motion.state, value: reaction)
                }
                card(deck[index])
                    .offset(x: slide)
                    .id(deck[index].persistentModelID)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                answers
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PaperBackground())
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAccount) { AccountFlow { showAccount = false } }
        .onAppear(perform: build)
        #if DEBUG
        .onChange(of: router.debug) { _, d in if d == "flip" { flipped = true } }
        #endif
    }
    @Environment(Router.self) private var router

    /// The account gate. Not a locked door — this is the best moment in the app to explain what an
    /// account is for, because the user is already reaching for the thing it unlocks.
    private var locked: some View {
        VStack(spacing: 14) {
            KnightDoodle(pose: .idle, color: .ink, accent: .pen).frame(width: 96, height: 96)
            Text("Flashcards need an account")
                .font(.title3.weight(.semibold)).foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            Text("They're how your words come back right before you'd forget them. Takes about twenty seconds, and every word you've saved stays exactly where it is.")
                .font(.body).foregroundStyle(Color.ink2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Create an account or sign in") { showAccount = true }
                .buttonStyle(CTAStyle())
                .padding(.top, 8)
        }
        .padding(.horizontal, 8)
    }

    private func build() {
        let pool: [Word]
        if let id = listID, let l = context.model(for: id) as? Wordlist { pool = l.words } else { pool = all }
        let due = pool.filter { $0.dueAt <= Date() }
        deck = (due.isEmpty ? pool : due).shuffled().prefix(20).map { $0 }
        total = deck.count; index = 0; right = 0; flipped = false
    }

    private func card(_ w: Word) -> some View {
        Button { withAnimation(reduceMotion ? .linear(duration: 0.12) : Motion.reveal) { flipped.toggle() } } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.sheet)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.rule, lineWidth: 1))
                    .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
                Group {
                    if flipped {
                        VStack(spacing: 14) {
                            Text(w.text).font(.pos).foregroundStyle(Color.ink2)
                            Text(w.definition).font(.define).foregroundStyle(Color.ink).multilineTextAlignment(.center)
                            if !w.synonyms.isEmpty {
                                Text(w.synonyms.prefix(3).joined(separator: " · ")).font(.footnote).foregroundStyle(Color.ink2)
                            }
                        }
                        .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (0, 1, 0))
                    } else {
                        VStack(spacing: 8) {
                            Text(w.text).font(.headword).foregroundStyle(Color.ink)
                            Text(w.partOfSpeech).font(.pos).foregroundStyle(Color.ink2)
                            if let r = Pronunciation.worthShowing(w.respelling, for: w.text) {
                                Text(r).font(.pron).foregroundStyle(Color.ink2)
                            }
                            Text("tap to flip").font(.caption).foregroundStyle(Color.ink2).padding(.top, 20)
                        }
                    }
                }
                .padding(28)
            }
            .rotation3DEffect(.degrees(flipped && !reduceMotion ? 180 : 0), axis: (0, 1, 0), perspective: 0.6)
            .frame(maxWidth: .infinity, minHeight: 300)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(flipped ? "\(w.text): \(w.definition)" : "\(w.text). Tap to reveal definition")
        .overlay(alignment: .topTrailing) {
            SpeakerButton(word: w.text, audio: w.audioURL).padding(22)
        }
        // Words saved before pronunciation existed never pass back through DefineView, so they'd
        // stay blank here forever. Fill the card in as it comes up — never blocking: the card is
        // already readable, and @Model means the respelling just appears when it lands.
        .task(id: w.text) {
            Speaker.shared.prefetch(w.audioURL)
            guard w.respelling == nil, let p = await Dictionary.pronunciation(for: w.text) else { return }
            w.addTag("pron", p.respelling, in: context)
            if let a = p.audio { w.addTag("audio", a.absoluteString, in: context) }
        }
    }

    private var answers: some View {
        HStack(spacing: 12) {
            answer("Pass", "xmark", knew: false)
            answer("Got it", "checkmark", .green, knew: true)
        }
        .opacity(flipped ? 1 : 0.35)
        .disabled(!flipped)
        .animation(Motion.state, value: flipped)
    }

    private func answer(_ title: String, _ icon: String, _ color: Color = .white, knew: Bool) -> some View {
        Button {
            let w = deck[index]
            w.review(knewIt: knew)
            if knew { if index < total { right += 1 } } else { deck.append(w) }   // missed words come back around this session
            withAnimation(reduceMotion ? .linear(duration: 0.12) : Motion.state) { flipped = false; index += 1; reaction = knew ? .cheer : .slump }
            Task { try? await Task.sleep(for: .milliseconds(900)); withAnimation(Motion.state) { reaction = .idle } }
        } label: {
            Label(title, systemImage: icon)
                .font(.body.weight(.semibold)).foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(knew ? AnyShapeStyle(color.opacity(0.10)) : AnyShapeStyle(Color.black), in: Capsule())
        }
        .buttonStyle(PressStyle())
    }

    private var done: some View {
        VStack(spacing: 12) {
            KnightDoodle(pose: .cheer, color: .ink, accent: .pen).frame(width: 96, height: 96)
            Text("Done").font(.headword).foregroundStyle(Color.ink)
                .overlay(alignment: .bottom) {
                    DoodleStroke(progress: 1).stroke(Color.pen, style: .init(lineWidth: 2.5, lineCap: .round)).frame(height: 8).offset(y: 6)
                }
            Text("\(right) of \(total) on the first try. Missed words come back sooner.")
                .font(.body).foregroundStyle(Color.ink2).multilineTextAlignment(.center)
            Button("Go again") { withAnimation(Motion.state) { build() } }
                .buttonStyle(.borderedProminent).padding(.top, 8)
        }
    }
}
