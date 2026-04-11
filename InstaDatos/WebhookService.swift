import Foundation

enum WebhookConfig {
    static let url = URL(string: "https://ideally-wordy-elene.ngrok-free.dev/webhook/7ceea860-e184-4126-ae67-616a3429fb3e")!
}

/// Webhook OpenClaw (mensaje + user_id).
enum OpenClawWebhookConfig {
    static let url = URL(string: "https://misapply-semipreserved-quinn.ngrok-free.dev/webhook")!
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

struct OpenClawChatPayload: Encodable {
    let message: String
    let user_id: Int64
}

enum WebhookService {
    /// Envía el texto del chat a OpenClaw; cabecera `ngrok-skip-browser-warning` para túneles ngrok.
    static func sendOpenClawChat(message: String, userId: Int64) async throws -> Data {
        var req = URLRequest(url: OpenClawWebhookConfig.url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        let payload = OpenClawChatPayload(message: message, user_id: userId)
        req.httpBody = try JSONEncoder().encode(payload)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "WebhookService", code: 2, userInfo: [NSLocalizedDescriptionKey: "OpenClaw respondió con error."])
        }
        return data
    }

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

