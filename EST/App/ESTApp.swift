import SwiftUI

@main
struct ESTApp: App {
    @State private var supportStore = SupportStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(supportStore)
                .task {
                    if !ProcessInfo.processInfo.arguments.contains("-ESTScreenshotMode") {
                        TelemetryCoordinator.shared.start()
                    }
                    await supportStore.start()
                }
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
    /// Games can use the full screen by hiding system game chrome. This is
    /// intentionally app-wide so every game mode feels the same.
    @AppStorage("immersiveGameMode") private var immersiveGameMode = true
    @State private var showTutorial = false

    /// The marketing screenshot test needs a clean title screen on every run.
    /// This launch argument is only consumed by UI-test launches; normal users
    /// still get the first-launch tutorial.
    private var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-ESTScreenshotMode")
    }

    private var isGameScreen: Bool {
        switch screen {
        case .title: false
        case .solo, .party, .networkParty: true
        }
    }

    private var shouldHideGameChrome: Bool {
        isGameScreen && immersiveGameMode
    }

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
        .statusBarHidden(shouldHideGameChrome)
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
                ESTTelemetry.record(.tutorialViewed)
                showTutorial = false
            }
            .interactiveDismissDisabled()
        }
        .onAppear {
            updateGameCenterAccessPoint()
            if !isScreenshotMode {
                GameCenterManager.shared.authenticate()
            }
            if !isScreenshotMode && !hasSeenTutorial {
                showTutorial = true
            }
        }
        .onChange(of: screen) { _, _ in
            updateGameCenterAccessPoint()
        }
        .onChange(of: immersiveGameMode) { _, _ in
            updateGameCenterAccessPoint()
        }
    }

    private func updateGameCenterAccessPoint() {
        GameCenterManager.shared.setAccessPointVisible(screen == .title && !shouldHideGameChrome)
    }
}
