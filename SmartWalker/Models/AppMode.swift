import Foundation

/// The three top-level modes of the app.
enum AppMode: String, CaseIterable, Identifiable {
    case userNavigation
    case safetyDetection
    case caretakerSetup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .userNavigation:  return "Navigation"
        case .safetyDetection: return "Safety"
        case .caretakerSetup:  return "Caretaker Setup"
        }
    }

    var systemImage: String {
        switch self {
        case .userNavigation:  return "location.north.line.fill"
        case .safetyDetection: return "eye.fill"
        case .caretakerSetup:  return "slider.horizontal.3"
        }
    }
}
