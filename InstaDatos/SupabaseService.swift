import Foundation
import Supabase
import Combine

enum SupabaseConfig {
    static let url = URL(string: "https://imcsnudboiqabogtniqq.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltY3NudWRib2lxYWJvZ3RuaXFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1OTg0MTIsImV4cCI6MjA5MDE3NDQxMn0.aTnsA_GqH5YteUDsfr8JMk10btBgYxvroppCsPkvO5c"
}

@MainActor
final class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    let client: SupabaseClient

    @Published var isSignedIn: Bool = false
    @Published var authEmail: String?

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
        } catch {
            isSignedIn = false
            authEmail = nil
        }
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
        await refreshSession()

        // Con RLS desactivado, garantizamos que exista un perfil en public.users.
        let correo = email.trimmingCharacters(in: .whitespacesAndNewlines)
        try? await ensureDBUserExists(correo: correo)
    }

    func signUp(nombre: String, correo: String, password: String, telefono: String?) async throws {
        let correoTrimmed = correo.trimmingCharacters(in: .whitespacesAndNewlines)
        try await client.auth.signUp(email: correoTrimmed, password: password)
        await refreshSession()

        // RLS desactivado: creamos el perfil en public.users como paso requerido.
        // Nota: no guardamos contraseñas en texto plano en la tabla.
        try await upsertDBUser(
            nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
            correo: correoTrimmed,
            telefono: telefono
        )
    }

    func signOut() async {
        do { try await client.auth.signOut() } catch {}
        await refreshSession()
    }

    private func ensureDBUserExists(correo: String) async throws {
        struct DBUserRow: Decodable {
            let id: Int64
        }

        let existing = try await client
            .from("users")
            .select("id")
            .eq("correo", value: correo)
            .limit(1)
            .execute()
            .value as [DBUserRow]

        if existing.isEmpty {
            try await upsertDBUser(nombre: nil, correo: correo, telefono: nil)
        }
    }

    private func upsertDBUser(nombre: String?, correo: String, telefono: String?) async throws {
        struct DBUserInsert: Encodable {
            let nombre: String?
            let correo: String?
            let password: String?
            let telefono: Int64?
        }

        let telValue: Int64?
        if let telefono, !telefono.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            telValue = Int64(telefono)
        } else {
            telValue = nil
        }

        let payload = DBUserInsert(nombre: nombre, correo: correo, password: nil, telefono: telValue)

        // Con RLS desactivado, un insert simple suele ser suficiente.
        // Si en el futuro pones unique(correo), cambia esto a upsert con onConflict.
        _ = try await client.from("users").insert(payload).execute()
    }
}

