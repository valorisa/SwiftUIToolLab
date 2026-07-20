import Foundation

@MainActor
final class CryptoViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var password: String = ""
    @Published var outputText: String = ""
    @Published var errorMessage: String?

    private let service: CryptoServicing

    init(service: CryptoServicing = ServiceLocator.shared.resolve(CryptoServicing.self) ?? CryptoService()) {
        self.service = service
    }

    func encrypt() {
        errorMessage = nil
        do {
            outputText = try service.encrypt(inputText, password: password)
        } catch CryptoError.invalidPassword {
            errorMessage = "Mot de passe requis."
            outputText = ""
        } catch CryptoError.invalidInput {
            errorMessage = "Le texte à chiffrer est vide."
            outputText = ""
        } catch {
            errorMessage = "Erreur de chiffrement."
            outputText = ""
        }
    }

    func decrypt() {
        errorMessage = nil
        do {
            outputText = try service.decrypt(inputText, password: password)
        } catch CryptoError.invalidPassword {
            errorMessage = "Mot de passe incorrect."
            outputText = ""
        } catch CryptoError.corruptedData {
            errorMessage = "Données chiffrées invalides ou corrompues."
            outputText = ""
        } catch {
            errorMessage = "Erreur de déchiffrement."
            outputText = ""
        }
    }
}
