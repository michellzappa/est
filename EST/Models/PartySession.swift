import SwiftUI
import Observation

/// Local multiplayer on one device. Nobody can touch the board until a player
/// buzzes; the buzzer then has a short window to pick 3 cards.
@Observable
final class PartySession {
    static let claimWindow: TimeInterval = 3.0
    static let lockoutDuration: TimeInterval = 4.0

    struct Player: Identifiable {
        let id: Int
        let name: String
        let color: Color
        var score = 0
        var lockedUntil: Date?

        func isLocked(at now: Date) -> Bool {
            guard let lockedUntil else { return false }
            return lockedUntil > now
        }
    }

    static let palette: [(String, Color)] = [
        ("P1", Color(red: 0.86, green: 0.18, blue: 0.16)),
        ("P2", Color(red: 0.08, green: 0.36, blue: 0.87)),
        ("P3", Color(red: 0.95, green: 0.71, blue: 0.00)),
        ("P4", Color(red: 0.16, green: 0.65, blue: 0.36)),
    ]

    let engine = GameEngine()
    private(set) var players: [Player]
    private(set) var activePlayerID: Int?
    private(set) var claimDeadline: Date?

    private var expiryTask: Task<Void, Never>?

    init(playerCount: Int) {
        let count = min(max(playerCount, 2), 4)
        players = (0..<count).map { i in
            Player(id: i, name: Self.palette[i].0, color: Self.palette[i].1)
        }
        engine.start()
    }

    var activePlayer: Player? {
        guard let activePlayerID else { return nil }
        return players.first { $0.id == activePlayerID }
    }

    var winners: [Player] {
        let top = players.map(\.score).max() ?? 0
        return players.filter { $0.score == top }
    }

    func canBuzz(_ id: Int, at now: Date = .now) -> Bool {
        guard !engine.isFinished, activePlayerID == nil else { return false }
        guard let player = players.first(where: { $0.id == id }) else { return false }
        return !player.isLocked(at: now)
    }

    func buzz(_ id: Int) {
        guard canBuzz(id) else { return }
        activePlayerID = id
        let deadline = Date.now.addingTimeInterval(Self.claimWindow)
        claimDeadline = deadline
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.claimWindow))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run { self.expireClaim() }
        }
    }

    /// Board taps route through here; ignored unless someone holds the claim.
    func select(_ card: Card) -> GameEngine.SelectionOutcome {
        guard activePlayerID != nil else { return .pending }
        let outcome = engine.select(card)
        switch outcome {
        case .pending:
            break
        case .matched:
            award(points: 1)
            endClaim()
        case .mismatched:
            penalize()
            endClaim()
        }
        return outcome
    }

    private func expireClaim() {
        guard activePlayerID != nil else { return }
        engine.clearSelection()
        penalize()
        endClaim()
    }

    private func award(points: Int) {
        guard let i = players.firstIndex(where: { $0.id == activePlayerID }) else { return }
        players[i].score += points
    }

    private func penalize() {
        guard let i = players.firstIndex(where: { $0.id == activePlayerID }) else { return }
        players[i].score = max(0, players[i].score - 1)
        players[i].lockedUntil = Date.now.addingTimeInterval(Self.lockoutDuration)
    }

    private func endClaim() {
        expiryTask?.cancel()
        expiryTask = nil
        activePlayerID = nil
        claimDeadline = nil
    }
}
