import SwiftUI

// MARK: - TODO
// App entry point. Wires AppState and Workspace as EnvironmentObjects
// and declares the root Scene (WindowGroup / NavigationSplitView).

@main
struct SwiftUIToolLabApp: App {
    // MARK: - TODO: instantiate AppState() and Workspace() here

    var body: some Scene {
        WindowGroup {
            // MARK: - TODO: root ContentView, injected with .environmentObject(...)
            EmptyView()
        }
    }
}
