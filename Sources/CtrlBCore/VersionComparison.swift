public func isNewerVersion(_ candidate: String, than current: String) -> Bool {
    let parts: (String) -> [Int] = { $0.split(separator: ".").compactMap { Int($0) } }
    let lhs = parts(candidate)
    let rhs = parts(current)
    for idx in 0..<max(lhs.count, rhs.count) {
        let lhsVal = idx < lhs.count ? lhs[idx] : 0
        let rhsVal = idx < rhs.count ? rhs[idx] : 0
        if lhsVal != rhsVal { return lhsVal > rhsVal }
    }
    return false
}
