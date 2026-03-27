import Foundation

struct Registro: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var nombre: String
    var createdAt: Date = Date()
}

struct ChatMessage: Identifiable, Hashable, Codable {
    enum Role: String, Codable {
        case user
        case system
    }

    var id: UUID = UUID()
    var role: Role
    var text: String
    var timestamp: Date = Date()
}

