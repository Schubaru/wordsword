import SwiftUI

/// The three screens that tell the story: hit a word → type it → it's kept.
///
/// Each one shows a miniature built from the app's real components and tokens (the same headword
/// treatment as `HeadwordBubble`, the same follow-up chips, the same ruled history rows) rather than a
/// stock icon. That makes the promise accurate by construction — the screens can't drift into
/// describing an app we don't ship — and it means the first real screen is already familiar.
struct StoryView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private static let last = 2

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.ink2)
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .accessibilityHint("Goes straight to the account step")
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            TabView(selection: $page) {
                HitAWordPage(active: page == 0).tag(0)
                TypeItPage(active: page == 1).tag(1)
                KeptPage(active: page == 2).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : Motion.reveal, value: page)

            dots.padding(.bottom, 20)

            Button(page == Self.last ? "Continue" : "Next") {
                if page < Self.last {
                    withAnimation(reduceMotion ? nil : Motion.state) { page += 1 }
                } else {
                    onFinish()
                }
            }
            .buttonStyle(CTAStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(PaperBackground())
        #if DEBUG
        .onChange(of: router.debug) { _, d in
            if d.hasPrefix("story:"), let n = Int(d.dropFirst(6)) { page = min(max(n, 0), Self.last) }
        }
        #endif
    }
    @Environment(Router.self) private var router

    /// Maps to real position in the story — three steps, and you can always see which one you're on.
    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0...Self.last, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.pen : Color.rule)
                    .frame(width: i == page ? 20 : 6, height: 6)
                    .animation(reduceMotion ? nil : Motion.state, value: page)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(page + 1) of \(Self.last + 1)")
    }
}

// MARK: - shared page scaffold

/// Art on top, then the claim, then the detail. Scrolls so the largest Dynamic Type sizes don't clip.
private struct StoryScaffold<Art: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var art: () -> Art

    var body: some View {
        // Centred when the content fits, scrollable when Dynamic Type pushes it past the screen.
        GeometryReader { g in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    art()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityHidden(true)   // the title + detail below say the same thing
                        .padding(.bottom, 28)
                    Text(title)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 8)
                    Text(detail)
                        .font(.body).foregroundStyle(Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .frame(minHeight: g.size.height, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// Draws a mark in when the page becomes the current one. The marked-up content is always visible
/// at rest — only the pen stroke on top animates — so a page that never gets its animation (a
/// headless render, a backgrounded tab) still reads correctly.
private struct Marker: ViewModifier {
    let active: Bool
    @Binding var t: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.onChange(of: active, initial: true) { _, on in
            guard on, t < 1 else { return }
            if reduceMotion { t = 1 } else { withAnimation(Motion.reveal.delay(0.18)) { t = 1 } }
        }
    }
}

private extension View {
    func marks(_ active: Bool, _ t: Binding<CGFloat>) -> some View {
        modifier(Marker(active: active, t: t))
    }
}

// MARK: - 1. the book

private struct HitAWordPage: View {
    let active: Bool
    @State private var t: CGFloat = 0

    var body: some View {
        StoryScaffold(
            title: "You hit a word you don't know.",
            detail: "Mid-chapter, mid-sentence. You could look it up — and lose it in your search history by Tuesday."
        ) {
            VStack(alignment: .leading, spacing: 11) {
                line("She wrote of the")
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("halcyon")
                        .font(.define).foregroundStyle(Color.ink)
                        .overlay(alignment: .bottom) {
                            // the reader's own pen mark — the same stroke the wordmark uses
                            DoodleStroke(progress: t)
                                .stroke(Color.pen, style: .init(lineWidth: 2, lineCap: .round))
                                .frame(height: 7).offset(y: 5)
                        }
                    line(" days before the")
                }
                line("war, when the harbour")
                line("lay flat as glass.")
            }
            .padding(22)
            .sheetSurface(radius: 18)
            .marks(active, $t)
        }
    }

    private func line(_ s: String) -> some View {
        Text(s).font(.define).foregroundStyle(Color.ink2)
    }
}

// MARK: - 2. the lookup

private struct TypeItPage: View {
    let active: Bool
    @State private var t: CGFloat = 0

    var body: some View {
        StoryScaffold(
            title: "Type it. Get one plain sentence.",
            detail: "Then three taps to go deeper — explain it differently, use it in a sentence, more synonyms. There's no blank chat box to fill in."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // the home input, at miniature scale
                HStack(spacing: 8) {
                    Text("halcyon")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 26)).foregroundStyle(Color.pen)
                }

                Rectangle().fill(Color.rule).frame(height: 1)   // what you typed, above; what you got, below

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("halcyon")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.ink)
                        Text("adjective").font(.caption).foregroundStyle(Color.ink2)
                    }
                    Text("Calm and peaceful — usually about a happy stretch of time you're looking back on.")
                        .font(.callout).fontDesign(.serif).foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    chip("Explain it differently")
                    chip("Use it in a sentence")
                }
                .lineLimit(1)
            }
            .padding(20)
            .sheetSurface(radius: 18)
            .marks(active, $t)
        }
    }

    private func chip(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold)).foregroundStyle(Color.pen)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.penWash, in: Capsule())
    }
}

// MARK: - 3. it's kept

private struct KeptPage: View {
    let active: Bool
    @State private var t: CGFloat = 0

    private static let saved = [("halcyon", "adj."), ("sanguine", "adj."), ("ubiquitous", "adj.")]

    var body: some View {
        StoryScaffold(
            title: "It's saved. And it comes back.",
            detail: "Every word you look up files itself away. Flashcards bring them back right before you'd forget them."
        ) {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(Self.saved.enumerated()), id: \.offset) { i, w in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(w.0)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.ink)
                            Text(w.1).font(.caption2).foregroundStyle(Color.ink2)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 11)
                        .overlay(alignment: .bottom) {
                            if i < Self.saved.count - 1 { Rectangle().fill(Color.rule).frame(height: 1) }
                        }
                        // the list fills in top-down as the page arrives
                        .opacity(t >= CGFloat(i + 1) / 3 ? 1 : 0.25)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
                .padding(.trailing, 92)
                .sheetSurface(radius: 18)

                // a flashcard of the top word, lying on the list
                VStack(spacing: 4) {
                    Text("halcyon")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.ink)
                    Text("tap to flip").font(.caption2).foregroundStyle(Color.ink2)
                }
                .frame(width: 116, height: 84)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.sheet)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.rule, lineWidth: 1)
                        }
                        .shadow(color: .shadow, radius: 12, y: 6)
                }
                .rotationEffect(.degrees(-4))
                .offset(x: 10, y: 18)
            }
            .padding(.trailing, 8)
            .marks(active, $t)
        }
    }
}
