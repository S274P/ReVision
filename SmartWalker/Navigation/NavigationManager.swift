import Foundation
import Combine

/// Drives step-by-step navigation: starting a route, advancing, repeating, cancelling,
/// and producing the short spoken lines the synthesizer will read.
///
/// This object owns only navigation state. It speaks via a closure so it stays decoupled
/// from the speech layer (and easy to unit-test). The closure's second argument is an
/// optional clip key — for a step instruction it's the doorway's connection, so a
/// caretaker's recorded voice can be played instead of the synthesized voice.
@MainActor
final class NavigationManager: ObservableObject {
    @Published private(set) var session: NavigationSession?

    /// Called with a line to speak, plus an optional recorded-clip key.
    var speak: (String, String?) -> Void = { _, _ in }

    var isNavigating: Bool { session != nil && !(session?.isArrived ?? true) }

    /// Recorded-clip key for a step's doorway direction, if any.
    private func stepClip(_ step: RouteStep?) -> String? {
        guard let id = step?.connectionID else { return nil }
        return "dw:\(id.uuidString)"
    }

    // MARK: - Start

    /// Attempts to start navigation. Returns a spoken result; also speaks it.
    @discardableResult
    func startRoute(in layout: HouseLayout, to destination: Room) -> String {
        guard let originID = layout.currentRoomID,
              let origin = layout.room(withID: originID) else {
            let msg = "I need to know where you are starting from. Please say your current room."
            speak(msg, nil)
            return msg
        }

        if origin.id == destination.id {
            let msg = "You are already in the \(destination.name.lowercased())."
            speak(msg, nil)
            return msg
        }

        guard let steps = RouteEngine.route(in: layout, from: origin.id, to: destination.id),
              !steps.isEmpty else {
            let msg = "No route found to the \(destination.name.lowercased())."
            speak(msg, nil)
            return msg
        }

        session = NavigationSession(origin: origin, destination: destination, steps: steps)
        let intro = "Starting route to \(destination.name.lowercased())."
        let first = steps[0].instruction
        speak(intro, nil)
        speak(first, stepClip(steps[0]))
        return "\(intro) \(first)"
    }

    // MARK: - Progress

    /// User confirmed they finished the current step ("Next" / "I'm here").
    @discardableResult
    func advance() -> String {
        guard var current = session else {
            let msg = "There is no active route."
            speak(msg, nil)
            return msg
        }
        current.stepIndex += 1
        session = current

        if current.isArrived {
            let msg = "You have arrived at the \(current.destination.name.lowercased())."
            speak(msg, nil)
            session = nil
            return msg
        } else {
            let step = current.currentStep
            let msg = step?.instruction ?? "Continue forward."
            speak(msg, stepClip(step))
            return msg
        }
    }

    /// Re-reads the current instruction.
    @discardableResult
    func repeatInstruction() -> String {
        guard let current = session, let step = current.currentStep else {
            let msg = "There is no active route."
            speak(msg, nil)
            return msg
        }
        speak("Repeating instruction.", nil)
        speak(step.instruction, stepClip(step))
        return step.instruction
    }

    /// Cancels the active route.
    @discardableResult
    func cancel() -> String {
        let msg: String
        if session != nil {
            session = nil
            msg = "Route canceled."
        } else {
            msg = "There is no active route to cancel."
        }
        speak(msg, nil)
        return msg
    }

    /// Answers "Where am I?" honestly, given the stored current location.
    func whereAmI(in layout: HouseLayout) -> String {
        if let session {
            let approx = session.approximateRoom.name.lowercased()
            let dest = session.destination.name.lowercased()
            let origin = session.origin.name.lowercased()
            let msg = "You are on the route from \(origin) to \(dest). The app thinks you are near the \(approx)."
            speak(msg, nil)
            return msg
        }
        if let currentID = layout.currentRoomID, let room = layout.room(withID: currentID) {
            let msg = "You are currently set to \(room.name.lowercased())."
            speak(msg, nil)
            return msg
        }
        let msg = "I don't know where you are yet. Please say your current room."
        speak(msg, nil)
        return msg
    }
}
