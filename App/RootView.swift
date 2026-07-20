import SwiftUI

/// Composition root's UI. Only App/ is allowed to import multiple features —
/// individual features never depend on each other directly.
struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedFeature) {
            Base64View()
                .tabItem { Label("Base64", systemImage: "arrow.left.arrow.right") }
                .tag(FeatureIdentifier.base64)

            CryptoView()
                .tabItem { Label("Crypto", systemImage: "lock") }
                .tag(FeatureIdentifier.crypto)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(Workspace())
}
