import SwiftUI

struct RegistroDetailView: View {
    @EnvironmentObject private var store: RegistroStore
    @EnvironmentObject private var supabase: SupabaseService
    let registro: Registro

    @StateObject private var transcriber = SpeechTranscriber()
    @State private var composerText: String = ""

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 10) {
                messagesList

                composer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .navigationTitle(registro.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: transcriber.transcript) { _, newValue in
            // Mientras escucha, reflejamos el texto en el input (sin forzar si el usuario está escribiendo).
            if case .listening = transcriber.state {
                composerText = newValue
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                micStatus
            }
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(store.messages(for: registro.id)) { m in
                        messageBubble(m)
                            .id(m.id)
                    }
                }
                .padding(.top, 12)
            }
            .onChange(of: store.messages(for: registro.id).count) { _, _ in
                guard let last = store.messages(for: registro.id).last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private func messageBubble(_ m: ChatMessage) -> some View {
        let isUser = (m.role == .user)
        return HStack {
            if isUser { Spacer(minLength: 20) }

            Text(m.text)
                .font(.callout)
                .foregroundStyle(isUser ? Color.white : AppTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isUser ? AppTheme.accent : AppTheme.muted.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppTheme.muted.opacity(isUser ? 0.0 : 0.35), lineWidth: 1)
                        )
                )
                .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 20) }
        }
    }

    private var composer: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Chat")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.cocoa)

                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Escribe o dicta…", text: $composerText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.muted.opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.muted.opacity(0.35), lineWidth: 1)
                                )
                        )

                    Button {
                        Task { await toggleMic() }
                    } label: {
                        Image(systemName: micIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(micColor)
                            )
                    }
                    .accessibilityLabel("Micrófono")

                    Button {
                        send()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppTheme.cocoa)
                            )
                    }
                    .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Enviar")
                }

                if case let .denied(msg) = transcriber.state {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.85))
                } else if case let .error(msg) = transcriber.state {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.85))
                } else if case .listening = transcriber.state {
                    Text("Escuchando…")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.cocoa.opacity(0.75))
                }
            }
        }
    }

    private var micStatus: some View {
        Group {
            if case .listening = transcriber.state {
                Text("Dictando")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private var micIcon: String {
        if case .listening = transcriber.state { return "mic.fill" }
        return "mic"
    }

    private var micColor: Color {
        if case .listening = transcriber.state { return AppTheme.accent }
        return AppTheme.muted.opacity(0.65)
    }

    private func toggleMic() async {
        if case .listening = transcriber.state {
            transcriber.stop()
        } else {
            await transcriber.start()
        }
    }

    private func send() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        transcriber.stop()
        store.appendMessage(ChatMessage(role: .user, text: trimmed), to: registro.id)
        composerText = ""

        Task {
            do {
                let registroIdStr = registro.dbRowId.map { String($0) } ?? registro.id.uuidString
                let schemaNombre = supabase.userSchemaName ?? ""
                try await WebhookService.sendRegistroMessage(
                    registroId: registroIdStr,
                    schemaNombre: schemaNombre,
                    registroNombre: registro.nombre,
                    mensaje: trimmed,
                    userId: supabase.dbUserID,
                    correo: supabase.authEmail
                )
                store.appendMessage(ChatMessage(role: .system, text: "Enviado al webhook."), to: registro.id)
            } catch {
                store.appendMessage(ChatMessage(role: .system, text: "Error enviando webhook: \(error.localizedDescription)"), to: registro.id)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RegistroDetailView(registro: Registro(nombre: "Demo"))
            .environmentObject(RegistroStore())
            .environmentObject(SupabaseService.shared)
    }
}

