import Foundation
import Supabase
import Combine
import CryptoKit

enum SupabaseConfig {
    static let url = URL(string: "https://imcsnudboiqabogtniqq.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltY3NudWRib2lxYWJvZ3RuaXFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1OTg0MTIsImV4cCI6MjA5MDE3NDQxMn0.aTnsA_GqH5YteUDsfr8JMk10btBgYxvroppCsPkvO5c"
}

private struct CreateUserSchemaParams: Encodable, Sendable {
    let user_id: Int64
}

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    let client: SupabaseClient

    @Published var isSignedIn: Bool = false
    @Published var authEmail: String?
    @Published var dbUserID: Int64?

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )

        Task {
            await refreshSession()
        }
    }

    func refreshSession() async {
        do {
            let session = try await client.auth.session
            isSignedIn = session.user.email != nil
            authEmail = session.user.email
            if let email = session.user.email {
                dbUserID = try? await fetchDBUserID(correo: email)
            } else {
                dbUserID = nil
            }
        } catch {
            isSignedIn = false
            authEmail = nil
            dbUserID = nil
        }
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
        await refreshSession()

        // Con RLS desactivado, garantizamos que exista un perfil en public.users.
        let correo = email.trimmingCharacters(in: .whitespacesAndNewlines)
        dbUserID = try? await ensureDBUserExists(correo: correo)
    }

    func signUp(nombre: String, correo: String, password: String, telefono: String?) async throws {
        let correoTrimmed = correo.trimmingCharacters(in: .whitespacesAndNewlines)
        try await client.auth.signUp(email: correoTrimmed, password: password)
        await refreshSession()

        // RLS desactivado: creamos el perfil en public.users como paso requerido.
        // Guardamos un hash (no texto plano) en public.users.password.
        let userID = try await insertDBUser(
            nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
            correo: correoTrimmed,
            telefono: telefono,
            passwordHash: Self.hashPassword(password)
        )
        dbUserID = userID

        // Creamos schema por usuario vía RPC (debes crear el RPC en Supabase, ver nota).
        try await createUserSchema(userId: userID)
    }

    func signOut() async {
        do { try await client.auth.signOut() } catch {}
        await refreshSession()
    }

    private func fetchDBUserID(correo: String) async throws -> Int64? {
        struct DBUserRow: Decodable { let id: Int64 }
        let rows: [DBUserRow] = try await client
            .from("users")
            .select("id")
            .eq("correo", value: correo)
            .limit(1)
            .execute()
            .value
        return rows.first?.id
    }

    private func ensureDBUserExists(correo: String) async throws -> Int64 {
        if let id = try await fetchDBUserID(correo: correo) { return id }
        return try await insertDBUser(nombre: nil, correo: correo, telefono: nil, passwordHash: nil)
    }

    private func insertDBUser(nombre: String?, correo: String, telefono: String?, passwordHash: String?) async throws -> Int64 {
        struct DBUserInsert: Encodable {
            let nombre: String?
            let correo: String?
            let password: String?
            let telefono: Int64?
        }
        struct DBUserRow: Decodable { let id: Int64 }

        let telValue: Int64?
        if let telefono, !telefono.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            telValue = Int64(telefono)
        } else {
            telValue = nil
        }

        let payload = DBUserInsert(nombre: nombre, correo: correo, password: passwordHash, telefono: telValue)

        // Pedimos que devuelva el id insertado.
        let inserted: [DBUserRow] = try await client
            .from("users")
            .insert(payload)
            .select("id")
            .execute()
            .value

        guard let id = inserted.first?.id else {
            throw NSError(domain: "SupabaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se pudo obtener el id del usuario insertado."])
        }
        return id
    }

    private func createUserSchema(userId: Int64) async throws {
        _ = try await client
            .rpc("create_user_schema", params: CreateUserSchemaParams(user_id: userId))
            .execute()
    }

    private static func hashPassword(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

