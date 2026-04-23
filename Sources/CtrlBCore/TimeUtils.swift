import Foundation

/// Classifies a duration (in seconds) into the most readable unit.
public enum TimeMagnitude: Equatable {
    case seconds(Double)
    case minutes(Double)
    case hours(Double)

    public init(_ seconds: Double) {
        if seconds < 60 { self = .seconds(seconds) }
        else if seconds < 3600 { self = .minutes(seconds / 60) }
        else { self = .hours(seconds / 3600) }
    }
}
