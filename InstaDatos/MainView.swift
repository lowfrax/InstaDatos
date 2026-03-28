import SwiftUI

struct MainView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @StateObject private var store = RegistroStore()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header

                        NavigationLink {
                            RegistrosView()
                                .environmentObject(store)
                                .environmentObject(supabase)
                        } label: {
                            SoftCard {
                                HStack(alignment: .center, spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(AppTheme.accent.opacity(0.16))
                                            .frame(width: 52, height: 52)
                                        Image(systemName: "square.stack.3d.up")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(AppTheme.accent)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Registros")
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.ink)
                                        Text("Crea y administra tus registros.")
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.cocoa.opacity(0.75))
                                    }

                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(AppTheme.muted)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salir") {
                        Task { await supabase.signOut() }
                    }
                    .foregroundStyle(AppTheme.cocoa)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Inicio")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
            if let authEmail = supabase.authEmail {
                Text(authEmail)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.cocoa.opacity(0.75))
            }
        }
        .padding(.top, 6)
    }
}

#Preview {
    MainView()
        .environmentObject(SupabaseService.shared)
}

