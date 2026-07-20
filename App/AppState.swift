import Foundation

final class AppState: ObservableObject {
    @Published var selectedFeature: FeatureIdentifier = .base64
}

enum FeatureIdentifier: String, CaseIterable, Identifiable {
    case base64
    case crypto
    case fileImportExport
    case settings

    var id: String { rawValue }
}
