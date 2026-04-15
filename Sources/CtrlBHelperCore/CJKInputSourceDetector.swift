import Foundation

/// CJK 언어 프리픽스 목록
private let cjkLanguagePrefixes = ["ko", "zh", "ja"]

/// CJK 입력 소스 ID 키워드 (대소문자 무시)
private let cjkIDKeywords = ["korean", "chinese", "japanese", "pinyin", "wubi", "cangjie", "zhuyin", "kotoeri"]

/// language 배열에 CJK 언어가 포함되어 있는지 판별
public func containsCJKLanguage(_ languages: [String]) -> Bool {
    languages.contains { lang in
        cjkLanguagePrefixes.contains { lang.hasPrefix($0) }
    }
}

/// input source ID가 CJK 입력 소스인지 판별
public func isCJKInputSourceID(_ id: String) -> Bool {
    let lowered = id.lowercased()
    return cjkIDKeywords.contains { lowered.contains($0) }
}
