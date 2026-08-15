import Foundation

/// A parsed user intent from a spoken phrase.
enum VoiceCommand: Equatable {
    case navigate(roomPhrase: String)      // "take me to the kitchen"
    case setLocation(roomPhrase: String)   // "I am in the bedroom"
    case whereAmI                          // "where am I"
    case listRooms                         // "what rooms are available"
    case next                              // "next" / "I'm here"
    case repeatInstruction                 // "repeat"
    case cancel                            // "cancel" / "stop navigation"
    case unknown(String)                   // fallback, carries the raw text
}
