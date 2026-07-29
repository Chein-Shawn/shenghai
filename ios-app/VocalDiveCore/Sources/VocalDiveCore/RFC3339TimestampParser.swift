import Foundation

/// Accepts the current no-fraction RFC 3339 wire format and older server values
/// that included fractional seconds, so mobile and server deployments can overlap.
public enum RFC3339TimestampParser {
    public static func date(from value: String) -> Date? {
        let standard = ISO8601DateFormatter()
        if let date = standard.date(from: value) {
            return date
        }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value)
    }
}
