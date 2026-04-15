import XCTest
@testable import CtrlBHelperCore

final class CJKInputSourceDetectorTests: XCTestCase {

    // MARK: - containsCJKLanguage

    func test_korean_detected() {
        XCTAssertTrue(containsCJKLanguage(["ko"]))
    }

    func test_chinese_simplified_detected() {
        XCTAssertTrue(containsCJKLanguage(["zh-Hans"]))
    }

    func test_chinese_traditional_detected() {
        XCTAssertTrue(containsCJKLanguage(["zh-Hant"]))
    }

    func test_chinese_bare_detected() {
        XCTAssertTrue(containsCJKLanguage(["zh"]))
    }

    func test_japanese_detected() {
        XCTAssertTrue(containsCJKLanguage(["ja"]))
    }

    func test_english_not_detected() {
        XCTAssertFalse(containsCJKLanguage(["en"]))
    }

    func test_empty_not_detected() {
        XCTAssertFalse(containsCJKLanguage([]))
    }

    func test_mixed_languages_with_korean() {
        XCTAssertTrue(containsCJKLanguage(["en", "ko"]))
    }

    func test_mixed_languages_without_cjk() {
        XCTAssertFalse(containsCJKLanguage(["en", "fr", "de"]))
    }

    // MARK: - isCJKInputSourceID

    func test_apple_korean_2set() {
        XCTAssertTrue(isCJKInputSourceID("com.apple.inputmethod.Korean.2SetKorean"))
    }

    func test_apple_korean_3set() {
        XCTAssertTrue(isCJKInputSourceID("com.apple.inputmethod.Korean.3SetKorean"))
    }

    func test_apple_chinese_pinyin() {
        XCTAssertTrue(isCJKInputSourceID("com.apple.inputmethod.Pinyin"))
    }

    func test_apple_japanese() {
        XCTAssertTrue(isCJKInputSourceID("com.apple.inputmethod.Japanese"))
    }

    func test_apple_japanese_kotoeri() {
        XCTAssertTrue(isCJKInputSourceID("com.apple.inputmethod.Kotoeri"))
    }

    func test_apple_chinese_wubi() {
        XCTAssertTrue(isCJKInputSourceID("com.apple.inputmethod.Wubi"))
    }

    func test_apple_chinese_cangjie() {
        XCTAssertTrue(isCJKInputSourceID("com.apple.inputmethod.Cangjie"))
    }

    func test_apple_chinese_zhuyin() {
        XCTAssertTrue(isCJKInputSourceID("com.apple.inputmethod.Zhuyin"))
    }

    func test_abc_not_detected() {
        XCTAssertFalse(isCJKInputSourceID("com.apple.keylayout.ABC"))
    }

    func test_us_not_detected() {
        XCTAssertFalse(isCJKInputSourceID("com.apple.keylayout.US"))
    }

    func test_emptyID_not_detected() {
        XCTAssertFalse(isCJKInputSourceID(""))
    }

    func test_case_insensitive_korean() {
        XCTAssertTrue(isCJKInputSourceID("com.example.KOREAN.input"))
    }

    func test_case_insensitive_chinese() {
        XCTAssertTrue(isCJKInputSourceID("com.example.CHINESE.input"))
    }

    // MARK: - SCIM (Apple 중국어 간체) - ID에 Chinese가 없는 경우

    func test_apple_scim_no_keyword_match() {
        // com.apple.inputmethod.SCIM.ITABC 에는 "chinese"가 없지만
        // 실제로는 language 배열에 "zh"가 있어서 containsCJKLanguage로 감지됨
        // ID만으로는 감지 안 될 수 있음 → 2단계 감지의 이유
        XCTAssertFalse(isCJKInputSourceID("com.apple.inputmethod.SCIM.ITABC"))
    }
}
