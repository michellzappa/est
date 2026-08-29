import SwiftUI

/// Multi-device party: every player holds their own phone. Opponents show as
/// score chips up top; your buzz button sits at the bottom.
struct NetworkPartyGameView: View {
    let session: NetworkPartySession
    @State private var pileFrames = PileFrames()
    @State private var showExitConfirm = false
    var onExit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            opponentsRow

            HStack {
                Button {
                    if session.isFinished || session.someoneLeft {
                        exit()
                    } else {
                        showExitConfirm = true
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusLabel
                Spacer()
            }
            .padding(.horizontal, 4)

            BoardGridView(
                table: session.table,
                selectedIDs: session.selectedIDs,
                mismatchIDs: session.mismatchIDs,
                mismatchToken: session.mismatchToken,
                celebrationIDs: session.celebrationIDs,
                collectedCount: session.doneCount,
                pileFrames: pileFrames,
                isInteractive: session.activePlayerID == session.localID && !session.isFinished
            ) { card in
                session.selectLocal(card)
            }
            .overlay {
                if let activeID = session.activePlayerID,
                   let active = session.players.first(where: { $0.id == activeID }) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(active.color, lineWidth: 3)
                        .padding(-8)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottom) {
                MismatchExplainer(
                    reasons: session.mismatchReasons,
                    token: session.mismatchToken
                )
                .padding(.bottom, 6)
            }

            HStack(spacing: 16) {
                PilesView(
                    deckCount: session.deckCount,
                    doneCount: session.doneCount,
                    doneTop: session.doneTop
                )
                localBuzzButton
            }
        }
        .padding()
        .coordinateSpace(name: "game")
        .onPreferenceChange(PileFramesKey.self) { pileFrames = $0 }
        .background(Color(.systemGroupedBackground))
        .confirmationDialog("Leave the match?", isPresented: $showExitConfirm, titleVisibility: .visible) {
            Button("Leave Match", role: .destructive) { exit() }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("Leaving ends the match for everyone.")
        }
        .sensoryFeedback(.success, trigger: session.matchToken)
        .sensoryFeedback(.error, trigger: session.mismatchToken)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: session.activePlayerID)
        .sensoryFeedback(.success, trigger: session.isFinished)
        .overlay {
            if session.someoneLeft {
                endCard {
                    Text("a player disconnected")
                        .font(.headline)
                }
            } else if session.isFinished {
                endCard(celebratory: true) {
                    let winners = session.winners
                    Text(winners.count == 1 ? "\(winners[0].name) wins" : "draw")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(winners.count == 1 ? winners[0].color : .primary)
                    scoreList
                }
            }
        }
        .onDisappear {
            session.leave()
        }
    }

    private func exit() {
        session.leave()
        onExit()
    }

    private var opponentsRow: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            HStack(spacing: 8) {
                ForEach(session.players.filter { $0.id != session.localID }) { player in
                    HStack(spacing: 6) {
                        Circle().fill(player.color).frame(width: 10, height: 10)
                        Text(player.name)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Text("\(player.score)")
                            .font(.caption.monospacedDigit().bold())
                        if player.isLocked(at: context.date) {
                            Image(systemName: "hourglass")
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            player.color.opacity(session.activePlayerID == player.id ? 0.35 : 0.12)
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var statusLabel: some View {
        Group {
            if let activeID = session.activePlayerID,
               let active = session.players.first(where: { $0.id == activeID }) {
                Text(activeID == session.localID ? "tap 3 cards!" : "\(active.name) is picking…")
                    .font(.headline)
                    .foregroundStyle(active.color)
            } else {
                Text("see one? buzz!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var localBuzzButton: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            let now = context.date
            let me = session.localPlayer
            let isActive = session.activePlayerID == session.localID
            let isLocked = me?.isLocked(at: now) ?? false
            let enabled = session.canBuzzLocally(at: now)
            let color = me?.color ?? .accentColor

            Button {
                session.buzzLocal()
            } label: {
                VStack(spacing: 2) {
                    Text("\(me?.score ?? 0)")
                        .font(.title2.monospacedDigit().bold())
                    if isActive, let deadline = session.claimDeadline {
                        let progress = max(0, deadline.timeIntervalSince(now) / PartySession.claimWindow)
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white)
                                .frame(width: proxy.size.width * progress)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 4)
                    } else if isLocked {
                        Image(systemName: "hourglass")
                            .font(.caption)
                    } else {
                        Text("EST!")
                            .font(.headline.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassButtonSurface(
                    tint: color,
                    opacity: isActive ? 1 : isLocked ? 0.25 : 0.85,
                    cornerRadius: 16
                )
                .foregroundStyle(.white)
            }
            .disabled(!enabled && !isActive)
        }
    }

    private var scoreList: some View {
        VStack(spacing: 8) {
            ForEach(session.players.sorted { $0.score > $1.score }) { player in
                HStack {
                    Circle().fill(player.color).frame(width: 12, height: 12)
                    Text(player.name)
                    Spacer()
                    Text("\(player.score)")
                        .monospacedDigit()
                        .bold()
                }
                .font(.headline)
            }
        }
        .padding(.horizontal, 24)
    }

    private func endCard(
        celebratory: Bool = false,
        @ViewBuilder content: () -> some View
    ) -> some View {
        ZStack {
            if celebratory {
                ConfettiView()
                    .ignoresSafeArea()
            }
            VStack(spacing: 20) {
                VaryingTitleView(fontSize: 40)
                content()
                Button("Menu", action: exit)
                    .buttonStyle(.game(.primary, tint: .blue, size: .large))
                    .padding(.horizontal, 24)
            }
            .padding(32)
            .glassCard(cornerRadius: 24)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }
}
