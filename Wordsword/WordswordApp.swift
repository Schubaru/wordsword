import SwiftUI
import SwiftData

@main
struct WordswordApp: App {
    @State private var router = Router()
    @State private var auth = Auth()
    @State private var splashDone = false

    var body: some Scene {
        WindowGroup {
            Group {
                // splash → story + account (first run only) → the input
                if !splashDone {
                    SplashView { splashDone = true }
                } else if !auth.hasSeenStory {
                    OnboardingView()
                } else {
                    HomeView()
                }
            }
            .animation(Motion.reveal, value: splashDone)
            .animation(Motion.reveal, value: auth.hasSeenStory)
            .environment(router)
            .environment(auth)
            .tint(.pen)
            #if DEBUG
            .task { DebugSnapshots.runIfRequested(router, auth) }
            #endif
            // wordsword://define            → focus the input (future widget)
            // wordsword://define?word=halcyon → straight into the chat
            // Arriving mid-onboarding is fine: the route waits on the router and opens as soon as
            // Home exists, rather than being dropped on the floor.
            .onOpenURL { url in
                guard url.host == "define" else { return }
                let w = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "word" }?.value
                if let w, !w.isEmpty { router.path = [.define(w)] } else { router.path = []; router.focusInput = true }
            }
        }
        .modelContainer(for: [Word.self, Tag.self, Wordlist.self])
    }
}

enum Route: Hashable {
    case define(String)
    case library
    case wordlist(PersistentIdentifier?)   // nil = "All"
    case flashcards(PersistentIdentifier?)
    case settings
}

@Observable final class Router {
    var path: [Route] = []
    var focusInput = false
    /// DEBUG-only remote control for DebugSnapshots; views watch this and perform the named action.
    var debug = ""
}
