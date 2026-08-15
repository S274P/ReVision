import Foundation

/// Recognizes family-related voice commands so they can be handled before the
/// normal navigation parser. Returns nil for anything that isn't a family command.
enum FamilyVoice {
    enum Intent {
        case message(name: String, body: String)   // "tell Mom I'm okay"
        case help                                    // "I need help"
    }

    static func parse(_ raw: String) -> Intent? {
        let text = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Help / SOS
        let helpTriggers = ["i need help", "call for help", "help me", "notify family",
                            "tell my family", "message my family", "need assistance", "emergency"]
        for t in helpTriggers where text.contains(t) { return .help }

        // "tell / message / text <name> <body>"
        for prefix in ["tell ", "message ", "text ", "send a message to ", "send "] {
            if text.hasPrefix(prefix) {
                let remainder = String(text.dropFirst(prefix.count))
                if let intent = splitNameAndBody(remainder) { return intent }
            }
        }
        return nil
    }

    /// Splits "mom i'm okay" → name "mom", body "I'm okay".
    private static func splitNameAndBody(_ s: String) -> Intent? {
        var words = s.split(separator: " ").map(String.init)
        guard words.count >= 2 else { return nil }
        let name = words.removeFirst()
        if words.first == "that" { words.removeFirst() }   // "tell mom that I'm okay"
        guard !words.isEmpty else { return nil }
        return .message(name: name, body: capitalizeFirst(words.joined(separator: " ")))
    }

    private static func capitalizeFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return String(first).uppercased() + s.dropFirst()
    }
}
