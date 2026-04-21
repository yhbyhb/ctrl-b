import ApplicationServices
import Foundation
import AppKit

private let accessibilitySettingsURLString =
    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

protocol AccessibilityPermissionControlling {
    func promptIfNeededOnFirstLaunch() -> Bool
    func isTrusted() -> Bool
    func openSettings()
}

final class AccessibilityPermissionController: AccessibilityPermissionControlling {
    private let defaults: UserDefaults
    private let hasPromptedKey: String

    init(
        defaults: UserDefaults = .standard,
        hasPromptedKey: String = "hasPromptedForAccessibilityPermission"
    ) {
        self.defaults = defaults
        self.hasPromptedKey = hasPromptedKey
    }

    func promptIfNeededOnFirstLaunch() -> Bool {
        if defaults.bool(forKey: hasPromptedKey) {
            return isTrusted()
        }

        defaults.set(true, forKey: hasPromptedKey)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func openSettings() {
        guard let url = URL(string: accessibilitySettingsURLString) else { return }
        NSWorkspace.shared.open(url)
    }
}
