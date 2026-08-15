import SwiftUI

@main
struct SmartWalkerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var family = FamilyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(family)
                .onAppear { installVoiceRouting() }
        }
    }

    /// Intercept recognized speech: handle family voice commands here and pass
    /// everything else to the normal navigation handler. Done at the wiring layer
    /// so it needs no changes to AppState or the navigation parser.
    private func installVoiceRouting() {
        let a = appState
        let f = family
        a.recognizer.onFinalResult = { [weak a, weak f] phrase in
            guard let a, let f else { return }
            if let intent = FamilyVoice.parse(phrase) {
                switch intent {
                case .message(let name, let body):
                    if f.message(toName: name, body: body) {
                        a.speech.speak("Preparing a message to \(name).", priority: .normal)
                    } else {
                        a.speech.speak("I couldn't find \(name) in your family list.", priority: .normal)
                    }
                case .help:
                    if f.contacts.isEmpty {
                        a.speech.speak("No family members have been added yet.", priority: .normal)
                    } else {
                        a.speech.speak("Notifying your family.", priority: .normal)
                        let room = a.layout.room(withID: a.layout.currentRoomID)?.name ?? ""
                        Task {
                            let photo = await SnapshotService.capture()
                            f.requestHelp(currentRoom: room, image: photo)
                        }
                    }
                }
            } else {
                a.handleVoiceCommand(phrase)
            }
        }
    }
}
