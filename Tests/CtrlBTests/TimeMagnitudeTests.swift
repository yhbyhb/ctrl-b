import XCTest
@testable import CtrlBCore

final class TimeMagnitudeTests: XCTestCase {
    // MARK: - Seconds branch

    func test_zero_isSeconds() {
        XCTAssertEqual(TimeMagnitude(0), .seconds(0))
    }

    func test_belowOneMinute_isSeconds() {
        XCTAssertEqual(TimeMagnitude(30), .seconds(30))
        XCTAssertEqual(TimeMagnitude(59), .seconds(59))
    }

    // MARK: - Minutes branch

    func test_exactlyOneMinute_isMinutes() {
        XCTAssertEqual(TimeMagnitude(60), .minutes(1))
    }

    func test_twoMinutes_isMinutes() {
        XCTAssertEqual(TimeMagnitude(120), .minutes(2))
    }

    func test_justBelowOneHour_isMinutes() {
        XCTAssertEqual(TimeMagnitude(3599), .minutes(3599.0 / 60.0))
    }

    // MARK: - Hours branch

    func test_exactlyOneHour_isHours() {
        XCTAssertEqual(TimeMagnitude(3600), .hours(1))
    }

    func test_twoHours_isHours() {
        XCTAssertEqual(TimeMagnitude(7200), .hours(2))
    }

    func test_largeValue_isHours() {
        XCTAssertEqual(TimeMagnitude(36000), .hours(10))
    }
}
