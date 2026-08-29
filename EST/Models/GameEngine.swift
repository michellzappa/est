import Foundation
import Observation

/// Core table state shared by solo and party modes: deck, table, done pile,
/// selection, and the deal rules (12 on table, +3 while no set is present).
@Observable
final class GameEngine {
    enum SelectionOutcome {
        case pending
        case matched([Card])
        case mismatched([Card])
    }

    /// Full: all 81 cards, 12 on the table. Quick: the 27 solid cards (the
    /// fill trait is constant, so it drops out of the set logic), 9 on the
    /// table. Same rules otherwise.
    enum Variant: Int, Equatable {
        case full, quick
    }

    private(set) var variant: Variant = .full

    var totalCards: Int { variant == .quick ? 27 : 81 }
    var setsTotal: Int { totalCards / 3 }
    private var tableBaseline: Int { variant == .quick ? 9 : 12 }

    private(set) var deck: [Card] = []
    private(set) var table: [Card] = []
    private(set) var done: [Card] = []
    private(set) var selection: Set<Card> = []
    private(set) var isFinished = false

    private(set) var startDate: Date?
    private(set) var endDate: Date?

    /// Pause support: while paused the clock freezes; paused stretches are
    /// subtracted from elapsed time.
    private var pauseStart: Date?
    private var pausedTotal: TimeInterval = 0

    var isPaused: Bool { pauseStart != nil }

    /// Bumped on every mismatch so views can drive a shake animation.
    private(set) var mismatchToken = 0
    private(set) var lastMismatch: Set<Int> = []
    /// One line per trait the last mismatch broke ("color: red, red vs blue").
    private(set) var mismatchReasons: [String] = []

    /// A matched trio celebrates on the table for a beat before it is
    /// replaced. While non-empty, input is ignored.
    private(set) var celebrationIDs: Set<Int> = []
    /// Bumped on every match, at celebration start — haptic/audio trigger.
    private(set) var matchToken = 0
    /// Called after the engine advances on its own (celebration ends and
    /// replacements are dealt). The network host rebroadcasts here.
    var onAutoAdvance: (() -> Void)?

    static let celebrationDuration: TimeInterval = 0.9
    private var celebrationTask: Task<Void, Never>?
    private var lastMatchDate: Date?

    var setsFound: Int { done.count / 3 }

    func start(variant: Variant = .full) {
        self.variant = variant
        celebrationTask?.cancel()
        celebrationIDs = []
        lastMatchDate = nil
        pauseStart = nil
        pausedTotal = 0
        let source = variant == .quick
            ? Card.fullDeck.filter { $0.fill == .solid }
            : Card.fullDeck
        deck = source.shuffled()
        table = []
        done = []
        selection = []
        isFinished = false
        endDate = nil
        table = Array(deck.prefix(tableBaseline))
        deck.removeFirst(min(tableBaseline, deck.count))
        dealUntilSetAvailable()
        startDate = .now
    }

    func elapsed(at now: Date = .now) -> TimeInterval {
        guard let startDate else { return 0 }
        let effectiveEnd = endDate ?? pauseStart ?? now
        return effectiveEnd.timeIntervalSince(startDate) - pausedTotal
    }

    func pause() {
        guard startDate != nil, !isFinished, pauseStart == nil else { return }
        pauseStart = .now
    }

    func resume() {
        guard let pauseStart else { return }
        pausedTotal += Date.now.timeIntervalSince(pauseStart)
        self.pauseStart = nil
    }

    /// Toggle a card in the selection. Evaluates when the third card lands.
    @discardableResult
    func select(_ card: Card) -> SelectionOutcome {
        guard !isFinished, celebrationIDs.isEmpty, table.contains(card) else { return .pending }
        if selection.contains(card) {
            selection.remove(card)
            return .pending
        }
        selection.insert(card)
        guard selection.count == 3 else { return .pending }

        let picked = Array(selection)
        selection = []
        if Card.isValidSet(picked[0], picked[1], picked[2]) {
            beginCelebration(picked)
            return .matched(picked)
        } else {
            lastMismatch = Set(picked.map(\.id))
            mismatchReasons = Card.violationDescriptions(picked[0], picked[1], picked[2])
            mismatchToken += 1
            return .mismatched(picked)
        }
    }

    func clearSelection() {
        selection = []
    }

    /// Matched cards stay on the table and glow for a beat; the actual
    /// replacement deal happens in `finalizeMatch`.
    private func beginCelebration(_ cards: [Card]) {
        celebrationIDs = Set(cards.map(\.id))
        matchToken += 1
        lastMatchDate = .now
        celebrationTask?.cancel()
        celebrationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.celebrationDuration))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run { self.finalizeMatch(cards) }
        }
    }

    private func finalizeMatch(_ cards: [Card]) {
        guard !celebrationIDs.isEmpty else { return }
        celebrationIDs = []
        resolveMatched(cards)
        onAutoAdvance?()
    }

    private func resolveMatched(_ cards: [Card]) {
        done.append(contentsOf: cards)
        let indices = cards.compactMap { table.firstIndex(of: $0) }.sorted()
        if table.count <= tableBaseline, deck.count >= 3 {
            // Replace in place so the grid stays stable.
            for i in indices {
                table[i] = deck.removeFirst()
            }
        } else {
            for i in indices.reversed() {
                table.remove(at: i)
            }
        }
        dealUntilSetAvailable()
        if deck.isEmpty, Card.findSet(in: table) == nil {
            isFinished = true
            // Clock the finish at the moment of the final match, not after
            // its celebration animation.
            endDate = lastMatchDate ?? .now
        }
    }

    /// The physical game's rule: if the table has no valid set, deal 3 more
    /// (12 -> 15 -> ...), until one exists or the deck runs out.
    private func dealUntilSetAvailable() {
        while Card.findSet(in: table) == nil, !deck.isEmpty {
            let draw = min(3, deck.count)
            table.append(contentsOf: deck.prefix(draw))
            deck.removeFirst(draw)
        }
    }
}
