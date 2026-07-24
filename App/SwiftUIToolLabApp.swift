import SwiftUI

@main
struct SwiftUIToolLabApp: App {
    @StateObject private var appState: AppState
    @StateObject private var workspace: Workspace

    init() {
        let sharedAppState = AppState()
        let sharedWorkspace = Workspace()
        _appState = StateObject(wrappedValue: sharedAppState)
        _workspace = StateObject(wrappedValue: sharedWorkspace)

        ServiceLocator.shared.register(Base64Servicing.self, instance: Base64Service())
        ServiceLocator.shared.register(CryptoServicing.self, instance: CryptoService())
        ServiceLocator.shared.register(FileImportExportServicing.self, instance: FileImportExportService())
        ServiceLocator.shared.register(Workspace.self, instance: sharedWorkspace)
        // Registered so CryptoViewModel's default-parameter resolution
        // can subscribe to the same AppState instance RootView observes
        // and sends purgeSensitiveDataSignal through (v2-B-bis).
        ServiceLocator.shared.register(AppState.self, instance: sharedAppState)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(workspace)
        }
    }
}
