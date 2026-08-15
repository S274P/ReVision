import Foundation
import CoreGraphics

/// The whole home represented as a graph: rooms (nodes) + connections (edges),
/// plus furniture placed on the visual map. Also remembers the user's last-known
/// current location.
nonisolated struct HouseLayout: Codable {
    var rooms: [Room]
    var connections: [Connection]
    var furniture: [FurnitureItem]
    var currentRoomID: UUID?

    init(rooms: [Room] = [],
         connections: [Connection] = [],
         furniture: [FurnitureItem] = [],
         currentRoomID: UUID? = nil) {
        self.rooms = rooms
        self.connections = connections
        self.furniture = furniture
        self.currentRoomID = currentRoomID
    }

    // MARK: - Lookups

    func room(withID id: UUID?) -> Room? {
        guard let id else { return nil }
        return rooms.first { $0.id == id }
    }

    /// Loose voice/text match: exact match key first, then a contains match.
    func room(matching spoken: String) -> Room? {
        let key = spoken.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        guard !key.isEmpty else { return nil }
        if let exact = rooms.first(where: { $0.matchKey == key }) { return exact }
        return rooms.first { $0.matchKey.contains(key) || key.contains($0.matchKey) }
    }

    /// Connection from one room to another, if one exists.
    func connection(from: UUID, to: UUID) -> Connection? {
        connections.first { $0.fromRoomID == from && $0.toRoomID == to }
    }

    /// Neighboring room IDs reachable directly from `roomID`.
    func neighbors(of roomID: UUID) -> [UUID] {
        connections.filter { $0.fromRoomID == roomID }.map(\.toRoomID)
    }

    // MARK: - Room mutation helpers

    mutating func addRoom(named name: String) -> Room {
        let room = Room(name: name)
        rooms.append(room)
        return room
    }

    /// Adds a room at a specific spot on the map (used by the visual editor).
    mutating func addRoom(named name: String, frame: MapFrame) -> Room {
        let room = Room(name: name, frame: frame)
        rooms.append(room)
        return room
    }

    mutating func removeRoom(_ id: UUID) {
        rooms.removeAll { $0.id == id }
        connections.removeAll { $0.fromRoomID == id || $0.toRoomID == id }
        if currentRoomID == id { currentRoomID = nil }
    }

    mutating func renameRoom(_ id: UUID, to name: String) {
        guard let idx = rooms.firstIndex(where: { $0.id == id }) else { return }
        rooms[idx].name = name
    }

    // MARK: - Connection / doorway helpers

    /// Adds a connection (and optionally its reverse) if not already present.
    mutating func addConnection(from: UUID,
                                to: UUID,
                                instruction: String,
                                bidirectional: Bool,
                                reverseInstruction: String = "") {
        if connection(from: from, to: to) == nil {
            connections.append(Connection(fromRoomID: from, toRoomID: to, instruction: instruction))
        }
        if bidirectional, connection(from: to, to: from) == nil {
            connections.append(Connection(fromRoomID: to, toRoomID: from, instruction: reverseInstruction))
        }
    }

    mutating func removeConnection(_ id: UUID) {
        connections.removeAll { $0.id == id }
    }

    /// Removes a doorway between two rooms (both directions).
    mutating func removeDoorway(_ a: UUID, _ b: UUID) {
        connections.removeAll {
            ($0.fromRoomID == a && $0.toRoomID == b) || ($0.fromRoomID == b && $0.toRoomID == a)
        }
    }

    mutating func updateInstruction(connectionID: UUID, to instruction: String) {
        guard let idx = connections.firstIndex(where: { $0.id == connectionID }) else { return }
        connections[idx].instruction = instruction
    }

    /// Sets (or clears) the spoken instruction for the connection from `a` to `b`.
    mutating func setInstruction(from a: UUID, to b: UUID, instruction: String) {
        if let idx = connections.firstIndex(where: { $0.fromRoomID == a && $0.toRoomID == b }) {
            connections[idx].instruction = instruction
        }
    }

    // MARK: - Furniture helpers

    mutating func addFurniture(_ kind: FurnitureKind, at point: CGPoint) {
        let size = kind.defaultSize
        let frame = MapFrame(x: Double(point.x) - Double(size.width) / 2,
                             y: Double(point.y) - Double(size.height) / 2,
                             width: Double(size.width),
                             height: Double(size.height))
        furniture.append(FurnitureItem(kind: kind, frame: frame))
    }

    mutating func removeFurniture(_ id: UUID) {
        furniture.removeAll { $0.id == id }
    }
}

// MARK: - Sample data

extension HouseLayout {
    /// A ready-to-use example home, arranged as a simple floor plan so the visual
    /// map has something to show before a caretaker configures it.
    static func sample() -> HouseLayout {
        var bedroom  = Room(name: "Bedroom")
        var hallway  = Room(name: "Hallway")
        var bathroom = Room(name: "Bathroom")
        var kitchen  = Room(name: "Kitchen")
        var living   = Room(name: "Living Room")

        bedroom.frame  = MapFrame(x: 24,  y: 24,  width: 150, height: 130)
        bathroom.frame = MapFrame(x: 190, y: 24,  width: 120, height: 90)
        hallway.frame  = MapFrame(x: 24,  y: 170, width: 150, height: 110)
        kitchen.frame  = MapFrame(x: 190, y: 130, width: 120, height: 150)
        living.frame   = MapFrame(x: 24,  y: 300, width: 286, height: 170)

        var layout = HouseLayout(
            rooms: [bedroom, hallway, bathroom, kitchen, living],
            currentRoomID: bedroom.id
        )

        layout.addConnection(from: bedroom.id, to: hallway.id,
                             instruction: "Move forward slowly until you reach the hallway.",
                             bidirectional: true,
                             reverseInstruction: "Move forward slowly back toward the bedroom.")
        layout.addConnection(from: hallway.id, to: bathroom.id,
                             instruction: "Turn right and continue a few steps to the bathroom.",
                             bidirectional: true,
                             reverseInstruction: "Leave the bathroom and turn left into the hallway.")
        layout.addConnection(from: hallway.id, to: kitchen.id,
                             instruction: "Turn left and continue forward toward the kitchen.",
                             bidirectional: true,
                             reverseInstruction: "Leave the kitchen and continue into the hallway.")
        layout.addConnection(from: kitchen.id, to: living.id,
                             instruction: "Move forward carefully. The living room is ahead.",
                             bidirectional: true,
                             reverseInstruction: "Move forward carefully back toward the kitchen.")

        layout.furniture = [
            FurnitureItem(kind: .bed,  frame: MapFrame(x: 40,  y: 60,  width: 90, height: 60)),
            FurnitureItem(kind: .sofa, frame: MapFrame(x: 60,  y: 380, width: 96, height: 42)),
            FurnitureItem(kind: .toilet, frame: MapFrame(x: 210, y: 44, width: 36, height: 44))
        ]

        return layout
    }
}
