import SwiftUI

/// Local multiplayer on one device. Even-numbered players sit on the bottom
/// edge, odd-numbered on the top (their controls render upside down).
struct PartyGameView: View {
    @State private var session: PartySession
    var onExit: () -> Void

    init(playerCount: Int, onExit: @escaping () -> Void) {
        _session = State(initialValue: PartySession(playerCount: playerCount))
        self.onExit = onExit
    }

    private var topPlayers: [PartySession.Player] {
        session.players.filter { $0.id % 2 == 1 }
    }

    private var bottomPlayers: [PartySession.Player] {
        session.players.filter { $0.id % 2 == 0 }
    }

    var body: some View {
        VStack(spacing: 10) {
            playerRow(topPlayers, flipped: true)

            HStack {
                Button(action: onExit) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusLabel
                Spacer()
                Text("\(session.engine.deck.count) left")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            BoardGridView(
                engine: session.engine,
                isInteractive: session.activePlayerID != nil && !session.engine.isFinished
            ) { card in
                _ = session.select(card)
            }
            .overlay {
                if let active = session.activePlayer {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(active.color, lineWidth: 3)
                        .padding(-8)
                        .allowsHitTesting(false)
                }
            }

            playerRow(bottomPlayers, flipped: false)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .sensoryFeedback(.success, trigger: session.engine.estsFound)
        .sensoryFeedback(.error, trigger: session.engine.mismatchToken)
        .overlay {
            if session.engine.isFinished {
                PartyGameOverView(session: session, onExit: onExit)
            }
        }
    }

    private var statusLabel: some View {
        Group {
            if let active = session.activePlayer {
                Text("\(active.name) — tap 3 cards!")
                    .font(.headline)
                    .foregroundStyle(active.color)
            } else {
                Text("see one? hit your button")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func playerRow(_ players: [PartySession.Player], flipped: Bool) -> some View {
        HStack(spacing: 12) {
            ForEach(players) { player in
                BuzzButton(session: session, playerID: player.id)
                    .rotationEffect(flipped ? .degrees(180) : .zero)
            }
        }
        .frame(height: players.isEmpty ? 0 : 76)
    }
}

/// A player's claim button: name, score, and — while they hold the claim —
/// a draining countdown bar for the selection window.
private struct BuzzButton: View {
    let session: PartySession
    let playerID: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            let now = context.date
            let player = session.players.first { $0.id == playerID }!
            let isActive = session.activePlayerID == playerID
            let isLocked = player.isLocked(at: now)
            let enabled = session.canBuzz(playerID, at: now)

            Button {
                session.buzz(playerID)
            } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 6) {
                        Text(player.name)
                            .font(.caption.bold())
                        Text("\(player.score)")
                            .font(.title3.monospacedDigit().bold())
                    }
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
                            .font(.caption2)
                    } else {
                        Text("EST!")
                            .font(.caption2.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(player.color.opacity(isActive ? 1 : isLocked ? 0.25 : 0.8))
                )
                .foregroundStyle(.white)
            }
            .disabled(!enabled && !isActive)
        }
    }
}

private struct PartyGameOverView: View {
    let session: PartySession
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VaryingTitleView(fontSize: 40)
            let winners = session.winners
            Text(winners.count == 1 ? "\(winners[0].name) wins" : "draw")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(winners.count == 1 ? winners[0].color : .primary)

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
            .padding(.horizontal, 32)

            Button("Menu", action: onExit)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(24)
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }
}
