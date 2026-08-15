import SwiftUI

/// Primary mode for the walker user: large buttons, spoken feedback, live status.
struct UserNavigationView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var family: FamilyStore
    @State private var showLocationPicker = false
    @State private var showDestinationPicker = false

    private var currentLocationName: String {
        app.layout.room(withID: app.layout.currentRoomID)?.name ?? "Not set"
    }

    private var destinationName: String {
        app.navigation.session?.destination.name ?? "None"
    }

    private var currentInstruction: String {
        guard let session = app.navigation.session else { return "Say or choose a destination." }
        return session.currentStep?.instruction ?? "Arriving…"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing) {
                header

                StatusCard(label: "Current location",
                           value: currentLocationName,
                           systemImage: "mappin.circle.fill")

                StatusCard(label: "Destination",
                           value: destinationName,
                           systemImage: "flag.checkered")

                StatusCard(label: "Instruction",
                           value: currentInstruction,
                           valueColor: Theme.accent,
                           systemImage: "arrow.turn.up.right")

                if app.navigation.isNavigating {
                    navigationControls
                } else {
                    startControls
                }

                helpButton

                detectionStatus
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .task {
            await app.requestNavigationPermissions()
            app.startListening()
        }
        .onDisappear { app.stopListening() }
        .sheet(isPresented: $showLocationPicker) {
            RoomPickerSheet(title: "I am in…") { room in
                app.setCurrentLocation(to: room)
            }
        }
        .sheet(isPresented: $showDestinationPicker) {
            RoomPickerSheet(title: "Take me to…") { room in
                app.navigate(to: room)
            }
        }
        .sheet(item: $family.pending) { pending in
            if MessageComposer.canSend {
                MessageComposer(recipients: pending.recipients,
                                body: pending.body,
                                imageData: pending.imageData) {
                    family.pending = nil
                }
            } else {
                VStack(spacing: 16) {
                    Text("This device can't send text messages.")
                        .font(Theme.body)
                        .multilineTextAlignment(.center)
                    Button("OK") { family.pending = nil }
                        .font(Theme.label)
                }
                .padding(30)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("Smart Walker")
                .font(Theme.hugeTitle)
                .foregroundStyle(Theme.primaryText)
            Spacer()
            Image(systemName: app.recognizer.isListening ? "mic.fill" : "mic.slash.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(app.recognizer.isListening ? Theme.safe : Theme.secondaryText)
                .accessibilityLabel(app.recognizer.isListening ? "Listening" : "Not listening")
        }
    }

    private var startControls: some View {
        VStack(spacing: Theme.spacing) {
            BigButton(title: "Set my location",
                      systemImage: "mappin.and.ellipse",
                      background: Theme.surface,
                      foreground: Theme.primaryText) {
                showLocationPicker = true
            }
            BigButton(title: "Choose destination",
                      systemImage: "flag.checkered") {
                showDestinationPicker = true
            }
            BigButton(title: "Where am I?",
                      systemImage: "questionmark.circle.fill",
                      background: Theme.surface,
                      foreground: Theme.primaryText) {
                _ = app.whereAmI()
            }
        }
    }

    private var navigationControls: some View {
        VStack(spacing: Theme.spacing) {
            Text(app.navigation.session?.progressText ?? "")
                .font(Theme.label)
                .foregroundStyle(Theme.secondaryText)

            BigButton(title: "Next / I'm here",
                      systemImage: "checkmark.circle.fill",
                      background: Theme.safe,
                      foreground: .black) {
                app.advance()
            }
            BigButton(title: "Repeat",
                      systemImage: "arrow.clockwise",
                      background: Theme.surface,
                      foreground: Theme.primaryText) {
                app.repeatInstruction()
            }
            BigButton(title: "Cancel route",
                      systemImage: "xmark.circle.fill",
                      background: Theme.danger,
                      foreground: .white) {
                app.cancelRoute()
            }
        }
    }

    // MARK: - Notify family

    private var helpButton: some View {
        BigButton(title: "Notify family",
                  systemImage: "person.2.fill",
                  background: Theme.caution,
                  foreground: .black) {
            if family.contacts.isEmpty {
                app.speech.speak("No family members have been added yet. Please add them in settings.",
                                 priority: .normal)
            } else {
                app.speech.speak("Notifying your family.", priority: .normal)
                let room = currentLocationName
                Task {
                    let photo = await SnapshotService.capture()
                    family.requestHelp(currentRoom: room, image: photo)
                }
            }
        }
    }

    private var detectionStatus: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(app.safetyEnabled ? Theme.safe : Theme.secondaryText)
                .frame(width: 14, height: 14)
            Text(app.safetyEnabled
                 ? "Safety detection ON — \(app.safety.lastWarning)"
                 : "Safety detection OFF")
                .font(Theme.label)
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Toggle("", isOn: $app.safetyEnabled)
                .labelsHidden()
                .tint(Theme.safe)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .onChange(of: app.safetyEnabled) { _, enabled in
            if enabled { app.startSafety() } else { app.stopSafety() }
        }
    }
}

/// Reusable large-button room picker used for both location and destination.
struct RoomPickerSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onPick: (Room) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacing) {
                    ForEach(app.layout.rooms) { room in
                        BigButton(title: room.name,
                                  systemImage: "door.left.hand.open") {
                            onPick(room)
                            dismiss()
                        }
                    }
                    if app.layout.rooms.isEmpty {
                        Text("No rooms yet. Ask your caretaker to add rooms in Caretaker Setup.")
                            .font(Theme.body)
                            .foregroundStyle(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(Theme.label)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
