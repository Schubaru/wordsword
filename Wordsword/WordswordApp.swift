import AuthenticationServices
import SwiftUI
import SwiftData

@main
struct WordswordApp: App {
    @State private var router = Router()
    @State private var auth = Auth()
    @State private var splashDone = false
    @Environment(\.scenePhase) private var scenePhase

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
            // Apple can unlink the account from outside the app (Settings → Sign in with Apple):
            // check once on launch, and listen in case it happens while the app is open.
            .task { await auth.checkCredential() }
            .onReceive(NotificationCenter.default.publisher(
                for: ASAuthorizationAppleIDProvider.credentialRevokedNotification).receive(on: RunLoop.main)) { _ in
                auth.signOut()
            }
            #if DEBUG
            .task { Auth.selfCheck() }
            .task { Dictionary.selfCheck(); Simplifier.selfCheck() }
            .task { await Task.detached { Level.selfCheck() }.value }
            .task { await Task.detached { LinkingPuzzle.selfCheck() }.value }
            // `SIMCTL_CHILD_OPEN_ROUTE=wordWheel simctl launch …` lands on a screen for screenshots.
            .task { if ProcessInfo.processInfo.environment["OPEN_ROUTE"] == "wordWheel" { router.path = [.games, .wordWheel] } }
            .task { if ProcessInfo.processInfo.environment["OPEN_ROUTE"] == "linkingWords" { router.path = [.linkingWords] } }
            .task { await Task.detached { PlexiconWords.selfCheck() }.value }
            .task { if ProcessInfo.processInfo.environment["OPEN_ROUTE"] == "plexicon" { router.path = [.plexicon] } }
            .task { await Task.detached { HaikuzyBank.selfCheck() }.value }
            .task { if ProcessInfo.processInfo.environment["OPEN_ROUTE"] == "haikuzy" { router.path = [.haikuzy] } }
            .task { DebugSnapshots.runIfRequested(router, auth) }
            #endif
            // wordsword://define               → focus the input (the search widget)
            // wordsword://define?word=halcyon   → straight into the chat (the word-of-the-day widget)
            // wordsword://play?game=plexicon    → a game (the game widgets; see `Route(game:)`)
            // Arriving mid-onboarding is fine: the route waits on the router and opens as soon as
            // Home exists, rather than being dropped on the floor.
            .onOpenURL { url in
                let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
                func query(_ name: String) -> String? { items?.first { $0.name == name }?.value }
                switch url.host {
                case "define":
                    if let w = query("word"), !w.isEmpty { router.path = [.define(w)] } else { router.path = []; router.focusInput = true }
                case "play":
                    if let route = query("game").flatMap(Route.init(game:)) { router.path = [route] }
                default: break
                }
            }
            // Hand the widget the week's words and meanings whenever the app comes forward. A beat
            // late, so it never crowds the first lookup (or the banner's own fetch of today's word).
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                await WordOfTheDay.shareWeek()
            }
        }
        .modelContainer(for: [Word.self, Tag.self, Wordlist.self])
    }
}

enum Route: Hashable {
    case define(String)
    case resume([String])                  // a chain picked back up: the trail is restored, the last word re-defined
    case library
    case wordlist(PersistentIdentifier?)   // nil = "All"
    case flashcards(PersistentIdentifier?)
    case settings
    case games                             // the hub: every game, and the words they turned up
    case wordWheel
    case linkingWords
    case plexicon
    case haikuzy
    case wordsFound

    /// The `game` in a `wordsword://play` link. The names are the widgets' (`WidgetLink.play`).
    init?(game: String) {
        switch game {
        case "haiklu":        self = .haikuzy
        case "linking-words": self = .linkingWords
        case "plexicon":      self = .plexicon
        case "word-wheel":    self = .wordWheel
        default: return nil
        }
    }
}

@Observable final class Router {
    var path: [Route] = []
    var focusInput = false
    /// DEBUG-only remote control for DebugSnapshots; views watch this and perform the named action.
    var debug = ""
}
