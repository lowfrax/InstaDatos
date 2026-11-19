import Foundation
import Combine

@MainActor
final class RegistroStore: ObservableObject {
    @Published var registros: [Registro] = []

    @Published var messagesByRegistroID: [UUID: [ChatMessage]] = [:]

    func setRegistros(_ items: [Registro]) {
        registros = items
    }

    func addRegistro(_ r: Registro) {
        registros.insert(r, at: 0)
    }

    func appendMessage(_ message: ChatMessage, to registroID: UUID) {
        messagesByRegistroID[registroID, default: []].append(message)
    }
}

