import Foundation

/// Human-readable representation of the current keyboard input source,
/// intended for display in UI such as the About panel.
public struct InputSourceDisplay: Equatable {
    public let flag: String
    public let name: String
    public let isIME: Bool

    public init(flag: String, name: String, isIME: Bool) {
        self.flag = flag
        self.name = name
        self.isIME = isIME
    }
}

/// Maps TIS-provided fields to a display struct.
///
/// - `languageTag`: first element of `kTISPropertyInputSourceLanguages`
///   (e.g. `"ko"`, `"ja"`, `"zh-Hans"`, `"zh-Hans-CN"`).
/// - `localizedName`: value of `kTISPropertyLocalizedName`
///   (e.g. `"2벌식"`, `"Hiragana"`, `"ABC"`).
/// - `typeIsIME`: result of `isInputMethod(kTISPropertyInputSourceType)`.
///
/// Flag mapping uses prefix matching. `zh-Hant*` must be checked before `zh*`
/// so that Traditional Chinese is not swallowed by the Simplified default.
public func inputSourceDisplay(
    languageTag: String?,
    localizedName: String?,
    typeIsIME: Bool
) -> InputSourceDisplay {
    let flag = flagEmoji(for: languageTag)
    let name: String
    if let localizedName, !localizedName.isEmpty {
        name = localizedName
    } else {
        name = "Unknown"
    }
    return InputSourceDisplay(flag: flag, name: name, isIME: typeIsIME)
}

private func flagEmoji(for languageTag: String?) -> String {
    guard let tag = languageTag?.lowercased() else { return "🌐" }
    if tag.hasPrefix("ko") { return "🇰🇷" }
    if tag.hasPrefix("ja") { return "🇯🇵" }
    if tag.hasPrefix("zh-hant") { return "🇹🇼" }
    if tag.hasPrefix("zh") { return "🇨🇳" }
    if tag.hasPrefix("en") { return "🇺🇸" }
    return "🌐"
}
