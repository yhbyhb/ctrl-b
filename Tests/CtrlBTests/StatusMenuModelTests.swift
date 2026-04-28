import XCTest
@testable import CtrlB

final class StatusMenuModelTests: XCTestCase {
    func test_permissionRequired_showsRecoveryActions() {
        let model = StatusMenuModelBuilder.build(for: .permissionRequired)

        XCTAssertEqual(model.statusTitleKey, "menu.state.permission_required")
        XCTAssertEqual(
            model.primaryItems,
            [
                StatusMenuPrimaryItem(
                    titleKey: "menu.action.open_accessibility_settings",
                    action: .openAccessibilitySettings
                ),
                StatusMenuPrimaryItem(titleKey: "menu.action.check_again", action: .checkAgain)
            ]
        )
    }

    func test_enabled_showsPauseOnly() {
        let model = StatusMenuModelBuilder.build(for: .enabled)

        XCTAssertEqual(model.statusTitleKey, "menu.state.enabled")
        XCTAssertEqual(
            model.primaryItems,
            [StatusMenuPrimaryItem(titleKey: "menu.action.pause", action: .pause)]
        )
    }

    func test_paused_showsResumeOnly() {
        let model = StatusMenuModelBuilder.build(for: .paused)

        XCTAssertEqual(model.statusTitleKey, "menu.state.paused")
        XCTAssertEqual(
            model.primaryItems,
            [StatusMenuPrimaryItem(titleKey: "menu.action.resume", action: .resume)]
        )
    }

    func test_unavailable_usesWarningIconTitle() {
        XCTAssertEqual(StatusMenuModelBuilder.statusItemTitle(for: .unavailable), "⌃b!")
        XCTAssertEqual(StatusMenuModelBuilder.tooltipKey(for: .unavailable), "tooltip.state.unavailable")
    }

    func test_paused_usesPausedIconTitle() {
        XCTAssertEqual(StatusMenuModelBuilder.statusItemTitle(for: .paused), "⌃b⏸")
        XCTAssertEqual(StatusMenuModelBuilder.tooltipKey(for: .paused), "tooltip.state.paused")
    }

    func test_enabled_withSecureInput_usesWarningIconTitle() {
        XCTAssertEqual(
            StatusMenuModelBuilder.statusItemTitle(for: .enabled, secureInputActive: true),
            "⌃b!"
        )
        XCTAssertEqual(
            StatusMenuModelBuilder.tooltipKey(for: .enabled, secureInputActive: true),
            "tooltip.state.secure_input_active"
        )
    }

    func test_enabled_withoutSecureInput_usesPlainTitle() {
        XCTAssertEqual(
            StatusMenuModelBuilder.statusItemTitle(for: .enabled, secureInputActive: false),
            "⌃b"
        )
        XCTAssertEqual(
            StatusMenuModelBuilder.tooltipKey(for: .enabled, secureInputActive: false),
            "tooltip.state.enabled"
        )
    }

    func test_secureInput_doesNotOverride_otherStates() {
        XCTAssertEqual(
            StatusMenuModelBuilder.statusItemTitle(for: .paused, secureInputActive: true),
            "⌃b⏸"
        )
        XCTAssertEqual(
            StatusMenuModelBuilder.statusItemTitle(for: .permissionRequired, secureInputActive: true),
            "⌃b!"
        )
        XCTAssertEqual(
            StatusMenuModelBuilder.tooltipKey(for: .permissionRequired, secureInputActive: true),
            "tooltip.state.permission_required"
        )
        XCTAssertEqual(
            StatusMenuModelBuilder.statusItemTitle(for: .unavailable, secureInputActive: true),
            "⌃b!"
        )
        XCTAssertEqual(
            StatusMenuModelBuilder.tooltipKey(for: .unavailable, secureInputActive: true),
            "tooltip.state.unavailable"
        )
    }
}
