import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var supabase: SupabaseService

    @StateObject private var transcriber = SpeechTranscriber()
    @State private var composerText: String = ""
    @State private var lines: [PersistedChatLine] = []
    /// Texto del envío en curso: se muestra solo en UI hasta que en BD la última fila sea `IA`; luego se sustituye por `loadLines()`.
    @State private var pendingHumanText: String?
    @State private var loadError: String?
    @State private var sendError: String?
    @State private var isLoading = false
    @State private var isSending = false
    /// Cancela el sondeo al salir del chat o al iniciar un envío nuevo.
    @State private var sendTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 10) {
                if let loadError {
                    Text(loadError)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let sendError {
                    Text(sendError)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                messagesList

                composer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: supabase.dbUserID) {
            await loadChatHistoryForCurrentUser()
        }
        .onDisappear {
            sendTask?.cancel()
        }
        .onChange(of: transcriber.transcript) { _, newValue in
            if case .listening = transcriber.state {
                composerText = newValue
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                micToolbarLabel
            }
        }
    }

    private var micToolbarLabel: some View {
        Group {
            if case .listening = transcriber.state {
                Text("Dictando")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.brandOrange)
            }
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if isLoading && lines.isEmpty && pendingHumanText == nil {
                        ProgressView()
                            .tint(AppTheme.brandOrange)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if lines.isEmpty && pendingHumanText == nil {
                        Text("Escribe un mensaje para enviarlo a OpenClaw. Se guardará en tu historial.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.cocoa.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 32)
                    } else {
                        ForEach(lines) { line in
                            chatBubble(line)
                                .id(line.id)
                        }
                        if let pending = pendingHumanText {
                            pendingHumanBubble(pending)
                                .id("pending-human")
                        }
                    }
                }
                .padding(.top, 12)
            }
            .onChange(of: lines.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: pendingHumanText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if pendingHumanText != nil {
                proxy.scrollTo("pending-human", anchor: .bottom)
            } else if let last = lines.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func chatBubble(_ line: PersistedChatLine) -> some View {
        let humano = line.isHumano
        let ia = line.isIA
        let bg: Color = {
            if humano { return AppTheme.brandOrange }
            if ia { return AppTheme.aiGrey.opacity(0.35) }
            return AppTheme.muted.opacity(0.22)
        }()
        let fg: Color = {
            if humano { return .white }
            if ia { return AppTheme.ink }
            return AppTheme.cocoa
        }()

        return HStack {
            if humano { Spacer(minLength: 28) }

            VStack(alignment: humano ? .trailing : .leading, spacing: 4) {
                Text(line.contenido)
                    .font(.callout)
                    .foregroundStyle(fg)
                    .multilineTextAlignment(humano ? .trailing : .leading)

                Text(line.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(fg.opacity(0.75))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.muted.opacity(humano ? 0.0 : 0.35), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 300, alignment: humano ? .trailing : .leading)

            if !humano { Spacer(minLength: 28) }
        }
    }

    private func pendingHumanBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 28)
            VStack(alignment: .trailing, spacing: 4) {
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                if isSending {
                    Text("Esperando respuesta…")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.brandOrange.opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.brandOrange.opacity(0.4), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 300, alignment: .trailing)
        }
    }

    private var composer: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("OpenClaw")
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
                        sendTask?.cancel()
                        sendTask = Task { await send() }
                    } label: {
                        Group {
                            if isSending {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.cocoa)
                        )
                    }
                    .disabled(isSending || composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    private var micIcon: String {
        if case .listening = transcriber.state { return "mic.fill" }
        return "mic"
    }

    private var micColor: Color {
        if case .listening = transcriber.state { return AppTheme.brandOrange }
        return AppTheme.muted.opacity(0.65)
    }

    private func toggleMic() async {
        if case .listening = transcriber.state {
            transcriber.stop()
        } else {
            await transcriber.start()
        }
    }

    /// Historial `chat_openclaw` filtrado por `user_id` del perfil `public.users` actual.
    private func loadChatHistoryForCurrentUser() async {
        loadError = nil
        if supabase.dbUserID == nil, supabase.isSignedIn {
            await supabase.refreshSession()
        }
        await loadLines()
    }

    private func loadLines() async {
        loadError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let rows = try await supabase.fetchChatLines()
            lines = rows
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Consulta en bucle hasta que la última fila del usuario sea `IA`, o hasta cancelación del `Task`.
    private func waitUntilLatestRowIsIA() async throws {
        while true {
            try Task.checkCancellation()
            if let latest = try await supabase.fetchLatestChatLine(), latest.isIA {
                return
            }
            try await Task.sleep(nanoseconds: 400_000_000)
        }
    }

    private func send() async {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let uid = supabase.dbUserID else {
            sendError = "No hay usuario en sesión."
            return
        }

        sendError = nil
        transcriber.stop()
        isSending = true
        defer { isSending = false }

        do {
            // El mensaje "humano" lo inserta solo el webhook (`insert_chat` en webhook_clawbot.py).
            // Si también insertáramos aquí, habría dos filas por cada envío (app + Python).
            composerText = ""
            pendingHumanText = trimmed

            _ = try await WebhookService.sendOpenClawChat(message: trimmed, userId: uid)

            try await waitUntilLatestRowIsIA()

            pendingHumanText = nil
            await loadLines()
        } catch is CancellationError {
            pendingHumanText = nil
            await loadLines()
        } catch {
            sendError = error.localizedDescription
            pendingHumanText = nil
            await loadLines()
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
            .environmentObject(SupabaseService.shared)
    }
}
