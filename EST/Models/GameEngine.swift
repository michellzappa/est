import Foundation
import Observation

/// Core table state shared by solo and party modes: deck, table, done pile,
/// selection, and the deal rules (12 on table, +3 while no EST is present).
@Observable
final class GameEngine {
    enum SelectionOutcome {
        case pending
        case matched([Card])
        case mismatched([Card])
    }

    private(set) var deck: [Card] = []
    private(set) var table: [Card] = []
    private(set) var done: [Card] = []
    private(set) var selection: Set<Card> = []
    private(set) var isFinished = false

    private(set) var startDate: Date?
    private(set) var endDate: Date?

    /// Bumped on every mismatch so views can drive a shake animation.
    private(set) var mismatchToken = 0
    private(set) var lastMismatch: Set<Int> = []

    var estsFound: Int { done.count / 3 }

    func start() {
        deck = Card.fullDeck.shuffled()
        table = []
        done = []
        selection = []
        isFinished = false
        endDate = nil
        table = Array(deck.prefix(12))
        deck.removeFirst(min(12, deck.count))
        dealUntilESTAvailable()
        startDate = .now
    }

    func elapsed(at now: Date = .now) -> TimeInterval {
        guard let startDate else { return 0 }
        return (endDate ?? now).timeIntervalSince(startDate)
    }

    /// Toggle a card in the selection. Evaluates when the third card lands.
    @discardableResult
    func select(_ card: Card) -> SelectionOutcome {
        guard !isFinished, table.contains(card) else { return .pending }
        if selection.contains(card) {
            selection.remove(card)
            return .pending
        }
        selection.insert(card)
        guard selection.count == 3 else { return .pending }

        let picked = Array(selection)
        selection = []
        if Card.isEST(picked[0], picked[1], picked[2]) {
            resolveMatched(picked)
            return .matched(picked)
        } else {
            lastMismatch = Set(picked.map(\.id))
            mismatchToken += 1
            return .mismatched(picked)
        }
    }

    func clearSelection() {
        selection = []
    }

    private func resolveMatched(_ cards: [Card]) {
        done.append(contentsOf: cards)
        let indices = cards.compactMap { table.firstIndex(of: $0) }.sorted()
        if table.count <= 12, deck.count >= 3 {
            // Replace in place so the grid stays stable.
            for i in indices {
                table[i] = deck.removeFirst()
            }
        } else {
            for i in indices.reversed() {
                table.remove(at: i)
            }
        }
        dealUntilESTAvailable()
        if deck.isEmpty, Card.findEST(in: table) == nil {
            isFinished = true
            endDate = .now
        }
    }

    /// The physical game's rule: if the table has no valid set, deal 3 more
    /// (12 -> 15 -> ...), until one exists or the deck runs out.
    private func dealUntilESTAvailable() {
        while Card.findEST(in: table) == nil, !deck.isEmpty {
            let draw = min(3, deck.count)
            table.append(contentsOf: deck.prefix(draw))
            deck.removeFirst(draw)
        }
    }
}
