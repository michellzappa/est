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
    @State private var showHintWarning = false
    @State private var lastMatchElapsed: TimeInterval = 0
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    var onExit: () -> Void

    private var bestTime: Double {
        variant == .quick ? bestQuickTime : bestFullTime
    }

    private var leaderboardID: String {
        GameCenterManager.leaderboardID(for: variant)
    }

    /// Marketing captures need to communicate the core interaction at a
    /// glance. This is presentation-only: the real engine selection remains
    /// empty until the player taps, so no gameplay or scoring behavior changes.
    private var screenshotSelectedIDs: Set<Int>? {
        guard ProcessInfo.processInfo.arguments.contains("-ESTScreenshotMode"),
              variant == .full else { return nil }
        return Set(engine.table.prefix(3).map(\.id))
    }

    var body: some View {
        VStack(spacing: 12) {
            hud
            BoardGridView(
                engine: engine,
                selectedIDsOverride: screenshotSelectedIDs,
                hintedIDs: hintedIDs,
                pileFrames: pileFrames,
                isInteractive: !engine.isFinished && !engine.isPaused
            ) { card in
                select(card)
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
                        Text("Paused")
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
        .background(Appearance.shared.gameBackground)
        .confirmationDialog("End this game?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("End game", role: .destructive) { onExit() }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("The run and its time are lost.")
        }
        .alert("Use a hint?", isPresented: $showHintWarning) {
            Button("Use hint", role: .destructive) {
                revealHint()
            }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("If you use a hint, this run will not appear on the Game Center leaderboard. Your time can still become a personal best.")
        }
        .onChange(of: showExitConfirm) { _, showing in
            if showing {
                engine.pause()
            } else if !showHintWarning {
                engine.resume()
            }
        }
        .onChange(of: showHintWarning) { _, showing in
            if showing {
                engine.pause()
            } else if !showExitConfirm {
                engine.resume()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if !showExitConfirm && !showHintWarning {
                    engine.resume()
                }
            } else {
                engine.pause()
            }
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: engine.matchToken, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, oldValue.value != newValue.value else { return nil }
            return .success
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: engine.mismatchToken, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, oldValue.value != newValue.value else { return nil }
            return .error
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: engine.isFinished, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, !oldValue.value, newValue.value else { return nil }
            return .success
        }
        .sensoryFeedback(
            trigger: FeedbackTrigger(value: hintedIDs, enabled: hapticsEnabled)
        ) { oldValue, newValue in
            guard newValue.enabled, oldValue.value != newValue.value else { return nil }
            return .impact(flexibility: .rigid, intensity: 0.5)
        }
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
                    runWasPaused: engine.wasPaused,
                    leaderboardID: leaderboardID,
                    onPlayAgain: {
                        submittedScore = false
                        hintUsed = false
                        hintedIDs = []
                        lastMatchElapsed = 0
                        engine.start(variant: variant)
                        ESTTelemetry.record(variant == .quick
                            ? .quickSoloStarted
                            : .fullSoloStarted)
                    },
                    onExit: onExit
                )
            }
        }
        .onAppear {
            lastMatchElapsed = 0
            engine.start(variant: variant)
            ESTTelemetry.record(variant == .quick
                ? .quickSoloStarted
                : .fullSoloStarted)
        }
        .onChange(of: engine.table) {
            hintedIDs = []
        }
        .onChange(of: engine.isFinished) { _, finished in
            if finished {
                GameAudio.shared.play(.completion)
                PlayerStats.shared.recordCompletedRound(variant)
                ESTTelemetry.record(variant == .quick
                    ? .quickSoloCompleted
                    : .fullSoloCompleted)
            }
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
                GameCenterManager.shared.submitSoloTime(
                    time,
                    variant: variant,
                    wasPaused: engine.wasPaused
                )
            }
        }
    }

    private var hud: some View {
        ZStack {
            // The timer sits in a ZStack so it is centered on screen, not
            // between the unequal left and right button groups.
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                Text(TimeFormat.clock(engine.elapsed()))
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
                if variant == .full {
                    Button {
                        if hintUsed {
                            revealHint()
                        } else {
                            showHintWarning = true
                        }
                    } label: {
                        Image(systemName: hintUsed ? "lightbulb.fill" : "lightbulb")
                            .font(.title3)
                            .foregroundStyle(hintUsed ? .orange : .secondary)
                    }
                    .disabled(engine.isFinished)
                    .accessibilityLabel("Hint")
                    .accessibilityHint(hintUsed
                        ? "Reveal a card from a set"
                        : "Ask for a hint. This run will not appear on the leaderboard")
                }
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
        ESTTelemetry.record(.hintUsed)
        GameAudio.shared.play(.hint)
    }

    private func select(_ card: Card) {
        let boardSetCount = Card.countSets(in: engine.table)
        let elapsed = engine.elapsed()
        switch engine.select(card) {
        case .pending:
            break
        case .matched(let cards):
            PlayerStats.shared.recordMatch(
                cards,
                boardSetCount: boardSetCount,
                timeSincePreviousMatch: elapsed - lastMatchElapsed
            )
            lastMatchElapsed = elapsed
        case .mismatched(let cards):
            PlayerStats.shared.recordMismatch(cards, boardSetCount: boardSetCount)
        }
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
    var runWasPaused = false
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
            Text("Complete")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Text(TimeFormat.clock(time))
                .font(.system(size: 52, weight: .black, design: .rounded))
                .monospacedDigit()

            Text("\(setsFound) sets, about \(String(format: "%.0f", time / Double(max(1, setsFound)))) seconds each")
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.85))

            // The zero-sum fact: the leftover always sums to zero, and a
            // leftover with no set is a cap. Never exactly 3 cards.
            Text(leftover == 0
                ? "Perfect clear: all \(totalCards) cards played."
                : "The last \(leftover) cards contain no set. This is a \(leftover)-card cap.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if bestTime > 0 {
                // A personal best is the good news on the card, so it reads
                // as a highlight rather than as another gray footnote.
                Text(time <= bestTime ? "New personal best" : "Best: \(TimeFormat.clock(bestTime))")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(time <= bestTime ? Card.Tint.yellow.color : Color.primary.opacity(0.85))
            }

            if hintUsed {
                Label("Hint used. This run was not submitted.", systemImage: "lightbulb.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if runWasPaused {
                Label("Paused or interrupted. This run was not submitted.", systemImage: "pause.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                Button("Play again", action: onPlayAgain)
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
        .glassCard(cornerRadius: 24)
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

    static func shortSeconds(_ interval: TimeInterval) -> String {
        String(format: "%.1fs", max(0, interval))
    }
}
