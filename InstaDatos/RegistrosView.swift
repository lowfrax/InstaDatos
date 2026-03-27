import SwiftUI

struct RegistrosView: View {
    @EnvironmentObject private var store: RegistroStore

    @State private var newName: String = ""
    @State private var showingCreate = false

    var body: some View {
        ZStack {
            AppTheme.bg.ignoresSafeArea()

            VStack(spacing: 12) {
                if store.registros.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .padding(16)
        }
        .navigationTitle("Registros")
        .navigationBarTitleDisplayMode(.inline)
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

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.registros) { r in
                    NavigationLink {
                        RegistroDetailView(registro: r)
                            .environmentObject(store)
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

                    Button("Crear") {
                        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        _ = store.createRegistro(nombre: trimmed)
                        newName = ""
                        showingCreate = false
                    }
                    .buttonStyle(SoftButtonStyle())

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
    }
}

