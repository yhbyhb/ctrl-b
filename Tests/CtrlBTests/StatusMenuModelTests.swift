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
        XCTAssertEqual(StatusMenuModelBuilder.statusItemAppearance(for: .unavailable).title, "⌃b!")
        XCTAssertEqual(StatusMenuModelBuilder.tooltipKey(for: .unavailable), "tooltip.state.unavailable")
    }

    func test_paused_usesPausedIconTitle() {
        XCTAssertEqual(StatusMenuModelBuilder.statusItemAppearance(for: .paused).title, "⌃b⏸")
        XCTAssertEqual(StatusMenuModelBuilder.tooltipKey(for: .paused), "tooltip.state.paused")
    }

    func test_enabled_withoutSecureInput_plainTitleNoImage() {
        let appearance = StatusMenuModelBuilder.statusItemAppearance(
            for: .enabled,
            secureInputActive: false
        )
        XCTAssertEqual(appearance.title, "⌃b")
        XCTAssertNil(appearance.symbolName)
        XCTAssertEqual(
            StatusMenuModelBuilder.tooltipKey(for: .enabled, secureInputActive: false),
            "tooltip.state.enabled"
        )
    }

    func test_enabled_withSecureInput_lockSymbolReplacesExclamation() {
        let appearance = StatusMenuModelBuilder.statusItemAppearance(
            for: .enabled,
            secureInputActive: true
        )
        XCTAssertEqual(appearance.title, "⌃b")
        XCTAssertEqual(appearance.symbolName, "lock.fill")
        XCTAssertEqual(
            StatusMenuModelBuilder.tooltipKey(for: .enabled, secureInputActive: true),
            "tooltip.state.secure_input_active"
        )
    }

    func test_secureInput_doesNotOverride_otherStates() {
        let paused = StatusMenuModelBuilder.statusItemAppearance(
            for: .paused, secureInputActive: true
        )
        XCTAssertEqual(paused.title, "⌃b⏸")
        XCTAssertNil(paused.symbolName)

        let perm = StatusMenuModelBuilder.statusItemAppearance(
            for: .permissionRequired, secureInputActive: true
        )
        XCTAssertEqual(perm.title, "⌃b!")
        XCTAssertNil(perm.symbolName)
        XCTAssertEqual(
            StatusMenuModelBuilder.tooltipKey(for: .permissionRequired, secureInputActive: true),
            "tooltip.state.permission_required"
        )

        let unavail = StatusMenuModelBuilder.statusItemAppearance(
            for: .unavailable, secureInputActive: true
        )
        XCTAssertEqual(unavail.title, "⌃b!")
        XCTAssertNil(unavail.symbolName)
        XCTAssertEqual(
            StatusMenuModelBuilder.tooltipKey(for: .unavailable, secureInputActive: true),
            "tooltip.state.unavailable"
        )
    }
}
