import Foundation

/// Turns free-form recognized speech into a `VoiceCommand`.
/// Intentionally simple and forgiving — order of checks matters (most specific first).
enum VoiceCommandParser {

    static func parse(_ raw: String) -> VoiceCommand {
        let text = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .unknown(raw) }

        // --- Cancel / stop ---
        if text.contains("cancel") || text.contains("stop navigation") || text == "stop" {
            return .cancel
        }

        // --- Progress ---
        if text == "next" || text.contains("i'm here") || text.contains("im here")
            || text.contains("i am here") || text.contains("done") {
            return .next
        }
        if text.contains("repeat") || text.contains("say that again") || text.contains("again") {
            return .repeatInstruction
        }

        // --- Questions ---
        if text.contains("where am i") || text.contains("where i am")
            || text.contains("current location") && !text.contains("set") && !text.contains("my current location is") {
            // "what is my current location" is a question; "my current location is X" is set.
            if !text.contains("my current location is") {
                return .whereAmI
            }
        }
        if text.contains("what rooms") || text.contains("which rooms")
            || text.contains("list rooms") || text.contains("available rooms") {
            return .listRooms
        }

        // --- Set current location ---
        // Handles: "I am in the X", "I'm in X", "set my location to X",
        //          "my current location is X", "my location is X"
        for prefix in ["set my location to", "set location to",
                       "my current location is", "my location is",
                       "i am in the", "i am in", "i'm in the", "i'm in", "im in"] {
            if let room = extractRoom(after: prefix, in: text) {
                return .setLocation(roomPhrase: room)
            }
        }

        // --- Navigate ---
        for prefix in ["take me to the", "take me to",
                       "navigate to the", "navigate to",
                       "guide me to the", "guide me to",
                       "go to the", "go to",
                       "bring me to the", "bring me to"] {
            if let room = extractRoom(after: prefix, in: text) {
                return .navigate(roomPhrase: room)
            }
        }

        return .unknown(raw)
    }

    /// Returns the trimmed remainder after `prefix` if `text` starts with it
    /// (allowing a leading filler). Strips trailing punctuation.
    private static func extractRoom(after prefix: String, in text: String) -> String? {
        guard let range = text.range(of: prefix) else { return nil }
        // Only accept the prefix near the start (avoid matching mid-sentence noise).
        guard text.distance(from: text.startIndex, to: range.lowerBound) <= 6 else { return nil }
        let remainder = text[range.upperBound...]
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,!?"))
        return remainder.isEmpty ? nil : remainder
    }
}
