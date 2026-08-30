import Foundation
import XCTest
@testable import EST

final class ClaimRaceTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    func testFirstClaimWinsUntilItIsReleased() {
        var race = ClaimRace<String>()

        let deadline = race.claim("one", at: start)

        XCTAssertEqual(deadline, start.addingTimeInterval(5))
        XCTAssertNil(race.claim("two", at: start))
        XCTAssertEqual(race.activePlayerID, "one")
        XCTAssertNil(race.releaseClaim(heldBy: "two"))
        XCTAssertEqual(race.releaseClaim(heldBy: "one"), "one")
        XCTAssertTrue(race.canClaim("two", at: start))
    }

    func testExpiryReleasesOnlyAnOverdueClaim() {
        var race = ClaimRace<String>()
        _ = race.claim("one", at: start)

        XCTAssertNil(race.expire(at: start.addingTimeInterval(4.99)))
        XCTAssertEqual(race.expire(at: start.addingTimeInterval(5)), "one")
        XCTAssertNil(race.activePlayerID)
    }

    func testPenaltiesEscalateAndBlockOnlyThePenalizedPlayer() {
        var race = ClaimRace<String>()

        let firstLock = race.penalize("one", at: start)
        let secondLock = race.penalize("one", at: start.addingTimeInterval(10))

        XCTAssertEqual(firstLock, start.addingTimeInterval(4))
        XCTAssertEqual(secondLock, start.addingTimeInterval(15))
        XCTAssertTrue(race.isLocked("one", at: start.addingTimeInterval(11)))
        XCTAssertFalse(race.isLocked("two", at: start.addingTimeInterval(11)))
        XCTAssertFalse(race.isLocked("one", at: start.addingTimeInterval(15)))
    }
}
