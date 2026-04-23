import XCTest
import AppKit
@testable import CtrlB
@testable import CtrlBCore

final class AboutPanelControllerTests: XCTestCase {
    func test_buildCredits_containsKeycapDemo() {
        let credits = makeSUT().buildCredits().string
        XCTAssertTrue(credits.contains("⌃b"))
    }

    func test_buildCredits_containsStatsLabels() {
        let credits = makeSUT().buildCredits().string
        XCTAssertTrue(credits.contains("Remapped"))
        XCTAssertTrue(credits.contains("Saved"))
    }

    func test_buildCredits_containsLinks() {
        let credits = makeSUT().buildCredits().string
        XCTAssertTrue(credits.contains("GitHub"))
        XCTAssertTrue(credits.contains("Ko-fi"))
    }

    func test_buildCredits_activeIME_omitsIdleSuffix() {
        let sut = AboutPanelController(
            stats: StatisticsManager(defaults: makeTestDefaults()),
            currentInputSource: { InputSourceDisplay(flag: "🇰🇷", name: "Korean", isIME: true) }
        )
        XCTAssertFalse(sut.buildCredits().string.contains("idle"))
    }

    func test_buildCredits_noIME_showsIdleSuffix() {
        let sut = AboutPanelController(
            stats: StatisticsManager(defaults: makeTestDefaults()),
            currentInputSource: { InputSourceDisplay(flag: "🇺🇸", name: "ABC", isIME: false) }
        )
        XCTAssertTrue(sut.buildCredits().string.contains("idle"))
    }

    func test_buildCredits_largeCount_formatsWithCommas() {
        let defaults = makeTestDefaults()
        defaults.set(1_234_567, forKey: "remapCount")
        let sut = AboutPanelController(
            stats: StatisticsManager(defaults: defaults),
            currentInputSource: { InputSourceDisplay(flag: "🌐", name: "Unknown", isIME: false) }
        )
        XCTAssertTrue(sut.buildCredits().string.contains("1,234,567"))
    }
}

private func makeSUT(isIME: Bool = false) -> AboutPanelController {
    AboutPanelController(
        stats: StatisticsManager(defaults: makeTestDefaults()),
        currentInputSource: { InputSourceDisplay(flag: "🌐", name: "Unknown", isIME: isIME) }
    )
}

private func makeTestDefaults() -> UserDefaults {
    UserDefaults(suiteName: UUID().uuidString) ?? .standard
}
