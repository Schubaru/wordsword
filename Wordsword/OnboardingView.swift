import SwiftUI

/// First run: the story, then the account.
///
/// The order is deliberate. The account ask is the highest-friction moment in the app, so it lands
/// after the three screens that show what an account is *for*, never in front of them. Replaying
/// the story from Settings skips the account step for anyone already signed in.
struct OnboardingView: View {
    @Environment(Auth.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var storyDone = false

    var body: some View {
        Group {
            if storyDone {
                AccountFlow(laterTitle: "Maybe later") { auth.finishOnboarding() }
                    .transition(.opacity)
            } else {
                StoryView {
                    if auth.isSignedIn {
                        auth.finishOnboarding()      // replaying from Settings — don't ask twice
                    } else {
                        withAnimation(reduceMotion ? nil : Motion.state) { storyDone = true }
                    }
                }
                .transition(.opacity)
            }
        }
        .background(PaperBackground())
        #if DEBUG
        .onChange(of: router.debug) { _, d in
            if d == "story:done" { storyDone = true }
        }
        #endif
    }
    @Environment(Router.self) private var router
}
