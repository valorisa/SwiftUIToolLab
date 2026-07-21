import SwiftUI

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
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(Workspace())
}
