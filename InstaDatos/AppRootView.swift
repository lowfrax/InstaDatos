import SwiftUI

struct AppRootView: View {
    @StateObject private var supabase = SupabaseService.shared

    var body: some View {
        Group {
            if supabase.isSignedIn {
                MainView()
                    .environmentObject(supabase)
            } else {
                AuthView()
                    .environmentObject(supabase)
            }
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(.light)
    }
}

#Preview {
    AppRootView()
}

