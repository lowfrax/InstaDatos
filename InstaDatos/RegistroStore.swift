import Foundation
import Combine

@MainActor
final class RegistroStore: ObservableObject {
    @Published var registros: [Registro] = [
        Registro(nombre: "Demo")
    ]

    @Published var messagesByRegistroID: [UUID: [ChatMessage]] = [:]

    func createRegistro(nombre: String) -> Registro {
        let r = Registro(nombre: nombre)
        registros.insert(r, at: 0)
        return r
    }

    func messages(for registroID: UUID) -> [ChatMessage] {
        messagesByRegistroID[registroID, default: []]
    }

    func appendMessage(_ message: ChatMessage, to registroID: UUID) {
        messagesByRegistroID[registroID, default: []].append(message)
    }
}

