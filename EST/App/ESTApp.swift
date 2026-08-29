import SwiftUI

@main
struct ESTApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    enum Screen: Equatable {
        case title
        case solo(GameEngine.Variant)
        case party(Int)
        case networkParty
    }

    @State private var screen: Screen = .title
    @State private var showMatchmaker = false
    @State private var networkSession: NetworkPartySession?
    /// First launch opens the tutorial over the title screen. Set once the
    /// learner finishes or skips it; the rules sheet replays it on demand.
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false

    var body: some View {
        ZStack {
            switch screen {
            case .title:
                TitleView(
                    onSolo: { screen = .solo(.full) },
                    onQuickSolo: { screen = .solo(.quick) },
                    onParty: { screen = .party($0) },
                    onOnlineParty: { showMatchmaker = true }
                )
                .transition(.opacity)
            case .solo(let variant):
                SoloGameView(variant: variant, onExit: { screen = .title })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .party(let count):
                PartyGameView(playerCount: count, onExit: { screen = .title })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .networkParty:
                if let networkSession {
                    NetworkPartyGameView(session: networkSession) {
                        self.networkSession = nil
                        screen = .title
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(duration: 0.4), value: screen)
        .sheet(isPresented: $showMatchmaker) {
            MatchmakerView(
                onMatch: { match in
                    showMatchmaker = false
                    networkSession = NetworkPartySession(match: match)
                    screen = .networkParty
                },
                onDismiss: { showMatchmaker = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView {
                hasSeenTutorial = true
                showTutorial = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            GameCenterManager.shared.authenticate()
            if !hasSeenTutorial {
                showTutorial = true
            }
        }
    }
}
