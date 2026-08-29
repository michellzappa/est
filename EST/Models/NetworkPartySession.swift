import GameKit
import SwiftUI
import Observation

/// Party mode across devices over a GKMatch (online or nearby).
///
/// The device with the lowest gamePlayerID is the host and runs the only real
/// `GameEngine`. Clients render snapshots and send buzz/select events. Claim
/// window and lockout reuse the constants in `PartySession`.
@Observable
final class NetworkPartySession {
    struct PlayerDisplay: Identifiable {
        let id: String
        let name: String
        let color: Color
        var score: Int
        var lockedUntil: Date?

        func isLocked(at now: Date) -> Bool {
            guard let lockedUntil else { return false }
            return lockedUntil > now
        }
    }

    let match: GKMatch
    let isHost: Bool
    let localID = GKLocalPlayer.local.gamePlayerID

    // Display state. On the host this mirrors the engine; on clients it is
    // whatever the last snapshot said.
    private(set) var players: [PlayerDisplay] = []
    private(set) var table: [Card] = []
    private(set) var selectedIDs: Set<Int> = []
    private(set) var mismatchIDs: Set<Int> = []
    private(set) var mismatchToken = 0
    private(set) var mismatchReasons: [String] = []
    private(set) var celebrationIDs: Set<Int> = []
    private(set) var matchToken = 0
    private(set) var deckCount = 0
    private(set) var doneCount = 0
    private(set) var doneTop: Card?
    private(set) var activePlayerID: String?
    private(set) var claimDeadline: Date?
    private(set) var isFinished = false
    private(set) var someoneLeft = false

    // Host-only authority.
    private let engine = GameEngine()
    private var roster: [(id: String, name: String)] = []
    private var scores: [String: Int] = [:]
    private var locks: [String: Date] = [:]
    private var expiryTask: Task<Void, Never>?
    private let remoteHost: GKPlayer?

    private let proxy = MatchDelegateProxy()

    init(match: GKMatch) {
        self.match = match
        let everyone = (match.players + [GKLocalPlayer.local])
            .sorted { $0.gamePlayerID < $1.gamePlayerID }
        let hostID = everyone.first?.gamePlayerID
        isHost = hostID == GKLocalPlayer.local.gamePlayerID
        remoteHost = match.players.first { $0.gamePlayerID == hostID }

        proxy.onData = { [weak self] data, player in
            DispatchQueue.main.async { self?.receive(data, from: player.gamePlayerID) }
        }
        proxy.onStateChange = { [weak self] _, state in
            DispatchQueue.main.async {
                if state == .disconnected { self?.someoneLeft = true }
            }
        }
        match.delegate = proxy

        if isHost {
            roster = everyone.map { ($0.gamePlayerID, $0.displayName) }
            for entry in roster { scores[entry.id] = 0 }
            engine.onAutoAdvance = { [weak self] in self?.publishAndBroadcast() }
            engine.start()
            publishAndBroadcast()
        }
    }

    var localPlayer: PlayerDisplay? {
        players.first { $0.id == localID }
    }

    var winners: [PlayerDisplay] {
        let top = players.map(\.score).max() ?? 0
        return players.filter { $0.score == top }
    }

    func canBuzzLocally(at now: Date = .now) -> Bool {
        guard !isFinished, activePlayerID == nil else { return false }
        guard let localPlayer else { return true }
        return !localPlayer.isLocked(at: now)
    }

    func buzzLocal() {
        if isHost {
            handleBuzz(from: localID)
        } else {
            send(.event(.buzz))
        }
    }

    func selectLocal(_ card: Card) {
        guard activePlayerID == localID else { return }
        if isHost {
            handleSelect(from: localID, cardID: card.id)
        } else {
            send(.event(.select(card.id)))
        }
    }

    func leave() {
        expiryTask?.cancel()
        match.delegate = nil
        match.disconnect()
    }

    // MARK: - Host authority

