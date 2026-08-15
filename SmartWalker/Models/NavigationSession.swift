import Foundation

/// A single leg of a route: "from this room, do this, and you'll be at that room."
struct RouteStep: Identifiable, Hashable {
    let id = UUID()
    let fromRoom: Room
    let toRoom: Room
    let instruction: String
    /// The connection this step travels, used to play a caretaker's recorded voice.
    let connectionID: UUID?
}

/// An in-progress navigation session over a computed route.
///
/// Location honesty: `stepIndex` reflects how far the *user has confirmed* they've
/// travelled (via "Next"/"I'm here"), not any automatic sensing. `approximateRoom`
/// is therefore the best guess, clearly labelled as such in the UI and speech.
struct NavigationSession {
    let origin: Room
    let destination: Room
    let steps: [RouteStep]
    /// Index of the step currently being performed. Equal to `steps.count` when arrived.
    var stepIndex: Int = 0

    var isArrived: Bool { stepIndex >= steps.count }

    var currentStep: RouteStep? {
        guard stepIndex >= 0, stepIndex < steps.count else { return nil }
        return steps[stepIndex]
    }

    /// The room the app *believes* the user is at right now (best guess).
    var approximateRoom: Room {
        if isArrived { return destination }
        return steps[stepIndex].fromRoom
    }

    /// "1 of 3", used in the UI.
    var progressText: String {
        "\(min(stepIndex + 1, steps.count)) of \(steps.count)"
    }
}
