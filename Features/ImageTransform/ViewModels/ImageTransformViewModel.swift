import Foundation
import AppKit

@MainActor
final class ImageTransformViewModel: ObservableObject {

    static let availableOperations: [String] = [
        ImageOperation.rotate90.rawValue,
        ImageOperation.rotate180.rawValue,
        ImageOperation.rotate270.rawValue,
        ImageOperation.flipHorizontal.rawValue,
        ImageOperation.flipVertical.rawValue,
        ImageOperation.invertColors.rawValue
    ]

    /// String-backed selection rather than binding SwiftUI's Picker
    /// directly to ImageOperation -- ImageOperation is not declared
    /// Hashable, and adding that conformance would mean touching
    /// Features/ImageTransform/Models/ImageTransformConfiguration.swift,
    /// which this chantier deliberately leaves untouched (axe UX only,
    /// not axe calcul). rawValue is String, natively Hashable, no
    /// change to validated files required.
    @Published var selectedOperationRawValue: String = ImageOperation.rotate90.rawValue

    @Published var statusMessage: String?
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var isImporting: Bool = false
    @Published var isExporting: Bool = false
    @Published var hasImportedImage: Bool = false
    @Published var hasTransformedImage: Bool = false

    private let service: ImageTransformServicing
    private let openPanelFactory: () -> OpenPanelProviding
    private let savePanelFactory: () -> SavePanelProviding

    private var importedImage: RawImage?
    private var transformedImage: RawImage?

    private var selectedOperation: ImageOperation {
        ImageOperation(rawValue: selectedOperationRawValue) ?? .rotate90
    }

    /// service resolved via ServiceLocator with a real-instance
    /// fallback -- same pattern as Base64ViewModel/CryptoViewModel.
    /// Panel factories default to the v2-C wrappers (OpenPanelWrapper/
    /// SavePanelWrapper), NOT NSOpenPanel()/NSSavePanel() directly --
    /// the trivial-extension conformance failed to compile in v2-C
    /// (run 1), wrappers are the confirmed-working default since then.
    init(
        service: ImageTransformServicing = ServiceLocator.shared.resolve(ImageTransformServicing.self) ?? ImageTransformService(),
        openPanelFactory: @escaping () -> OpenPanelProviding = { OpenPanelWrapper() },
        savePanelFactory: @escaping () -> SavePanelProviding = { SavePanelWrapper() }
    ) {
        self.service = service
        self.openPanelFactory = openPanelFactory
        self.savePanelFactory = savePanelFactory
    }

    // MARK: - Angle 4: user-visible status, no preview in this increment

    func importImage() {
        isImporting = true
        defer { isImporting = false }
        errorMessage = nil

        var panel = openPanelFactory()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.title = "Importer une image (PNG ou JPEG)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let image = try ImageIOBridge.decodeRawImage(fromFileAt: url)
            importedImage = image
            transformedImage = nil
            hasImportedImage = true
            hasTransformedImage = false
            statusMessage = "Image importée : \(url.lastPathComponent) (\(image.width)×\(image.height))"
        } catch {
            presentError(describeError(error, context: .importing))
        }
    }

    func applyTransformation() {
        errorMessage = nil
        guard let importedImage else {
            presentError("Aucune image importée.")
            return
        }

        do {
            let payloadData = try service.encodeRawImage(importedImage)
            let configuration = ImageTransformConfiguration(operation: selectedOperation)
            let result = try service.transform(.image(payloadData), configuration: configuration)

            guard case .image(let resultData) = result else {
                presentError("Résultat de transformation invalide (payload inattendu).")
                return
            }

            let resultImage = try service.decodeRawImage(from: resultData)
            transformedImage = resultImage
            hasTransformedImage = true
            statusMessage = "Transformation appliquée : \(selectedOperation.displayName)"
        } catch {
            presentError(describeError(error, context: .transforming))
        }
    }

    func exportImage() {
        errorMessage = nil
        guard let transformedImage else {
            presentError("Aucune image transformée à exporter.")
            return
        }

        isExporting = true
        defer { isExporting = false }

        var panel = savePanelFactory()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "image_transformee.png"
        panel.title = "Exporter en PNG"

        guard panel.runModal() == .OK, let rawURL = panel.url else { return }

        // ANGLE 3 (PNG-only, ceinture): SavePanelProviding does not
        // expose allowedContentTypes/allowsOtherFileTypes, so this is
        // the ONLY enforcement point. Whatever extension the user
        // typed or the panel returned, the destination URL is
        // rewritten to .png before any bytes are written -- it is
        // structurally impossible for this method to produce a file
        // named anything other than *.png.
        let pngURL = rawURL.deletingPathExtension().appendingPathExtension("png")

        do {
            let pngData = try ImageIOBridge.encodePNG(transformedImage)
            try pngData.write(to: pngURL, options: .atomic)
            statusMessage = "Export réussi vers : \(pngURL.path)"
        } catch {
            presentError(describeError(error, context: .exporting))
        }
    }

    // MARK: - Angle 2: readable error messages, no silent failure

    private enum ErrorContext {
        case importing, transforming, exporting
    }

    private func describeError(_ error: Error, context: ErrorContext) -> String {
        let prefix: String
        switch context {
        case .importing: prefix = "Import impossible"
        case .transforming: prefix = "Transformation impossible"
        case .exporting: prefix = "Export impossible"
        }

        if let bridgeError = error as? ImageIOBridgeError {
            switch bridgeError {
            case .decodingFailed:
                return "\(prefix) : le fichier n'a pas pu être décodé (format non reconnu ou fichier corrompu)."
            case .unsupportedPixelFormat:
                return "\(prefix) : format de pixels non pris en charge."
            case .unsupportedAlphaLayout:
                return "\(prefix) : disposition du canal alpha non prise en charge."
            case .jpegOutputNotSupported:
                return "\(prefix) : l'export JPEG n'est pas pris en charge (PNG uniquement)."
            case .pngEncodingFailed:
                return "\(prefix) : échec de l'encodage PNG."
            case .cgImageCreationFailed:
                return "\(prefix) : impossible de créer l'image en mémoire."
            }
        }
        if let transformError = error as? ImageTransformError {
            switch transformError {
            case .invalidPayloadType:
                return "\(prefix) : type de contenu invalide pour cette opération."
            }
        }
        return "\(prefix) : \(error.localizedDescription)"
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showError = true
        statusMessage = nil
    }
}

// MARK: - Angle 1: display labels (presentation-only, kept out of Models)

extension ImageOperation {
    var displayName: String {
        switch self {
        case .rotate90: return "Rotation 90°"
        case .rotate180: return "Rotation 180°"
        case .rotate270: return "Rotation 270°"
        case .flipHorizontal: return "Miroir horizontal"
        case .flipVertical: return "Miroir vertical"
        case .invertColors: return "Inversion des couleurs"
        }
    }
}
