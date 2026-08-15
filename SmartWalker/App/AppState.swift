import Foundation
import Combine
import CoreVideo

/// Top-level coordinator. Owns the layout + all managers, wires them together, and
/// exposes the intent methods the UI and voice layer call. This is the single source
/// of truth injected into the SwiftUI environment.
@MainActor
final class AppState: ObservableObject {

    // Persisted domain data
    @Published var layout: HouseLayout {
        didSet { LayoutStore.shared.save(layout) }
    }

    @Published var mode: AppMode = .userNavigation
    /// Whether safety detection runs alongside navigation.
    @Published var safetyEnabled: Bool = true

    /// Caretaker setting: speak more slowly for users who need extra time.
    @Published var speechSlow: Bool = UserDefaults.standard.bool(forKey: "speechSlow") {
        didSet {
            UserDefaults.standard.set(speechSlow, forKey: "speechSlow")
            speech.slowSpeech = speechSlow
        }
    }

    /// Caretaker setting: distance units used when the app speaks distances.
    @Published var units: Units =
        Units(rawValue: UserDefaults.standard.string(forKey: "units") ?? "feet") ?? .feet {
        didSet { UserDefaults.standard.set(units.rawValue, forKey: "units") }
    }

    // Managers
    let speech = SpeechSynthesizer()
    let recognizer = SpeechRecognizer()
    let navigation = NavigationManager()
    let camera = CameraManager()
    let detector = ObjectDetectionManager()
    let safety: SafetyAlertManager
    /// Caretaker voice recordings, played in place of TTS when present.
    let voice = VoiceLibrary()

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.layout = LayoutStore.shared.load()
        self.safety = SafetyAlertManager(speaker: speech)
        speech.slowSpeech = speechSlow   // apply the saved preference at startup
        speech.library = voice           // prefer recorded voice over TTS
        wireUp()
    }

    private func wireUp() {
        // Navigation speaks at normal priority — but only when no safety warning is active.
        // A step passes its doorway's clip key so the caretaker's recording can play.
        navigation.speak = { [weak self] line, clipKey in
            guard let self else { return }
            if self.safetyEnabled && self.safety.hasActiveWarning { return } // yield to safety
            self.speech.speak(line, priority: .normal, clipKey: clipKey)
        }

        // Voice commands from the mic.
        recognizer.onFinalResult = { [weak self] phrase in
            self?.handleVoiceCommand(phrase)
        }

        // Camera frames → detector.
        camera.onFrame = { [weak self] buffer in
            self?.detector.analyze(buffer)
        }

        // Detections → safety alerts.
        detector.onDetections = { [weak self] objects in
            guard let self, self.safetyEnabled else { return }
            self.safety.process(objects)
        }
    }

    // MARK: - Permissions

    func requestNavigationPermissions() async {
        await recognizer.requestAuthorization()
    }

    func requestCameraPermissions() async {
        await camera.requestAuthorization()
    }

    // MARK: - Mode / listening lifecycle

    func startListening() { recognizer.startListening() }
    func stopListening()  { recognizer.stopListening() }

    func startSafety() {
        guard camera.authorized else { return }
        safety.reset()
        camera.start()
    }

    func stopSafety() {
        camera.stop()
        safety.reset()
    }

    // MARK: - Intent methods (shared by buttons and voice)

    /// Set the user's current location by room, speaking a confirmation.
    @discardableResult
    func setCurrentLocation(to room: Room) -> String {
        layout.currentRoomID = room.id
        let msg = "Current location set to \(room.name.lowercased())."
        speech.speak(msg, priority: .normal)
        return msg
    }

    /// Start navigation to a destination room.
    @discardableResult
    func navigate(to room: Room) -> String {
        navigation.startRoute(in: layout, to: room)
    }

    @discardableResult func advance() -> String { navigation.advance() }
    @discardableResult func repeatInstruction() -> String { navigation.repeatInstruction() }

    @discardableResult
    func cancelRoute() -> String { navigation.cancel() }

    func whereAmI() -> String { navigation.whereAmI(in: layout) }

    @discardableResult
    func listRooms() -> String {
        guard !layout.rooms.isEmpty else {
            let msg = "No rooms have been set up yet."
            speech.speak(msg)
            return msg
        }
        let names = layout.rooms.map { $0.name.lowercased() }
        let list = names.count == 1 ? names[0]
            : names.dropLast().joined(separator: ", ") + ", and " + names.last!
        let msg = "Available rooms are: \(list)."
        speech.speak(msg)
        return msg
    }

    // MARK: - Voice command handling

    func handleVoiceCommand(_ phrase: String) {
        let command = VoiceCommandParser.parse(phrase)
        switch command {
        case .navigate(let roomPhrase):
            if let room = layout.room(matching: roomPhrase) {
                navigate(to: room)
            } else {
                speech.speak("I could not find a room called \(roomPhrase). Say: what rooms are available.")
            }

        case .setLocation(let roomPhrase):
            if let room = layout.room(matching: roomPhrase) {
                setCurrentLocation(to: room)
            } else {
                speech.speak("I could not find a room called \(roomPhrase).")
            }

        case .whereAmI:
            _ = whereAmI()

        case .listRooms:
            _ = listRooms()

        case .next:
            advance()

        case .repeatInstruction:
            repeatInstruction()

        case .cancel:
            cancelRoute()

        case .unknown:
            // Stay quiet on noise; only nudge if it half-looked like a command.
            break
        }
    }
}
