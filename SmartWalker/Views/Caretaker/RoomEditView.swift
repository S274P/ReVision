import SwiftUI

/// Rename a room, mark it as the user's current location, or delete it.
struct RoomEditView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let room: Room
    @State private var name: String

    init(room: Room) {
        self.room = room
        _name = State(initialValue: room.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Room name", text: $name)
                }
                Section {
                    Button {
                        if let r = app.layout.room(withID: room.id) {
                            app.setCurrentLocation(to: r)
                        }
                    } label: {
                        Label(room.id == app.layout.currentRoomID
                              ? "This is the current location"
                              : "Set as current location",
                              systemImage: "mappin.circle")
                    }
                    .disabled(room.id == app.layout.currentRoomID)
                }
                Section {
                    Button(role: .destructive) {
                        app.layout.removeRoom(room.id)
                        dismiss()
                    } label: {
                        Label("Delete room", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { app.layout.renameRoom(room.id, to: trimmed) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
