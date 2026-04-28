import Foundation

enum EventTapState: Equatable {
    case permissionRequired
    case enabled
    case paused
    case unavailable
}

enum EventTapStateChangeReason: String {
    case launch
    case initialPromptShown
    case permissionMissing
    case permissionGranted
    case checkAgainRequested
    case tapCreateFailed
    case userPaused
    case userResumed
    case tapDisabledByTimeout
    case tapDisabledByUserInput
}

enum StatusMenuPrimaryAction: Equatable {
    case pause
    case resume
    case openAccessibilitySettings
    case checkAgain
}

struct StatusMenuPrimaryItem: Equatable {
    let titleKey: String
    let action: StatusMenuPrimaryAction
}

struct StatusMenuModel: Equatable {
    let statusTitleKey: String
    let primaryItems: [StatusMenuPrimaryItem]
}

enum StatusMenuModelBuilder {
    static func build(for state: EventTapState) -> StatusMenuModel {
        switch state {
        case .permissionRequired:
            return StatusMenuModel(
                statusTitleKey: "menu.state.permission_required",
                primaryItems: [
                    StatusMenuPrimaryItem(
                        titleKey: "menu.action.open_accessibility_settings",
                        action: .openAccessibilitySettings
                    ),
                    StatusMenuPrimaryItem(titleKey: "menu.action.check_again", action: .checkAgain)
                ]
            )
        case .enabled:
            return StatusMenuModel(
                statusTitleKey: "menu.state.enabled",
                primaryItems: [
                    StatusMenuPrimaryItem(titleKey: "menu.action.pause", action: .pause)
                ]
            )
        case .paused:
            return StatusMenuModel(
                statusTitleKey: "menu.state.paused",
                primaryItems: [
                    StatusMenuPrimaryItem(titleKey: "menu.action.resume", action: .resume)
                ]
            )
        case .unavailable:
            return StatusMenuModel(
                statusTitleKey: "menu.state.unavailable",
                primaryItems: [
                    StatusMenuPrimaryItem(titleKey: "menu.action.open_accessibility_settings", action: .openAccessibilitySettings),
                    StatusMenuPrimaryItem(titleKey: "menu.action.check_again", action: .checkAgain)
                ]
            )
        }
    }

    static func tooltipKey(for state: EventTapState, secureInputActive: Bool = false) -> String {
        switch state {
        case .permissionRequired:
            return "tooltip.state.permission_required"
        case .enabled:
            return secureInputActive ? "tooltip.state.secure_input_active" : "tooltip.state.enabled"
        case .paused:
            return "tooltip.state.paused"
        case .unavailable:
            return "tooltip.state.unavailable"
        }
    }

    static func statusItemTitle(for state: EventTapState, secureInputActive: Bool = false) -> String {
        switch state {
        case .permissionRequired, .unavailable:
            return "⌃b!"
        case .enabled:
            return secureInputActive ? "⌃b!" : "⌃b"
        case .paused:
            return "⌃b⏸"
        }
    }
}
