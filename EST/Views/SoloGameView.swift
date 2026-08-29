import SwiftUI

struct SoloGameView: View {
    var variant: GameEngine.Variant = .full
    @State private var engine = GameEngine()
    @AppStorage("bestSoloTime") private var bestFullTime: Double = 0
    @AppStorage("bestQuickTime") private var bestQuickTime: Double = 0
    @State private var submittedScore = false
    @State private var hintedIDs: Set<Int> = []
    @State private var hintUsed = false
    @State private var pileFrames = PileFrames()
    @State private var showExitConfirm = false
    @Environment(\.scenePhase) private var scenePhase
    var onExit: () -> Void

    private var bestTime: Double {
        variant == .quick ? bestQuickTime : bestFullTime
    }

    private var leaderboardID: String {
        variant == .quick
            ? GameCenterManager.quickLeaderboardID
            : GameCenterManager.soloLeaderboardID
    }

    var body: some View {
        VStack(spacing: 12) {
            hud
            BoardGridView(
                engine: engine,
                hintedIDs: hintedIDs,
                pileFrames: pileFrames,
                isInteractive: !engine.isFinished && !engine.isPaused
            ) { card in
                engine.select(card)
            }
            .overlay(alignment: .bottom) {
                MismatchExplainer(reasons: engine.mismatchReasons, token: engine.mismatchToken)
                    .padding(.bottom, 6)
            }
            .overlay {
                if engine.isPaused {
                    VStack(spacing: 8) {
                        Image(systemName: "pause.circle.fill")
                            .font(.largeTitle)
                        Text("paused")
                            .font(.headline)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(.secondary)
                    .padding(28)
                    .glassPanel(cornerRadius: 20)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: engine.isPaused)
            PilesView(engine: engine)
                .padding(.horizontal, 6)
        }
        .padding()
        .coordinateSpace(name: "game")
        .onPreferenceChange(PileFramesKey.self) { pileFrames = $0 }
        .background(Color(.systemGroupedBackground))
        .confirmationDialog("End this game?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("End Game", role: .destructive) { onExit() }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("The run and its time are lost.")
        }
        .onChange(of: showExitConfirm) { _, showing in
            if showing {
                engine.pause()
            } else {
                engine.resume()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if !showExitConfirm {
                    engine.resume()
                }
            } else {
                engine.pause()
            }
        }
        .sensoryFeedback(.success, trigger: engine.matchToken)
        .sensoryFeedback(.error, trigger: engine.mismatchToken)
        .sensoryFeedback(.success, trigger: engine.isFinished)
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.5), trigger: hintedIDs)
        .overlay {
            if engine.isFinished {
                SoloGameOverView(
                    time: engine.elapsed(),
                    bestTime: bestTime,
                    setsFound: engine.setsFound,
                    setsTotal: engine.setsTotal,
                    leftover: engine.table.count,
                    totalCards: engine.totalCards,
                    hintUsed: hintUsed,
                    leaderboardID: leaderboardID,
                    onPlayAgain: {
                        submittedScore = false
                        hintUsed = false
                        hintedIDs = []
                        engine.start(variant: variant)
                    },
                    onExit: onExit
                )
            }
        }
        .onAppear { engine.start(variant: variant) }
        .onChange(of: engine.table) {
            hintedIDs = []
        }
        .onChange(of: engine.isFinished) { _, finished in
            guard finished, !submittedScore else { return }
            submittedScore = true
            let time = engine.elapsed()
            if bestTime == 0 || time < bestTime {
                if variant == .quick {
                    bestQuickTime = time
                } else {
                    bestFullTime = time
                }
            }
            // A hinted run keeps its local best but stays off the leaderboard.
            if !hintUsed {
                GameCenterManager.shared.submitSoloTime(time, leaderboardID: leaderboardID)
            }
        }
    }

    private var hud: some View {
        ZStack {
            // The timer sits in a ZStack so it is centered on screen, not
            // between the unequal left and right button groups.
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                Text(TimeFormat.clock(engine.elapsed(at: context.date)))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
            }
            HStack {
                Button {
                    if engine.isFinished {
                        onExit()
                    } else {
                        showExitConfirm = true
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    revealHint()
                } label: {
                    Image(systemName: hintUsed ? "lightbulb.fill" : "lightbulb")
                        .font(.title3)
                        .foregroundStyle(hintUsed ? .orange : .secondary)
                }
                .disabled(engine.isFinished)
                Text("\(engine.setsFound)/\(engine.setsTotal)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Reveals one card of a valid set. Marks the run: it will not submit
    /// to the leaderboard.
    private func revealHint() {
        guard let set = Card.findSet(in: engine.table) else { return }
        hintedIDs = [set[0].id]
        hintUsed = true
    }
}

struct SoloGameOverView: View {
    let time: TimeInterval
    let bestTime: Double
    var setsFound = 27
    var setsTotal = 27
    var leftover = 0
    var totalCards = 81
    var hintUsed = false
    var leaderboardID = GameCenterManager.soloLeaderboardID
    let onPlayAgain: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            ConfettiView()
                .ignoresSafeArea()
            card
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    private var card: some View {
        VStack(spacing: 20) {
            VaryingTitleView(fontSize: 40)
            Text("complete")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Text(TimeFormat.clock(time))
                .font(.system(size: 52, weight: .black, design: .rounded))
                .monospacedDigit()

            Text("\(setsFound) sets, about \(String(format: "%.0f", time / Double(max(1, setsFound)))) seconds each")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // The zero-sum fact: the leftover always sums to zero, and a
            // leftover with no set is a cap. Never exactly 3 cards.
            Text(leftover == 0
                ? "perfect clear, all \(totalCards) cards played"
                : "the last \(leftover) cards hide no set (a \(leftover)-card cap)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if bestTime > 0 {
                Text(time <= bestTime ? "new personal best" : "best: \(TimeFormat.clock(bestTime))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if hintUsed {
                Label("hints used, not submitted to leaderboard", systemImage: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 10) {
                Button("Play Again", action: onPlayAgain)
                    .buttonStyle(.game(.primary, tint: .blue, size: .large))

                if GameCenterManager.shared.isAuthenticated {
                    Button("Leaderboard") {
                        GameCenterManager.shared.showLeaderboard(id: leaderboardID)
                    }
                    .buttonStyle(.game(.secondary, tint: .yellow))
                }

                Button("Menu", action: onExit)
                    .buttonStyle(.game(.quiet))
            }
            .padding(.horizontal, 24)
        }
        .padding(32)
        .glassPanel(cornerRadius: 24)
        .padding(24)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }
}

enum TimeFormat {
    /// mm:ss everywhere. The leaderboard still receives centiseconds; only
    /// the display rounds.
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
