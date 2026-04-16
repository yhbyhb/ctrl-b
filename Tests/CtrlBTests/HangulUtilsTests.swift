import XCTest
@testable import CtrlBCore

final class HangulUtilsTests: XCTestCase {

    // MARK: - Hangul Jamo (0x1100–0x11FF)

    func test_hangulJamo_start() {
        XCTAssertTrue(isHangul(0x1100))  // ᄀ
    }

    func test_hangulJamo_end() {
        XCTAssertTrue(isHangul(0x11FF))  // ᇿ
    }

    func test_hangulJamo_boundary_before() {
        XCTAssertFalse(isHangul(0x10FF))
    }

    func test_hangulJamo_boundary_after() {
        XCTAssertFalse(isHangul(0x1200))
    }

    // MARK: - Hangul Compatibility Jamo (0x3130–0x318F)

    func test_hangulCompatJamo_yu() {
        XCTAssertTrue(isHangul(0x3160))  // ㅠ — primary target
    }

    func test_hangulCompatJamo_start() {
        XCTAssertTrue(isHangul(0x3130))
    }

    func test_hangulCompatJamo_end() {
        XCTAssertTrue(isHangul(0x318F))
    }

    func test_hangulCompatJamo_boundary_before() {
        XCTAssertFalse(isHangul(0x312F))
    }

    func test_hangulCompatJamo_boundary_after() {
        XCTAssertFalse(isHangul(0x3190))
    }

    // MARK: - Hangul Syllables (0xAC00–0xD7A3)

    func test_hangulSyllables_ga() {
        XCTAssertTrue(isHangul(0xAC00))  // 가
    }

    func test_hangulSyllables_hih() {
        XCTAssertTrue(isHangul(0xD7A3))  // 힣
    }

    func test_hangulSyllables_boundary_before() {
        XCTAssertFalse(isHangul(0xABFF))
    }

    func test_hangulSyllables_boundary_after() {
        XCTAssertFalse(isHangul(0xD7A4))
    }

    // MARK: - Non-Hangul characters

    func test_ascii_a() {
        XCTAssertFalse(isHangul(UniChar(("a" as Unicode.Scalar).value)))
    }

    func test_ascii_z() {
        XCTAssertFalse(isHangul(UniChar(("z" as Unicode.Scalar).value)))
    }

    func test_ascii_uppercase() {
        XCTAssertFalse(isHangul(0x0041))  // A
    }

    func test_digit() {
        XCTAssertFalse(isHangul(0x0031))  // 1
    }

    func test_japanese_hiragana() {
        XCTAssertFalse(isHangul(0x3042))  // あ
    }
}
