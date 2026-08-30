import XCTest
@testable import EST

final class PartySessionTests: XCTestCase {
    func testLockoutDurationAddsOneSecondForEachPenalty() {
        let configuration = ClaimRace<Int>.Configuration.standard
        XCTAssertEqual(configuration.lockoutDuration(forPenaltyNumber: 1), 4)
        XCTAssertEqual(configuration.lockoutDuration(forPenaltyNumber: 2), 5)
        XCTAssertEqual(configuration.lockoutDuration(forPenaltyNumber: 3), 6)
    }
}
