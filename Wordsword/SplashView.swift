import SwiftUI

/// The cover of the notebook opening. ~900ms, then it gets out of the way on its own.
///
/// It earns the delay by doing the app's one signature move — the sword slash cutting the wordmark
/// into the page — and by covering the SwiftData container load, so the first real screen never
/// appears half-built. It is never a tap target and never a dead end: `onDone` always fires.
struct SplashView: View {
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var slash: CGFloat = 0
    @State private var sword = false

    var body: some View {
        ZStack {
            PaperBackground()
            VStack(spacing: 22) {
                SwordDoodle(color: .pen)
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(sword ? 0 : -16), anchor: .bottomLeading)
                    .opacity(sword ? 1 : 0)
                Wordmark(font: .headword)
                    .slashReveal(slash, edge: .pen)
            }
        }
        .task {
            guard !reduceMotion else {
                sword = true; slash = 1
                try? await Task.sleep(for: .milliseconds(450))
                onDone(); return
            }
            withAnimation(Motion.state) { sword = true }
            try? await Task.sleep(for: .milliseconds(140))
            withAnimation(Motion.slash) { slash = 1 }
            try? await Task.sleep(for: .milliseconds(740))
            onDone()
        }
    }
}
