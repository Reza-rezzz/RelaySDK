import Foundation

/// Shared JSON coders configured for the Relay API.
public enum RelayJSON {
    /// Encoder producing snake_case keys and ISO-8601 dates.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(RelayISO8601.string(from: date))
        }
        return encoder
    }

    /// Decoder that accepts ISO-8601 dates with or without fractional seconds.
    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = RelayISO8601.date(from: raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO-8601 date"
                )
            }
            return date
        }
        return decoder
    }
}

/// Thread-safe ISO-8601 parsing and formatting helpers.
public enum RelayISO8601 {
    private static func formatter(_ options: ISO8601DateFormatter.Options) -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = options
        return f
    }

    /// Parses `2024-01-01T10:00:00Z`, `2024-01-01T10:00:00.123Z`, offsets like `+03:30`, and plain dates.
    public static func date(from string: String) -> Date? {
        // Formatters are created per call: ISO8601DateFormatter is mutable and not Sendable.
        let fractional = formatter([.withInternetDateTime, .withFractionalSeconds])
        let plain = formatter([.withInternetDateTime])
        let dateOnly = formatter([.withFullDate])
        let trimmed = truncateFraction(string.trimmingCharacters(in: .whitespacesAndNewlines))
        if let d = fractional.date(from: trimmed) { return d }
        if let d = plain.date(from: trimmed) { return d }
        // Some backends emit a space instead of "T" or omit the zone.
        let normalized = trimmed.replacingOccurrences(of: " ", with: "T")
        if let d = fractional.date(from: normalized) ?? plain.date(from: normalized) { return d }
        if !normalized.hasSuffix("Z"), !normalized.contains("+"), normalized.count > 10 {
            let withZ = normalized + "Z"
            if let d = fractional.date(from: withZ) ?? plain.date(from: withZ) { return d }
        }
        return dateOnly.date(from: trimmed)
    }

    /// Formats a date with fractional seconds in UTC.
    public static func string(from date: Date) -> String {
        formatter([.withInternetDateTime, .withFractionalSeconds]).string(from: date)
    }

    /// Limits a fractional-seconds component to 3 digits (`.123456Z` → `.123Z`).
    static func truncateFraction(_ value: String) -> String {
        guard let dot = value.firstIndex(of: ".") else { return value }
        var end = value.index(after: dot)
        while end < value.endIndex, value[end].isNumber { end = value.index(after: end) }
        let digits = value[value.index(after: dot)..<end]
        guard digits.count > 3 else { return value }
        return String(value[..<dot]) + "." + digits.prefix(3) + String(value[end...])
    }
}
