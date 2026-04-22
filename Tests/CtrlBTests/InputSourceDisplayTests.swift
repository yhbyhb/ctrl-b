import XCTest
@testable import CtrlBCore

final class InputSourceDisplayTests: XCTestCase {

    // MARK: - Flag mapping

    func test_korean_mapsTo_kr() {
        let display = inputSourceDisplay(languageTag: "ko", localizedName: "2벌식", typeIsIME: true)
        XCTAssertEqual(display.flag, "🇰🇷")
        XCTAssertEqual(display.name, "2벌식")
        XCTAssertTrue(display.isIME)
    }

    func test_japanese_mapsTo_jp() {
        let display = inputSourceDisplay(languageTag: "ja", localizedName: "Hiragana", typeIsIME: true)
        XCTAssertEqual(display.flag, "🇯🇵")
    }

    func test_simplifiedChinese_mapsTo_cn() {
        let display = inputSourceDisplay(languageTag: "zh-Hans", localizedName: "拼音", typeIsIME: true)
        XCTAssertEqual(display.flag, "🇨🇳")
    }

    func test_simplifiedChinese_regionalVariant_mapsTo_cn() {
        let display = inputSourceDisplay(languageTag: "zh-Hans-CN", localizedName: "Pinyin", typeIsIME: true)
        XCTAssertEqual(display.flag, "🇨🇳")
    }

    func test_traditionalChinese_mapsTo_tw() {
        let display = inputSourceDisplay(languageTag: "zh-Hant", localizedName: "注音", typeIsIME: true)
        XCTAssertEqual(display.flag, "🇹🇼")
    }

    func test_traditionalChinese_takesPrecedence_overGenericZh() {
        // zh-Hant-TW must hit the Traditional branch, not fall through to generic zh → 🇨🇳.
        let display = inputSourceDisplay(languageTag: "zh-Hant-TW", localizedName: "Zhuyin", typeIsIME: true)
        XCTAssertEqual(display.flag, "🇹🇼")
    }

    func test_english_nonIME_mapsTo_us() {
        let display = inputSourceDisplay(languageTag: "en", localizedName: "ABC", typeIsIME: false)
        XCTAssertEqual(display.flag, "🇺🇸")
        XCTAssertFalse(display.isIME)
    }

    func test_unknownLanguage_fallsBackTo_globe() {
        let display = inputSourceDisplay(languageTag: "fr", localizedName: "French", typeIsIME: false)
        XCTAssertEqual(display.flag, "🌐")
        XCTAssertEqual(display.name, "French", "localizedName should be preserved even when flag falls back")
    }

    // MARK: - Name fallback

    func test_nilInputs_fallBackTo_globe_Unknown() {
        let display = inputSourceDisplay(languageTag: nil, localizedName: nil, typeIsIME: false)
        XCTAssertEqual(display.flag, "🌐")
        XCTAssertEqual(display.name, "Unknown")
        XCTAssertFalse(display.isIME)
    }

    func test_emptyLocalizedName_fallsBackTo_Unknown() {
        let display = inputSourceDisplay(languageTag: "ko", localizedName: "", typeIsIME: true)
        XCTAssertEqual(display.name, "Unknown")
    }

    // MARK: - Case insensitivity

    func test_upperCaseLanguageTag_stillMatches() {
        let display = inputSourceDisplay(languageTag: "KO", localizedName: "Korean", typeIsIME: true)
        XCTAssertEqual(display.flag, "🇰🇷")
    }
}
