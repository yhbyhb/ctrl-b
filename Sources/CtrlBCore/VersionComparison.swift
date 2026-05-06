public func isNewerVersion(_ candidate: String, than current: String) -> Bool {
    let parts: (String) -> [Int] = { $0.split(separator: ".").compactMap { Int($0) } }
    let a = parts(candidate)
    let b = parts(current)
    for i in 0..<max(a.count, b.count) {
        let av = i < a.count ? a[i] : 0
        let bv = i < b.count ? b[i] : 0
        if av != bv { return av > bv }
    }
    return false
}
