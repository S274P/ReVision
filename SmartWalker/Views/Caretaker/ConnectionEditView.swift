import SwiftUI

/// Create a new connection or edit an existing one's rooms + spoken instruction.
struct ConnectionEditView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    let existing: Connection?

    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var instruction: String
    @State private var bidirectional: Bool
    @State private var reverseInstruction: String

    init(existing: Connection?) {
        self.existing = existing
        _fromID = State(initialValue: existing?.fromRoomID)
        _toID = State(initialValue: existing?.toRoomID)
        _instruction = State(initialValue: existing?.instruction ?? "")
        _bidirectional = State(initialValue: existing == nil)
        _reverseInstruction = State(initialValue: "")
    }

    private var isEditing: Bool { existing != nil }

    var body: some View {
        Form {
            Section("Path") {
                Picker("From", selection: $fromID) {
                    Text("Select room").tag(UUID?.none)
                    ForEach(app.layout.rooms) { r in
                        Text(r.name).tag(Optional(r.id))
                    }
                }
                Picker("To", selection: $toID) {
                    Text("Select room").tag(UUID?.none)
                    ForEach(app.layout.rooms) { r in
                        Text(r.name).tag(Optional(r.id))
                    }
                }
            }

            Section("Spoken instruction") {
                TextField("e.g. Turn left and continue toward the kitchen.",
                          text: $instruction, axis: .vertical)
                    .lineLimit(2...4)
            }

            if !isEditing {
                Section {
                    Toggle("Also add the reverse path", isOn: $bidirectional)
                    if bidirectional {
                        TextField("Reverse instruction (optional)",
                                  text: $reverseInstruction, axis: .vertical)
                            .lineLimit(2...4)
                    }
                } footer: {
                    Text("Most doorways work both ways. Leave the reverse instruction blank to fill it in later.")
                }
            }

            if isEditing, let existing {
                Section {
                    Button(role: .destructive) {
                        app.layout.removeConnection(existing.id)
                        dismiss()
                    } label: {
                        Label("Delete connection", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Connection" : "New Connection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(fromID == nil || toID == nil || fromID == toID)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func save() {
        guard let fromID, let toID, fromID != toID else { return }
        if let existing {
            // Update in place: rooms + instruction.
            if let idx = app.layout.connections.firstIndex(where: { $0.id == existing.id }) {
                app.layout.connections[idx].fromRoomID = fromID
                app.layout.connections[idx].toRoomID = toID
                app.layout.connections[idx].instruction =
                    instruction.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            app.layout.addConnection(
                from: fromID, to: toID,
                instruction: instruction.trimmingCharacters(in: .whitespacesAndNewlines),
                bidirectional: bidirectional,
                reverseInstruction: reverseInstruction.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        dismiss()
    }
}
