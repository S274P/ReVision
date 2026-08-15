import SwiftUI

/// Caretaker screen to add, edit, and delete the family/caretaker contacts.
struct FamilyContactsView: View {
    @EnvironmentObject private var family: FamilyStore
    @State private var name = ""
    @State private var phone = ""
    @State private var editing: FamilyContact?

    var body: some View {
        List {
            Section {
                if family.contacts.isEmpty {
                    Text("No one added yet. Add family or caretakers who should be reachable for help.")
                        .foregroundStyle(.secondary)
                }
                ForEach(family.contacts) { contact in
                    Button {
                        editing = contact
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name).font(.body)
                                Text(contact.phone).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .tint(.primary)
                }
                .onDelete { indexSet in
                    indexSet.map { family.contacts[$0].id }.forEach { family.remove($0) }
                }
            } header: {
                Text("Family & caretakers")
            } footer: {
                Text("Tap a contact to edit it, or swipe left to delete.")
            }

            Section {
                TextField("Name (e.g. Mom)", text: $name)
                    .textInputAutocapitalization(.words)
                TextField("Phone number", text: $phone)
                    .keyboardType(.phonePad)
                Button {
                    family.addContact(name: name, phone: phone)
                    name = ""; phone = ""
                } label: {
                    Label("Add contact", systemImage: "plus.circle.fill")
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                          || phone.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                Text("Add someone")
            } footer: {
                Text("“Notify family” on the main screen texts everyone here your current room. Sends go through Messages so you confirm each one.")
            }
        }
        .navigationTitle("Family alerts")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { contact in
            EditContactSheet(contact: contact) { updated in
                family.update(updated)
            } onDelete: {
                family.remove(contact.id)
            }
        }
    }
}

/// Edit or delete a single contact.
private struct EditContactSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var phone: String
    let contact: FamilyContact
    let onSave: (FamilyContact) -> Void
    let onDelete: () -> Void

    init(contact: FamilyContact,
         onSave: @escaping (FamilyContact) -> Void,
         onDelete: @escaping () -> Void) {
        self.contact = contact
        _name = State(initialValue: contact.name)
        _phone = State(initialValue: contact.phone)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Phone number", text: $phone)
                        .keyboardType(.phonePad)
                }
                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete contact", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = contact
                        updated.name = name
                        updated.phone = phone
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                              || phone.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
