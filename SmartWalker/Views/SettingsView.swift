import SwiftUI

/// Caretaker settings: voice speed, family alerts, and distance units.
struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Slower speech", isOn: $app.speechSlow)
                    Button {
                        app.speech.speak("This is how the voice will sound. Take your time.",
                                         priority: .normal)
                    } label: {
                        Label("Test voice", systemImage: "speaker.wave.2.fill")
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    Text("Slower speech is easier to follow. Tap Test voice to hear it.")
                }

                Section {
                    NavigationLink {
                        FamilyContactsView()
                    } label: {
                        Label("Family alerts", systemImage: "person.2.fill")
                    }
                } header: {
                    Text("Family")
                } footer: {
                    Text("Add family or caretakers who can be reached for help.")
                }

                Section {
                    Picker("Units", selection: $app.units) {
                        ForEach(Units.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                } header: {
                    Text("Distance")
                } footer: {
                    Text("Used when the app speaks distances.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
