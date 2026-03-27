import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var supabase: SupabaseService

    @State private var mode: Mode = .login

    @State private var nombre = ""
    @State private var email = ""
    @State private var password = ""
    @State private var telefono = ""

    @State private var isBusy = false
    @State private var errorText: String?
    @State private var successText: String?

    enum Mode: String, CaseIterable {
        case login = "Iniciar sesión"
        case signup = "Crear cuenta"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.bg,
                    AppTheme.muted.opacity(0.20),
                    AppTheme.bg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("InstaDatos")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.ink)

                        Text("Crea tablas y registros por lenguaje natural.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.cocoa.opacity(0.85))
                    }
                    .padding(.top, 24)

                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    SoftCard {
                        VStack(alignment: .leading, spacing: 14) {
                            if mode == .signup {
                                SoftTextField(title: "Nombre", text: $nombre, textContentType: .name)
                            }

                            SoftTextField(title: "Correo", text: $email, keyboard: .emailAddress, textContentType: .emailAddress)
                            SoftTextField(title: "Contraseña", text: $password, isSecure: true, textContentType: .password)

                            if mode == .signup {
                                SoftTextField(title: "Teléfono (opcional)", text: $telefono, keyboard: .numberPad, textContentType: .telephoneNumber)
                            }

                            if let errorText {
                                Text(errorText)
                                    .font(.footnote)
                                    .foregroundStyle(.red.opacity(0.85))
                            }
                            if let successText {
                                Text(successText)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.cocoa)
                            }

                            Button {
                                Task { await submit() }
                            } label: {
                                HStack(spacing: 10) {
                                    if isBusy { ProgressView().tint(.white) }
                                    Text(mode == .login ? "Entrar" : "Crear cuenta")
                                }
                            }
                            .buttonStyle(SoftButtonStyle())
                            .disabled(isBusy || email.isEmpty || password.isEmpty || (mode == .signup && nombre.isEmpty))
                        }
                    }

                    Text("Tip: si no te deja crear perfil en `public.users`, revisa RLS en Supabase. El login funciona igual.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.cocoa.opacity(0.65))

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
        }
    }

    private func submit() async {
        errorText = nil
        successText = nil
        isBusy = true
        defer { isBusy = false }

        do {
            switch mode {
            case .login:
                try await supabase.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                          password: password)
            case .signup:
                try await supabase.signUp(
                    nombre: nombre.trimmingCharacters(in: .whitespacesAndNewlines),
                    correo: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    telefono: telefono.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                // Al crear usuario, regresamos automáticamente a Login.
                mode = .login
                password = ""
                successText = "Cuenta creada. Ahora inicia sesión."
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(SupabaseService.shared)
}

