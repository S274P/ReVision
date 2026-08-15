import Foundation

/// A family member or caretaker who can be contacted for help.
struct FamilyContact: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var phone: String

    init(id: UUID = UUID(), name: String, phone: String) {
        self.id = id
        self.name = name
        self.phone = phone
    }
}