    private func handleBuzz(from playerID: String) {
        guard isHost, !engine.isFinished, activePlayerID == nil else { return }
        if let lock = locks[playerID], lock > .now { return }
        activePlayerID = playerID
        claimDeadline = Date.now.addingTimeInterval(PartySession.claimWindow)
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(PartySession.claimWindow))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run { self.expireClaim() }
        }
        publishAndBroadcast()
    }

    private func handleSelect(from playerID: String, cardID: Int) {
        guard isHost, activePlayerID == playerID else { return }
        guard let card = engine.table.first(where: { $0.id == cardID }) else { return }
        switch engine.select(card) {
        case .pending:
            break
        case .matched:
            scores[playerID, default: 0] += 1
            endClaim()
        case .mismatched:
            penalize(playerID)
            endClaim()
        }
        publishAndBroadcast()
    }

    private func expireClaim() {
        guard isHost, let activePlayerID else { return }
        engine.clearSelection()
        penalize(activePlayerID)
        endClaim()
        publishAndBroadcast()
    }

    private func penalize(_ playerID: String) {
        scores[playerID] = max(0, (scores[playerID] ?? 0) - 1)
        locks[playerID] = Date.now.addingTimeInterval(PartySession.lockoutDuration)
    }

    private func endClaim() {
        expiryTask?.cancel()
        expiryTask = nil
        activePlayerID = nil
        claimDeadline = nil
    }

    /// Host: mirror the engine into the display fields, then broadcast.
    private func publishAndBroadcast() {
        table = engine.table
        selectedIDs = Set(engine.selection.map(\.id))
        mismatchIDs = engine.lastMismatch
        mismatchToken = engine.mismatchToken
        mismatchReasons = engine.mismatchReasons
        celebrationIDs = engine.celebrationIDs
        matchToken = engine.matchToken
        deckCount = engine.deck.count
        doneCount = engine.done.count
        doneTop = engine.done.last
        isFinished = engine.isFinished
        players = roster.enumerated().map { index, entry in
            PlayerDisplay(
                id: entry.id,
                name: entry.name,
                color: PartySession.palette[index % PartySession.palette.count].1,
                score: scores[entry.id] ?? 0,
                lockedUntil: locks[entry.id]
            )
        }

        let now = Date.now
        let snapshot = NetSnapshot(
            players: roster.enumerated().map { index, entry in
                NetSnapshot.PlayerState(
                    id: entry.id,
                    name: entry.name,
                    colorIndex: index % PartySession.palette.count,
                    score: scores[entry.id] ?? 0,
                    lockRemaining: locks[entry.id].flatMap {
                        $0 > now ? $0.timeIntervalSince(now) : nil
                    }
                )
            },
            tableIDs: table.map(\.id),
            selectedIDs: Array(selectedIDs),
            mismatchIDs: Array(mismatchIDs),
            mismatchToken: mismatchToken,
            mismatchReasons: mismatchReasons,
            celebrationIDs: Array(celebrationIDs),
            matchToken: matchToken,
            deckCount: deckCount,
            doneCount: doneCount,
            doneTopID: doneTop?.id,
            activePlayerID: activePlayerID,
            claimRemaining: claimDeadline.map { $0.timeIntervalSince(now) },
            isFinished: isFinished
        )
        send(.snapshot(snapshot))
    }

    // MARK: - Wire

    private func send(_ message: NetMessage) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        if isHost {
            try? match.sendData(toAllPlayers: data, with: .reliable)
        } else if let remoteHost {
            try? match.send(data, to: [remoteHost], dataMode: .reliable)
        }
    }

    private func receive(_ data: Data, from senderID: String) {
        guard let message = try? JSONDecoder().decode(NetMessage.self, from: data) else { return }
        switch message {
        case .event(let event):
            guard isHost else { return }
            switch event {
            case .buzz:
                handleBuzz(from: senderID)
            case .select(let cardID):
                handleSelect(from: senderID, cardID: cardID)
            }
        case .snapshot(let snapshot):
            guard !isHost else { return }
            apply(snapshot)
        }
    }

    /// Client: adopt the host's snapshot, mapping remaining-times onto the
    /// local clock.
    private func apply(_ snapshot: NetSnapshot) {
        let now = Date.now
        players = snapshot.players.map { state in
            PlayerDisplay(
                id: state.id,
                name: state.name,
                color: PartySession.palette[state.colorIndex].1,
                score: state.score,
                lockedUntil: state.lockRemaining.map { now.addingTimeInterval($0) }
            )
        }
        table = snapshot.tableIDs.map { Card(id: $0) }
        selectedIDs = Set(snapshot.selectedIDs)
        mismatchIDs = Set(snapshot.mismatchIDs)
        mismatchToken = snapshot.mismatchToken
        mismatchReasons = snapshot.mismatchReasons
        celebrationIDs = Set(snapshot.celebrationIDs)
        matchToken = snapshot.matchToken
        deckCount = snapshot.deckCount
        doneCount = snapshot.doneCount
        doneTop = snapshot.doneTopID.map { Card(id: $0) }
        activePlayerID = snapshot.activePlayerID
        claimDeadline = snapshot.claimRemaining.map { now.addingTimeInterval($0) }
        isFinished = snapshot.isFinished
    }

    private final class MatchDelegateProxy: NSObject, GKMatchDelegate {
        var onData: ((Data, GKPlayer) -> Void)?
        var onStateChange: ((GKPlayer, GKPlayerConnectionState) -> Void)?

        func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
            onData?(data, player)
        }

        func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
            onStateChange?(player, state)
        }
    }
}
