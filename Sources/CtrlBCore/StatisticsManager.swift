import Foundation

/// Tracks remap count and estimated time saved (persisted in UserDefaults)
public final class StatisticsManager {
    private let defaults: UserDefaults
    private let countKey = "remapCount"
    private let todayCountKey = "todayRemapCount"
    private let todayDateKey = "todayDate"

    /// Estimated time saved per remap (seconds)
    /// Noticing failure (~0.5s) + switching IME (~0.5s) + retrying key (~0.5s) + switching back (~0.5s)
    public static let secondsPerRemap: Double = 2.0

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    private let now: () -> Date

    public init(defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        self.now = now
    }

    // MARK: - Cumulative

    public var remapCount: Int {
        defaults.integer(forKey: countKey)
    }

    public var timeSavedSeconds: Double {
        Double(remapCount) * Self.secondsPerRemap
    }

    // MARK: - Today

    public var todayRemapCount: Int {
        resetTodayIfNeeded()
        return defaults.integer(forKey: todayCountKey)
    }

    public var todayTimeSavedSeconds: Double {
        Double(todayRemapCount) * Self.secondsPerRemap
    }

    // MARK: - Record

    public func recordRemap() {
        defaults.set(remapCount + 1, forKey: countKey)

        resetTodayIfNeeded()
        defaults.set(defaults.integer(forKey: todayCountKey) + 1, forKey: todayCountKey)
    }

    public func reset() {
        defaults.set(0, forKey: countKey)
        defaults.set(0, forKey: todayCountKey)
        defaults.set(todayString, forKey: todayDateKey)
    }

    // MARK: - Private

    private var todayString: String {
        Self.dateFormatter.string(from: now())
    }

    private func resetTodayIfNeeded() {
        let saved = defaults.string(forKey: todayDateKey) ?? ""
        if saved != todayString {
            defaults.set(0, forKey: todayCountKey)
            defaults.set(todayString, forKey: todayDateKey)
        }
    }
}
