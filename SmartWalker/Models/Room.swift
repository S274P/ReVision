import Foundation

/// A node in the house graph — a room or an important location
/// (e.g. "Bedroom", "Hallway Turn", "Front Door").
///
/// `frame` places the room on the visual home map. It always has a value
/// (defaulted), so older code that creates a room by name still works.
nonisolated struct Room: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var frame: MapFrame

    init(id: UUID = UUID(),
         name: String,
         frame: MapFrame = MapFrame(x: 40, y: 40, width: 150, height: 120)) {
        self.id = id
        self.name = name
        self.frame = frame
    }

    /// Normalized form used for loose voice matching.
    var matchKey: String {
        name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }
}
