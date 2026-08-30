import Foundation

/// Rules for games where the first player to claim a prompt gets a brief,
/// exclusive chance to answer. It intentionally knows nothing about the
/// prompt, scoring, or UI: EST and future games decide what a successful or
/// failed claim means, while this type owns timing and lockouts.
struct ClaimRace<PlayerID: Hashable> {
    struct Configuration: Equatable {
        /// A deliberately modest default for quick, shared-screen games.
        static var standard: Self {
            Self(claimWindow: 5, initialLockout: 4, lockoutEscalation: 1)
        }

        let claimWindow: TimeInterval
        let initialLockout: TimeInterval
        let lockoutEscalation: TimeInterval

        init(
            claimWindow: TimeInterval,
            initialLockout: TimeInterval,
            lockoutEscalation: TimeInterval
        ) {
            self.claimWindow = max(0, claimWindow)
            self.initialLockout = max(0, initialLockout)
            self.lockoutEscalation = max(0, lockoutEscalation)
        }

        /// Penalty one uses the base lockout; each later penalty extends it.
        func lockoutDuration(forPenaltyNumber number: Int) -> TimeInterval {
            initialLockout + TimeInterval(max(0, number - 1)) * lockoutEscalation
        }
    }

    let configuration: Configuration
    private(set) var activePlayerID: PlayerID?
    private(set) var claimDeadline: Date?
    private(set) var lockDeadlines: [PlayerID: Date] = [:]
    private(set) var penaltyCounts: [PlayerID: Int] = [:]

    init(configuration: Configuration = .standard) {
        self.configuration = configuration
    }

    func canClaim(_ playerID: PlayerID, at now: Date = .now) -> Bool {
        activePlayerID == nil && !isLocked(playerID, at: now)
    }

    func isLocked(_ playerID: PlayerID, at now: Date = .now) -> Bool {
        guard let deadline = lockDeadlines[playerID] else { return false }
        return deadline > now
    }

    func lockDeadline(for playerID: PlayerID) -> Date? {
        lockDeadlines[playerID]
    }

    /// Starts an exclusive claim and returns its deadline. The caller owns
    /// scheduling `expire(at:)`, which keeps this state reducer deterministic.
    @discardableResult
    mutating func claim(_ playerID: PlayerID, at now: Date = .now) -> Date? {
        guard canClaim(playerID, at: now) else { return nil }
        let deadline = now.addingTimeInterval(configuration.claimWindow)
        activePlayerID = playerID
        claimDeadline = deadline
        return deadline
    }

    /// Clears a claim after the owning player resolves it. Supplying an owner
    /// prevents a late event from one player clearing another player's claim.
    @discardableResult
    mutating func releaseClaim(heldBy playerID: PlayerID? = nil) -> PlayerID? {
        guard let activePlayerID else { return nil }
        guard playerID == nil || playerID == activePlayerID else { return nil }
        self.activePlayerID = nil
        claimDeadline = nil
        return activePlayerID
    }

    /// Releases an overdue claim and returns its owner so the game can apply
    /// its own failure rule.
    @discardableResult
    mutating func expire(at now: Date = .now) -> PlayerID? {
        guard let claimDeadline, claimDeadline <= now else { return nil }
        return releaseClaim()
    }

    /// Applies the configured escalating lockout and returns its deadline.
    @discardableResult
    mutating func penalize(_ playerID: PlayerID, at now: Date = .now) -> Date {
        let count = penaltyCounts[playerID, default: 0] + 1
        penaltyCounts[playerID] = count
        let deadline = now.addingTimeInterval(
            configuration.lockoutDuration(forPenaltyNumber: count)
        )
        lockDeadlines[playerID] = deadline
        return deadline
    }

    /// Clients adopt the host's clock-normalized values from a snapshot. A
    /// host never calls this; it retains its local penalty history.
    mutating func adoptAuthoritativeState(
        activePlayerID: PlayerID?,
        claimDeadline: Date?,
        lockDeadlines: [PlayerID: Date]
    ) {
        self.activePlayerID = activePlayerID
        self.claimDeadline = claimDeadline
        self.lockDeadlines = lockDeadlines
    }
}
