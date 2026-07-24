import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var selectedFeature: FeatureIdentifier = .base64

    /// Fired when RootView detects the user has left a tab that may
    /// hold sensitive data (currently: Crypto). Subscribers (e.g.
    /// CryptoViewModel) react by purging their own in-memory state.
    /// A signal rather than a direct method call so RootView doesn't
    /// need a reference to feature ViewModels it doesn't own — see
    /// Question 4 in the v2-B-bis brief.
    let purgeSensitiveDataSignal = PassthroughSubject<Void, Never>()
}

enum FeatureIdentifier: String, CaseIterable, Identifiable {
    case base64
    case crypto
    case fileImportExport
    case settings

    var id: String { rawValue }
}
