import Foundation

/// Nombre del esquema Postgres por usuario: `public.users.id` → `user_<id>` (ej. id 1 → `user_1`).
enum UserSchemaNaming {
    static func schemaName(publicUsersId: Int64) -> String {
        "user_\(publicUsersId)"
    }
}
