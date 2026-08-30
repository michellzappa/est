import XCTest
@testable import EST

final class CardTests: XCTestCase {
    func testFullDeckContainsEveryCardIDExactlyOnce() {
        let deck = Card.fullDeck

        XCTAssertEqual(deck.count, 81)
        XCTAssertEqual(Set(deck.map(\.id)), Set(0..<81))
    }

    func testCompletingEveryDistinctPairProducesAValidSet() {
        let deck = Card.fullDeck

        for index in deck.indices {
            for otherIndex in deck.indices where otherIndex != index {
                let first = deck[index]
                let second = deck[otherIndex]
                let third = Card.completing(first, second)

                XCTAssertTrue(
                    Card.isValidSet(first, second, third),
                    "Pair \(first.id), \(second.id) completed to invalid card \(third.id)"
                )
                XCTAssertNotEqual(third, first)
                XCTAssertNotEqual(third, second)
            }
        }
    }

    func testAuditIdentifiesEachBrokenTrait() {
        let first = Card(count: 1, tint: .red, symbol: .circle, fill: .solid)
        let second = Card(count: 1, tint: .blue, symbol: .circle, fill: .solid)
        let third = Card(count: 2, tint: .red, symbol: .circle, fill: .solid)

        let verdicts = Card.audit(first, second, third)

        XCTAssertEqual(verdicts.count, 4)
        XCTAssertEqual(verdicts.filter { !$0.isValid }.map(\.label), ["count", "color"])
        XCTAssertEqual(Card.violationDescriptions(first, second, third).count, 2)
    }
}
