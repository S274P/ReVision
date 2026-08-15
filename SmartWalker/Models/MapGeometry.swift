import Foundation
import CoreGraphics

/// A rectangle on the home map, stored in canvas points (top-left origin).
/// Used by both rooms and furniture so everything shares one coordinate space.
nonisolated struct MapFrame: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// Center point, handy for drawing doorway connectors between rooms.
    var center: CGPoint { CGPoint(x: x + width / 2, y: y + height / 2) }
}

/// The kinds of furniture a caretaker can drop onto the map. Each carries a
/// display name, an SF Symbol, and a sensible default size in canvas points.
nonisolated enum FurnitureKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case sofa, bed, table, chair, counter, toilet, sink, tv, rug, plant, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sofa:    return "Sofa"
        case .bed:     return "Bed"
        case .table:   return "Table"
        case .chair:   return "Chair"
        case .counter: return "Counter"
        case .toilet:  return "Toilet"
        case .sink:    return "Sink"
        case .tv:      return "TV"
        case .rug:     return "Rug"
        case .plant:   return "Plant"
        case .other:   return "Furniture"
        }
    }

    var systemImage: String {
        switch self {
        case .sofa:    return "sofa"
        case .bed:     return "bed.double"
        case .table:   return "table.furniture"
        case .chair:   return "chair"
        case .counter: return "cabinet"
        case .toilet:  return "toilet"
        case .sink:    return "sink"
        case .tv:      return "tv"
        case .rug:     return "square.dashed"
        case .plant:   return "leaf"
        case .other:   return "cube"
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .sofa:    return CGSize(width: 96, height: 42)
        case .bed:     return CGSize(width: 90, height: 70)
        case .table:   return CGSize(width: 70, height: 50)
        case .chair:   return CGSize(width: 40, height: 40)
        case .counter: return CGSize(width: 84, height: 30)
        case .toilet:  return CGSize(width: 36, height: 44)
        case .sink:    return CGSize(width: 40, height: 34)
        case .tv:      return CGSize(width: 70, height: 18)
        case .rug:     return CGSize(width: 90, height: 60)
        case .plant:   return CGSize(width: 34, height: 34)
        case .other:   return CGSize(width: 56, height: 44)
        }
    }
}

/// A furniture item placed on the map.
nonisolated struct FurnitureItem: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: FurnitureKind
    var frame: MapFrame

    init(id: UUID = UUID(), kind: FurnitureKind, frame: MapFrame) {
        self.id = id
        self.kind = kind
        self.frame = frame
    }

    var title: String { kind.title }
}
