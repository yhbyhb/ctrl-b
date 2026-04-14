import XCTest
@testable import CtrlBHelperCore

final class StatisticsManagerTests: XCTestCase {
    var sut: StatisticsManager!
    var testDefaults: UserDefaults!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        // 각 테스트마다 격리된 UserDefaults 사용
        suiteName = "TestSuite_\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        sut = StatisticsManager(defaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        sut = nil
        testDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - 초기값

    func test_initialCount_isZero() {
        XCTAssertEqual(sut.remapCount, 0)
    }

    func test_initialTimeSaved_isZero() {
        XCTAssertEqual(sut.timeSavedSeconds, 0, accuracy: 0.001)
    }

    func test_initialTodayCount_isZero() {
        XCTAssertEqual(sut.todayRemapCount, 0)
    }

    // MARK: - recordRemap()

    func test_record_incrementsCount() {
        sut.recordRemap()
        XCTAssertEqual(sut.remapCount, 1)
    }

    func test_record_twice_count2() {
        sut.recordRemap()
        sut.recordRemap()
        XCTAssertEqual(sut.remapCount, 2)
    }

    func test_record_accumulatesTimeSaved() {
        sut.recordRemap()
        XCTAssertEqual(sut.timeSavedSeconds, StatisticsManager.secondsPerRemap, accuracy: 0.001)
    }

    func test_record_twice_timeSaved() {
        sut.recordRemap()
        sut.recordRemap()
        XCTAssertEqual(sut.timeSavedSeconds, StatisticsManager.secondsPerRemap * 2, accuracy: 0.001)
    }

    func test_record_incrementsTodayCount() {
        sut.recordRemap()
        XCTAssertEqual(sut.todayRemapCount, 1)
    }

    // MARK: - reset()

    func test_reset_clearsCount() {
        sut.recordRemap()
        sut.reset()
        XCTAssertEqual(sut.remapCount, 0)
    }

    func test_reset_clearsTimeSaved() {
        sut.recordRemap()
        sut.reset()
        XCTAssertEqual(sut.timeSavedSeconds, 0, accuracy: 0.001)
    }

    func test_reset_clearsTodayCount() {
        sut.recordRemap()
        sut.reset()
        XCTAssertEqual(sut.todayRemapCount, 0)
    }

    // MARK: - formattedTimeSaved (누계)

    func test_format_seconds() {
        sut.recordRemap()  // 3.5초
        XCTAssertTrue(sut.formattedTimeSaved.hasSuffix("초"), "Expected 초, got: \(sut.formattedTimeSaved)")
    }

    func test_format_minutes() {
        for _ in 0..<20 { sut.recordRemap() }  // 70초 → 분 단위
        XCTAssertTrue(sut.formattedTimeSaved.hasSuffix("분"), "Expected 분, got: \(sut.formattedTimeSaved)")
    }

    func test_format_hours() {
        for _ in 0..<1200 { sut.recordRemap() }  // 4200초 → 시간 단위
        XCTAssertTrue(sut.formattedTimeSaved.hasSuffix("시간"), "Expected 시간, got: \(sut.formattedTimeSaved)")
    }

    func test_format_boundary_59seconds() {
        // 59.5초 = 17회 (17 * 3.5 = 59.5)
        for _ in 0..<17 { sut.recordRemap() }
        XCTAssertTrue(sut.formattedTimeSaved.hasSuffix("초"))
    }

    func test_format_boundary_60seconds() {
        // 63.0초 = 18회 (18 * 3.5 = 63.0)
        for _ in 0..<18 { sut.recordRemap() }
        XCTAssertTrue(sut.formattedTimeSaved.hasSuffix("분"))
    }

    // MARK: - todayTimeSavedSeconds

    func test_todayTimeSaved_matchesCount() {
        sut.recordRemap()
        sut.recordRemap()
        XCTAssertEqual(
            sut.todayTimeSavedSeconds,
            Double(sut.todayRemapCount) * StatisticsManager.secondsPerRemap,
            accuracy: 0.001
        )
    }
}
