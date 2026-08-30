import Foundation
import Observation

/// Private, aggregate learning stats. Nothing in this model is sent to
/// telemetry: it stays in this app's UserDefaults and can be reset by the
/// player at any time.
@MainActor
@Observable
final class PlayerStats {
    struct Snapshot: Codable, Equatable {
        var completedSoloRounds = 0
        var quickSoloRounds = 0
        var fullSoloRounds = 0
        var attempts = 0
        var correctSets = 0
        /// Index 1...4 is the number of all-different traits in a set.
        var correctByDifference = [Int](repeating: 0, count: 5)
        var secondsByDifference = [TimeInterval](repeating: 0, count: 5)
        /// Order matches Card.audit: count, color, shape, fill.
        var mismatchesByTrait = [Int](repeating: 0, count: 4)
        /// Board opportunity buckets: 0, 1, 2, or 3+ valid sets available.
        var boardSetBuckets = [Int](repeating: 0, count: 4)
        var nearMisses = 0
    }

    static let shared = PlayerStats()

    private static let storageKey = "estPlayerStats"
    private let defaults: UserDefaults
    private(set) var snapshot: Snapshot

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = saved
        } else {
            snapshot = Snapshot()
        }
    }

    var completedSoloRounds: Int { snapshot.completedSoloRounds }
    var quickSoloRounds: Int { snapshot.quickSoloRounds }
    var fullSoloRounds: Int { snapshot.fullSoloRounds }
    var attempts: Int { snapshot.attempts }
    var correctSets: Int { snapshot.correctSets }
    var mismatches: Int { max(0, snapshot.attempts - snapshot.correctSets) }
    var nearMisses: Int { snapshot.nearMisses }
    var correctByDifference: [Int] { snapshot.correctByDifference }
    var mismatchesByTrait: [Int] { snapshot.mismatchesByTrait }
    var boardSetBuckets: [Int] { snapshot.boardSetBuckets }

    var accuracy: Double {
        guard attempts > 0 else { return 0 }
        return Double(correctSets) / Double(attempts)
    }

    func averageTime(for differenceCount: Int) -> TimeInterval? {
        guard (1...4).contains(differenceCount),
              snapshot.correctByDifference[differenceCount] > 0
        else { return nil }
        return snapshot.secondsByDifference[differenceCount]
            / Double(snapshot.correctByDifference[differenceCount])
    }

    /// Records a valid set after GameEngine has accepted it. The difficulty
    /// axis comes from Card.audit, so this model does not duplicate set math.
    func recordMatch(
        _ cards: [Card],
        boardSetCount: Int,
        timeSincePreviousMatch: TimeInterval
    ) {
        guard cards.count == 3 else { return }
        snapshot.attempts += 1
        snapshot.correctSets += 1
        let differenceCount = Card.audit(cards[0], cards[1], cards[2])
            .filter {
                if case .allDifferent = $0.outcome { return true }
                return false
            }
            .count
        if (1...4).contains(differenceCount) {
            snapshot.correctByDifference[differenceCount] += 1
            snapshot.secondsByDifference[differenceCount] += max(
                0, timeSincePreviousMatch)
        }
        recordBoardOpportunity(boardSetCount)
        save()
    }

    /// Records an invalid three-card attempt and the traits that broke it.
    func recordMismatch(_ cards: [Card], boardSetCount: Int) {
        guard cards.count == 3 else { return }
        snapshot.attempts += 1
        let verdicts = Card.audit(cards[0], cards[1], cards[2])
        let violations = verdicts.enumerated().filter { !$0.element.isValid }
        for (index, _) in violations where index < snapshot.mismatchesByTrait.count {
            snapshot.mismatchesByTrait[index] += 1
        }
        if violations.count == 1 {
            snapshot.nearMisses += 1
        }
        recordBoardOpportunity(boardSetCount)
        save()
    }

    func recordCompletedRound(_ variant: GameEngine.Variant) {
        snapshot.completedSoloRounds += 1
        switch variant {
        case .full:
            snapshot.fullSoloRounds += 1
        case .quick:
            snapshot.quickSoloRounds += 1
        }
        save()
    }

    func reset() {
        snapshot = Snapshot()
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func recordBoardOpportunity(_ count: Int) {
        let bucket = min(max(count, 0), 3)
        snapshot.boardSetBuckets[bucket] += 1
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
