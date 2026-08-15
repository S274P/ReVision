import Foundation

/// Distance units the caretaker can choose. Feet is the default.
enum Units: String, CaseIterable, Identifiable {
    case feet, meters
    var id: String { rawValue }
    var title: String { self == .feet ? "Feet" : "Meters" }
}

/// Turns raw distances into friendly spoken phrases in the chosen unit.
/// Nothing measures real distance yet (obstacle urgency is area-based and
/// navigation uses written instructions), so this is ready for when it does.
enum Distance {
    static func spoken(meters: Double, in units: Units) -> String {
        switch units {
        case .feet:
            let feet = meters * 3.28084
            if feet < 3 { return "just ahead" }
            let steps = Int((feet / 2.5).rounded())          // ~2.5 ft per step
            return steps <= 12 ? "about \(steps) steps"
                               : "about \(Int(feet.rounded())) feet"
        case .meters:
            if meters < 1 { return "just ahead" }
            return "about \(Int(meters.rounded())) meters"
        }
    }
}
