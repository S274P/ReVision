import Foundation

/// A directed edge in the house graph: a walkable path from one room to another,
/// with the spoken instruction the caretaker wrote for travelling it.
///
/// Connections are stored one-directional so the instruction can differ by direction
/// ("Turn left toward the kitchen" vs. "Turn right back to the bedroom").
/// The caretaker UI offers to add the reverse edge automatically.
nonisolated struct Connection: Identifiable, Codable, Hashable {
    let id: UUID
    var fromRoomID: UUID
    var toRoomID: UUID
    /// Spoken guidance used during navigation, e.g.
    /// "Move forward slowly until you reach the hallway."
    var instruction: String

    init(id: UUID = UUID(),
         fromRoomID: UUID,
         toRoomID: UUID,
         instruction: String = "") {
        self.id = id
        self.fromRoomID = fromRoomID
        self.toRoomID = toRoomID
        self.instruction = instruction
    }
}
