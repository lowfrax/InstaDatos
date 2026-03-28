import Foundation

struct Registro: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    /// Id de la fila en `user_<id>.registros` (Supabase), si aplica.
    var dbRowId: Int64?
    var nombre: String
    var estado: String = "activo"
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

