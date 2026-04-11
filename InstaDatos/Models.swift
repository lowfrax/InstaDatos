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

/// Fila de `public.chat` (OpenClaw / historial persistente).
struct PersistedChatLine: Identifiable, Hashable {
    let id: Int64
    var contenido: String
    /// Valores esperados: `humano`, `IA`, `contexto`.
    var tipo: String
    var createdAt: Date

    var isHumano: Bool {
        tipo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "humano"
    }

    var isIA: Bool {
        tipo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "ia"
    }

    var isContexto: Bool {
        tipo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "contexto"
    }
}

