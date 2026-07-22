import SwiftUI

@main
struct SwiftUIToolLabApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var workspace: Workspace

    init() {
        let sharedWorkspace = Workspace()
        _workspace = StateObject(wrappedValue: sharedWorkspace)

        ServiceLocator.shared.register(Base64Servicing.self, instance: Base64Service())
        ServiceLocator.shared.register(CryptoServicing.self, instance: CryptoService())
        ServiceLocator.shared.register(FileImportExportServicing.self, instance: FileImportExportService())
        // Registered so every ViewModel's default-parameter resolution
        // (ServiceLocator.shared.resolve(Workspace.self)) returns this
        // exact instance — the same one exposed via .environmentObject
        // below, not an orphaned Workspace() per feature.
        ServiceLocator.shared.register(Workspace.self, instance: sharedWorkspace)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(workspace)
        }
    }
}
