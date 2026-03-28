import Foundation

enum WebhookConfig {
    static let url = URL(string: "https://ideally-wordy-elene.ngrok-free.dev/webhook/7ceea860-e184-4126-ae67-616a3429fb3e")!
}

struct WebhookPayload: Encodable {
    /// Id del registro (fila en `registros` del esquema del usuario, o UUID local si aún no hay fila).
    let registroId: String
    /// Esquema del usuario, p. ej. `user_1` para `public.users.id = 1`.
    let schemaNombre: String
    let registroNombre: String
    let mensaje: String
    let userId: Int64?
    let correo: String?
}

enum WebhookService {
    static func sendRegistroMessage(
        registroId: String,
        schemaNombre: String,
        registroNombre: String,
        mensaje: String,
        userId: Int64?,
        correo: String?
    ) async throws {
        var req = URLRequest(url: WebhookConfig.url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = WebhookPayload(
            registroId: registroId,
            schemaNombre: schemaNombre,
            registroNombre: registroNombre,
            mensaje: mensaje,
            userId: userId,
            correo: correo
        )
        req.httpBody = try JSONEncoder().encode(payload)

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "WebhookService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Webhook respondió con error."])
        }
    }
}

