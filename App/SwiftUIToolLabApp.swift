import SwiftUI

@main
struct SwiftUIToolLabApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var workspace = Workspace()

    init() {
        ServiceLocator.shared.register(Base64Servicing.self, instance: Base64Service())
    }

    var body: some Scene {
        WindowGroup {
            Base64View()
                .environmentObject(appState)
                .environmentObject(workspace)
        }
    }
}
