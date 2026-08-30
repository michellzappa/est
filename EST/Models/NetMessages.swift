import Foundation

/// Wire format for multi-device party play. The host device is authoritative:
/// clients send events, the host sends full state snapshots after every
/// change. Snapshots are tiny (a few hundred bytes of JSON), so no deltas.
enum NetMessage: Codable {
    case event(NetEvent)
    case snapshot(NetSnapshot)
}

/// Client -> host.
enum NetEvent: Codable {
    case buzz
    case select(Int)
}

/// Host -> everyone. Times cross the wire as remaining seconds, not dates,
/// because device clocks are not trusted to agree.
struct NetSnapshot: Codable {
    struct PlayerState: Codable {
        /// GKPlayer.gamePlayerID
        let id: String
        let name: String
        /// Index into PartySession.palette, assigned by the host.
        let colorIndex: Int
        var score: Int
        /// Physical cards won by this player; score remains separate because
        /// penalties affect points but do not remove cards from a player's pile.
        var cardCount: Int
        var topCardID: Int?
        var lockRemaining: TimeInterval?
    }

    var players: [PlayerState]
    var tableIDs: [Int]
    var selectedIDs: [Int]
    var mismatchIDs: [Int]
    var mismatchToken: Int
    var mismatchReasons: [String]
    var celebrationIDs: [Int]
    var matchToken: Int
    var dealToken: Int
    var penaltyToken: Int
    var deckCount: Int
    var doneCount: Int
    var doneTopID: Int?
    var activePlayerID: String?
    var claimRemaining: TimeInterval?
    var isFinished: Bool
}
