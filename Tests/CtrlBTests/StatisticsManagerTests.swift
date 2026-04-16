import XCTest
@testable import CtrlBCore

final class StatisticsManagerTests: XCTestCase {
    var sut: StatisticsManager!
    var testDefaults: UserDefaults!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "TestSuite_\(UUID().uuidString)"
        // swiftlint:disable:next force_unwrapping
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

    // MARK: - Initial values

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

    // MARK: - timeSavedSeconds is computed from remapCount

    func test_timeSaved_isComputedFromCount() {
        sut.recordRemap()
        sut.recordRemap()
        sut.recordRemap()
        XCTAssertEqual(sut.timeSavedSeconds, Double(sut.remapCount) * StatisticsManager.secondsPerRemap, accuracy: 0.001)
    }

    // MARK: - Day boundary reset

    func test_todayCount_resetsOnNewDay() {
        var currentDate = Date()
        let manager = StatisticsManager(defaults: testDefaults) { currentDate }

        manager.recordRemap()
        manager.recordRemap()
        XCTAssertEqual(manager.todayRemapCount, 2)

        // Advance to tomorrow
        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!  // swiftlint:disable:this force_unwrapping
        XCTAssertEqual(manager.todayRemapCount, 0, "Today count should reset on new day")
    }

    func test_todayCount_resetsOnNewDay_cumulativeUnchanged() {
        var currentDate = Date()
        let manager = StatisticsManager(defaults: testDefaults) { currentDate }

        manager.recordRemap()
        manager.recordRemap()

        // Advance to tomorrow
        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!  // swiftlint:disable:this force_unwrapping
        XCTAssertEqual(manager.remapCount, 2, "Cumulative count should not reset on new day")
    }

    func test_recordRemap_onNewDay_startsFresh() {
        var currentDate = Date()
        let manager = StatisticsManager(defaults: testDefaults) { currentDate }

        manager.recordRemap()
        manager.recordRemap()

        // Advance to tomorrow and record
        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!  // swiftlint:disable:this force_unwrapping
        manager.recordRemap()

        XCTAssertEqual(manager.todayRemapCount, 1, "Today count should be 1 after reset + new record")
        XCTAssertEqual(manager.remapCount, 3, "Cumulative count should include all days")
    }
}
