import SwiftUI

struct SoloGameView: View {
    @State private var engine = GameEngine()
    @AppStorage("bestSoloTime") private var bestTime: Double = 0
    @State private var submittedScore = false
    @State private var hintedIDs: Set<Int> = []
    @State private var hintUsed = false
    var onExit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            hud
            BoardGridView(
                engine: engine,
                hintedIDs: hintedIDs,
                isInteractive: !engine.isFinished
            ) { card in
                engine.select(card)
            }
            PilesView(engine: engine)
                .padding(.horizontal, 6)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .sensoryFeedback(.success, trigger: engine.estsFound)
        .sensoryFeedback(.error, trigger: engine.mismatchToken)
        .overlay {
            if engine.isFinished {
                SoloGameOverView(
                    time: engine.elapsed(),
                    bestTime: bestTime,
                    hintUsed: hintUsed,
                    onPlayAgain: {
                        submittedScore = false
                        hintUsed = false
                        hintedIDs = []
                        engine.start()
                    },
                    onExit: onExit
                )
            }
        }
        .onAppear { engine.start() }
        .onChange(of: engine.table) {
            hintedIDs = []
        }
        .onChange(of: engine.isFinished) { _, finished in
            guard finished, !submittedScore else { return }
            submittedScore = true
            let time = engine.elapsed()
            if bestTime == 0 || time < bestTime {
                bestTime = time
            }
            // A hinted run keeps its local best but stays off the leaderboard.
            if !hintUsed {
                GameCenterManager.shared.submitSoloTime(time)
            }
        }
    }

    private var hud: some View {
        HStack {
            Button(action: onExit) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                Text(TimeFormat.clock(engine.elapsed(at: context.date)))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
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
            Text("\(engine.estsFound)/27")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    /// Reveals one card of a valid EST. Marks the run: it will not submit
    /// to the leaderboard.
    private func revealHint() {
        guard let est = Card.findEST(in: engine.table) else { return }
        hintedIDs = [est[0].id]
        hintUsed = true
    }
}

struct SoloGameOverView: View {
    let time: TimeInterval
    let bestTime: Double
    var hintUsed = false
    let onPlayAgain: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VaryingTitleView(fontSize: 40)
            Text("complete")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Text(TimeFormat.clock(time))
                .font(.system(size: 52, weight: .black, design: .rounded))
                .monospacedDigit()

            if bestTime > 0 {
                Text(time <= bestTime ? "new personal best" : "best: \(TimeFormat.clock(bestTime))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if hintUsed {
                Label("hints used — not submitted to leaderboard", systemImage: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 12) {
                Button(action: onPlayAgain) {
                    Text("Play Again")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if GameCenterManager.shared.isAuthenticated {
                    Button("Leaderboard") {
                        GameCenterManager.shared.showLeaderboard()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Menu", action: onExit)
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(24)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }
}

enum TimeFormat {
    /// mm:ss for the in-game clock, mm:ss.cc once finished (under an hour
    /// games are the norm; hours roll into minutes).
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, interval)
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        let centiseconds = Int((total - floor(total)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }
}
