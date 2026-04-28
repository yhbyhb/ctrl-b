import Cocoa
import CtrlBCore

/// Builds and shows the standard Apple About panel with custom Credits that
/// reflect ctrl-b's identity: a static keycap demo, a live indicator of the
/// currently detected input source, lifetime stats, and project links.
///
/// Credits content is English-only by convention (matching Maccy/Rectangle).
/// Only the menu item title that triggers this panel is localized.
final class AboutPanelController: NSObject {
    private let stats: StatisticsManager
    private let currentInputSource: () -> InputSourceDisplay

    init(stats: StatisticsManager,
         currentInputSource: @escaping () -> InputSourceDisplay) {
        self.stats = stats
        self.currentInputSource = currentInputSource
        super.init()
    }

    @objc func show(_ sender: Any?) {
        // LSUIElement=true app has no Dock icon, so the panel would open
        // behind the frontmost app unless we explicitly activate.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: buildCredits()])
    }

    // MARK: - Credits composition

    func buildCredits() -> NSAttributedString {
        let result = NSMutableAttributedString()
        result.append(keycapLine())
        result.append(blankLine())
        result.append(currentInputSourceLine())
        if let secure = secureInputLine() {
            result.append(blankLine())
            result.append(secure)
        }
        result.append(blankLine())
        result.append(statsLine())
        result.append(blankLine())
        result.append(linksLine())

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        result.addAttribute(.paragraphStyle,
                            value: paragraph,
                            range: NSRange(location: 0, length: result.length))
        return result
    }

    private func keycapLine() -> NSAttributedString {
        let text = "⌃b  under  한 / 中 / あ   →   ⌃b"
        return NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    private func currentInputSourceLine() -> NSAttributedString {
        let source = currentInputSource()
        let suffix = source.isIME ? "" : " — idle"
        let text = "Currently: \(source.flag) \(source.name)\(suffix)"
        return NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    private func secureInputLine() -> NSAttributedString? {
        guard isSecureKeyboardEntryActive() else { return nil }
        return NSAttributedString(
            string: "🔒 Secure Keyboard Entry is active — ctrl-b cannot intercept",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.systemOrange
            ]
        )
    }

    private func statsLine() -> NSAttributedString {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        let countString = formatter.string(from: NSNumber(value: stats.remapCount)) ?? "\(stats.remapCount)"
        let savedString = formatSavedTime(stats.timeSavedSeconds)
        let text = "Remapped \(countString) times · Saved \(savedString)"
        return NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    private func linksLine() -> NSAttributedString {
        joinedLinksLine([
            link("GitHub", href: "https://github.com/yhbyhb/ctrl-b"),
            link("Issues", href: "https://github.com/yhbyhb/ctrl-b/issues"),
            link("Sponsor", href: "https://github.com/sponsors/yhbyhb"),
            link("Ko-fi", href: "https://ko-fi.com/yhbyhb")
        ])
    }

    private func joinedLinksLine(_ parts: [NSAttributedString]) -> NSAttributedString {
        let separator = NSAttributedString(
            string: "  ·  ",
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            ]
        )
        let result = NSMutableAttributedString()
        for (index, part) in parts.enumerated() {
            if index > 0 { result.append(separator) }
            result.append(part)
        }
        return result
    }

    private func link(_ text: String, href: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: attributed.length)
        attributed.addAttribute(.link, value: href, range: range)
        attributed.addAttribute(.underlineStyle,
                                value: NSNumber(value: NSUnderlineStyle.single.rawValue),
                                range: range)
        attributed.addAttribute(.underlineColor, value: NSColor.linkColor, range: range)
        attributed.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
        attributed.addAttribute(.font,
                                value: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                                range: range)
        return attributed
    }

    private func blankLine() -> NSAttributedString {
        NSAttributedString(string: "\n\n")
    }

    private func formatSavedTime(_ seconds: Double) -> String {
        switch TimeMagnitude(seconds) {
        case .seconds(let sec): return "~\(Int(sec.rounded())) seconds"
        case .minutes(let min): return "~\(Int(min.rounded())) minutes"
        case .hours(let hrs): return "~\(Int(hrs.rounded())) hours"
        }
    }
}
