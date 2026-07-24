import SwiftUI

/// Composition root. Only App/ imports multiple features.
///
/// v2-B-bis: also owns the tab-change → sensitive-data-purge signal.
/// This is a deliberate, documented widening of RootView's role beyond
/// pure TabView composition — it now carries a small piece of
/// navigation-driven security plumbing (still not business logic: it
/// only relays "the user left the Crypto tab", it doesn't decide what
/// counts as sensitive or how the purge happens).
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

            FileImportExportView()
                .tabItem { Label("Files", systemImage: "folder") }
                .tag(FeatureIdentifier.fileImportExport)
        }
        // Only fires when selectedFeature actually changes, never at
        // RootView's own initialization — no startup purge. Checks
        // oldValue, not newValue: purge only when LEAVING Crypto, not
        // when arriving on it (arriving would wipe text the user just
        // pasted before they could use it).
        .onChange(of: appState.selectedFeature) { oldValue, _ in
            if oldValue == .crypto {
                appState.purgeSensitiveDataSignal.send()
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(Workspace())
}
