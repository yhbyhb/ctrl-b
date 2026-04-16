import Foundation

/// Determines if the given UniChar falls within Hangul Unicode ranges
public func isHangul(_ char: UniChar) -> Bool {
    (0x1100...0x11FF).contains(char) ||  // Hangul Jamo
    (0x3130...0x318F).contains(char) ||  // Hangul Compatibility Jamo (ㅠ = U+3160)
    (0xAC00...0xD7A3).contains(char)     // Hangul Syllables
}

/// macOS physical keyCode → lowercase ASCII mapping (a–z)
public let keyCodeToLowerASCII: [Int64: UInt8] = [
     0: 97,   // a
     1: 115,  // s
     2: 100,  // d
     3: 102,  // f
     4: 104,  // h
     5: 103,  // g
     6: 122,  // z
     7: 120,  // x
     8: 99,  // c
     9: 118,  // v
    11: 98,  // b  ← Ctrl+b (tmux prefix)
    12: 113,  // q
    13: 119,  // w
    14: 101,  // e
    15: 114,  // r
    16: 121,  // y
    17: 116,  // t
    31: 111,  // o
    32: 117,  // u
    34: 105,  // i
    35: 112,  // p
    37: 108,  // l
    38: 106,  // j
    40: 107,  // k
    45: 110,  // n
    46: 109  // m
]
