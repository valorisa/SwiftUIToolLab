import Foundation

@MainActor
final class Base64ViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var outputText: String = ""
    @Published var errorMessage: String?

    private let service: Base64Servicing

    init(service: Base64Servicing = ServiceLocator.shared.resolve(Base64Servicing.self) ?? Base64Service()) {
        self.service = service
    }

    func encode() {
        errorMessage = nil
        outputText = service.encode(inputText)
    }

    func decode() {
        errorMessage = nil
        do {
            outputText = try service.decode(inputText)
        } catch {
            errorMessage = "Entrée Base64 invalide."
            outputText = ""
        }
    }
}
