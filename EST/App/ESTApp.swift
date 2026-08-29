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
        case solo
        case party(Int)
        case networkParty
    }

    @State private var screen: Screen = .title
    @State private var showMatchmaker = false
    @State private var networkSession: NetworkPartySession?

    var body: some View {
        ZStack {
            switch screen {
            case .title:
                TitleView(
                    onSolo: { screen = .solo },
                    onParty: { screen = .party($0) },
                    onOnlineParty: { showMatchmaker = true }
                )
                .transition(.opacity)
            case .solo:
                SoloGameView(onExit: { screen = .title })
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
        .onAppear {
            GameCenterManager.shared.authenticate()
        }
    }
}
