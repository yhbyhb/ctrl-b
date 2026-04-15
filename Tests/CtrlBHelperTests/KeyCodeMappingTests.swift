import XCTest
@testable import CtrlBHelperCore

final class KeyCodeMappingTests: XCTestCase {

    // MARK: - 핵심 키 (tmux prefix)

    func test_keyCode11_mapsTo_b() {
        XCTAssertEqual(keyCodeToLowerASCII[11], 98)  // 'b'
    }

    func test_ctrlB_controlChar() {
        guard let ascii = keyCodeToLowerASCII[11] else {
            XCTFail("keyCode 11 not found"); return
        }
        XCTAssertEqual(ascii & 0x1F, 0x02)  // Ctrl+B = STX
    }

    // MARK: - 모든 매핑 값은 소문자 ASCII (a–z)

    func test_allValues_areLowercaseASCII() {
        for (keyCode, ascii) in keyCodeToLowerASCII {
            XCTAssertTrue(
                ascii >= 97 && ascii <= 122,
                "keyCode \(keyCode) → \(ascii) 는 a-z 범위 밖"
            )
        }
    }

    // MARK: - 알파벳 26자 전체 커버 여부

    func test_allAlphabetLetters_covered() {
        let coveredASCII = Set(keyCodeToLowerASCII.values)
        let alphabet = Set<UInt8>(97...122)  // a–z
        let missing = alphabet.subtracting(coveredASCII).map { Character(UnicodeScalar($0)) }
        XCTAssertTrue(missing.isEmpty, "매핑 누락된 알파벳: \(missing)")
    }

    // MARK: - 주요 개별 키 검증

    func test_keyCode0_a() { XCTAssertEqual(keyCodeToLowerASCII[0], 97)  }
    func test_keyCode6_z() { XCTAssertEqual(keyCodeToLowerASCII[6], 122)  }
    func test_keyCode12_q() { XCTAssertEqual(keyCodeToLowerASCII[12], 113)  }
    func test_keyCode14_e() { XCTAssertEqual(keyCodeToLowerASCII[14], 101)  }
    func test_keyCode17_t() { XCTAssertEqual(keyCodeToLowerASCII[17], 116)  }

    // MARK: - 키맵에 없는 keyCode는 nil

    func test_unknownKeyCode_returnsNil() {
        XCTAssertNil(keyCodeToLowerASCII[99])
        XCTAssertNil(keyCodeToLowerASCII[-1])
    }

    // MARK: - Ctrl 문자 계산 검증 (ascii & 0x1F)

    func test_ctrlChar_a() {
        guard let ascii = keyCodeToLowerASCII[0] else { XCTFail("keyCode 0 not found"); return }
        XCTAssertEqual(ascii & 0x1F, 0x01)  // Ctrl+A = SOH
    }

    func test_ctrlChar_c() {
        guard let ascii = keyCodeToLowerASCII[8] else { XCTFail("keyCode 8 not found"); return }
        XCTAssertEqual(ascii & 0x1F, 0x03)  // Ctrl+C = ETX
    }
}
