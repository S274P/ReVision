import Foundation
import Combine

/// A message the app wants to send — drives the Messages composer sheet.
struct PendingMessage: Identifiable {
    let id = UUID()
    var recipients: [String]
    var body: String
    var imageData: Data? = nil
}

/// Holds the family/caretaker contacts and the "please send this" state.
/// Stored on its own (UserDefaults) so it doesn't depend on the rest of the app.
@MainActor
final class FamilyStore: ObservableObject {
    @Published var contacts: [FamilyContact] { didSet { save() } }
    /// When set, a view presents the Messages composer for it.
    @Published var pending: PendingMessage?

    private let key = "familyContacts"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([FamilyContact].self, from: data) {
            contacts = list
        } else {
            contacts = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - Manage contacts

    func addContact(name: String, phone: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !p.isEmpty else { return }
        contacts.append(FamilyContact(name: n, phone: p))
    }

    /// Update an existing contact's name/phone (matched by id).
    func update(_ contact: FamilyContact) {
        guard let idx = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        let n = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = contact.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !p.isEmpty else { return }
        contacts[idx].name = n
        contacts[idx].phone = p
    }

    func remove(_ id: UUID) { contacts.removeAll { $0.id == id } }

    // MARK: - Send

    /// Compose a "need help" message to everyone, including the current room + optional photo.
    func requestHelp(currentRoom: String, image: Data? = nil) {
        guard !contacts.isEmpty else { return }
        let clean = currentRoom.trimmingCharacters(in: .whitespaces)
        let loc = (clean.isEmpty || clean.lowercased() == "not set")
            ? ""
            : " I'm in the \(clean.lowercased())."
        pending = PendingMessage(recipients: contacts.map { $0.phone },
                                 body: "I need help.\(loc) — sent from SmartWalker.",
                                 imageData: image)
    }

    /// Share current location with everyone.
    func shareLocation(currentRoom: String, image: Data? = nil) {
        guard !contacts.isEmpty else { return }
        let clean = currentRoom.trimmingCharacters(in: .whitespaces)
        let loc = (clean.isEmpty || clean.lowercased() == "not set")
            ? "I'm not sure which room I'm in right now."
            : "I'm in the \(clean.lowercased()) right now."
        pending = PendingMessage(recipients: contacts.map { $0.phone },
                                 body: "\(loc) — sent from SmartWalker.",
                                 imageData: image)
    }

    /// Free-form message to one named contact (used by voice messaging).
    @discardableResult
    func message(toName name: String, body: String) -> Bool {
        guard let match = bestMatch(name) else { return false }
        pending = PendingMessage(recipients: [match.phone], body: body)
        return true
    }

    func bestMatch(_ name: String) -> FamilyContact? {
        let key = name.lowercased().trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        return contacts.first { $0.name.lowercased() == key }
            ?? contacts.first { $0.name.lowercased().contains(key) || key.contains($0.name.lowercased()) }
    }
}
