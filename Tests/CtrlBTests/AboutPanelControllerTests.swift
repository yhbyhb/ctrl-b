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
            currentInputSource: { InputSourceDisplay(flag: "🇰🇷", name: "Korean", isIME: true) },
            secureInputMonitor: StubSecureInputMonitor(active: false)
        )
        XCTAssertFalse(sut.buildCredits().string.contains("idle"))
    }

    func test_buildCredits_noIME_showsIdleSuffix() {
        let sut = AboutPanelController(
            stats: StatisticsManager(defaults: makeTestDefaults()),
            currentInputSource: { InputSourceDisplay(flag: "🇺🇸", name: "ABC", isIME: false) },
            secureInputMonitor: StubSecureInputMonitor(active: false)
        )
        XCTAssertTrue(sut.buildCredits().string.contains("idle"))
    }

    func test_buildCredits_largeCount_formatsWithCommas() {
        let defaults = makeTestDefaults()
        defaults.set(1_234_567, forKey: "remapCount")
        let sut = AboutPanelController(
            stats: StatisticsManager(defaults: defaults),
            currentInputSource: { InputSourceDisplay(flag: "🌐", name: "Unknown", isIME: false) },
            secureInputMonitor: StubSecureInputMonitor(active: false)
        )
        XCTAssertTrue(sut.buildCredits().string.contains("1,234,567"))
    }

    func test_buildCredits_secureInputActive_includesLockWarning() {
        let sut = AboutPanelController(
            stats: StatisticsManager(defaults: makeTestDefaults()),
            currentInputSource: { InputSourceDisplay(flag: "🇰🇷", name: "Korean", isIME: true) },
            secureInputMonitor: StubSecureInputMonitor(active: true)
        )
        let text = sut.buildCredits().string
        XCTAssertTrue(text.contains("Secure Keyboard Entry"))
        XCTAssertTrue(text.contains("🔒"))
    }

    func test_buildCredits_secureInputInactive_omitsLockWarning() {
        let sut = AboutPanelController(
            stats: StatisticsManager(defaults: makeTestDefaults()),
            currentInputSource: { InputSourceDisplay(flag: "🇰🇷", name: "Korean", isIME: true) },
            secureInputMonitor: StubSecureInputMonitor(active: false)
        )
        XCTAssertFalse(sut.buildCredits().string.contains("Secure Keyboard Entry"))
    }
}

private struct StubSecureInputMonitor: SecureInputMonitoring {
    let active: Bool
    func isActive() -> Bool { active }
}

private func makeSUT(isIME: Bool = false) -> AboutPanelController {
    AboutPanelController(
        stats: StatisticsManager(defaults: makeTestDefaults()),
        currentInputSource: { InputSourceDisplay(flag: "🌐", name: "Unknown", isIME: isIME) },
        secureInputMonitor: StubSecureInputMonitor(active: false)
    )
}

private func makeTestDefaults() -> UserDefaults {
    UserDefaults(suiteName: UUID().uuidString) ?? .standard
}
