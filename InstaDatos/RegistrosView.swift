import SwiftUI

struct RegistrosView: View {
    @EnvironmentObject private var store: RegistroStore
    @EnvironmentObject private var supabase: SupabaseService

    @State private var newName: String = ""
    @State private var showingCreate = false
    @State private var loadError: String?
    @State private var createError: String?
    @State private var isLoading = false
    @State private var isCreating = false

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 12) {
                if let loadError {
                    Text(loadError)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let createError {
                    Text(createError)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if isLoading && store.registros.isEmpty {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.registros.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .padding(16)
        }
        .navigationTitle("Registros")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reloadRegistros()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            createSheet
        }
    }

    private func reloadRegistros() async {
        loadError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await supabase.ensureWorkspaceReady()
            let rows = try await supabase.fetchRegistros()
            store.setRegistros(rows)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.registros) { r in
                    NavigationLink {
                        RegistroDetailView(registro: r)
                            .environmentObject(store)
                            .environmentObject(supabase)
                    } label: {
                        SoftCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(r.nombre)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.ink)
                                    Text(r.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.cocoa.opacity(0.65))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.muted)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            SoftCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Aún no tienes registros.")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text("Crea uno para empezar a conversar y luego lo enviaremos a n8n.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.cocoa.opacity(0.75))

                    Button("Crear registro") { showingCreate = true }
                        .buttonStyle(SoftButtonStyle())
                }
            }
            Spacer()
        }
    }

    private var createSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    SoftTextField(title: "Nombre del registro", text: $newName, textContentType: .nickname)

                    if let createError {
                        Text(createError)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.85))
                    }

                    Button("Crear") {
                        Task {
                            createError = nil
                            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            isCreating = true
                            defer { isCreating = false }
                            do {
                                try await supabase.ensureWorkspaceReady()
                                let rowId = try await supabase.insertRegistro(nombre: trimmed, estado: "activo")
                                let r = Registro(dbRowId: rowId, nombre: trimmed, estado: "activo")
                                store.addRegistro(r)
                                newName = ""
                                showingCreate = false
                            } catch {
                                createError = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(SoftButtonStyle())
                    .disabled(isCreating)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Nuevo registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { showingCreate = false }
                        .foregroundStyle(AppTheme.cocoa)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        RegistrosView()
            .environmentObject(RegistroStore())
            .environmentObject(SupabaseService.shared)
    }
}

