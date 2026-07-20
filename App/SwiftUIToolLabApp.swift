import SwiftUI

@main
struct SwiftUIToolLabApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var workspace = Workspace()

    init() {
        ServiceLocator.shared.register(Base64Servicing.self, instance: Base64Service())
        ServiceLocator.shared.register(CryptoServicing.self, instance: CryptoService())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(workspace)
        }
    }
}
