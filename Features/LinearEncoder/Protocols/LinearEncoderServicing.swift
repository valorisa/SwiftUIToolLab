import Foundation

/// EXCEPTION DOCUMENTÉE À "chaque feature ne communique qu'à travers
/// Core/Protocols/" : ce fichier référence directement Matrix,
/// défini dans Features/LinearOperator/Models/Matrix.swift — le
/// premier cas du repo où une feature dépend directement d'un type
/// d'une autre feature (jusqu'ici, Base64/Crypto/FileImportExport ne
/// se référençaient jamais entre elles ; seul App/ composait
/// plusieurs features). Exception motivée : Matrix est un type de
/// données pur, validé, sans dépendance à un service ou un
/// ViewModel — pas un couplage de logique métier entre features.
///
/// Fixes ConfigurableTransformer's associated Configuration type to
/// LinearEncoderConfiguration via a same-type constraint (SE-0309),
/// coexisting with LinearOperatorServicing's own constraint to
/// MatrixAnalysisConfiguration on the SAME parent protocol, in the
/// SAME compilation unit. This is the first exercise of the
/// polymorphic case left open since v2-E (single-conformance case
/// only, confirmed there). Whether two different same-type
/// constraints on one parent protocol compile together is confirmed
/// only once this file's CI run succeeds — not before.
protocol LinearEncoderServicing: ConfigurableTransformer where Configuration == LinearEncoderConfiguration {
    /// Builds a deterministic unimodular matrix (det = ±1) of the
    /// given size, from a seed and a number of elementary row
    /// operations — always valid by construction, never by rejection
    /// sampling.
    func generateConfiguration(size: Int, seed: UInt64, operationCount: Int) throws -> LinearEncoderConfiguration

    /// Encodes text into bytes: UTF-8 -> length-prefixed -> padded to
    /// a multiple of the matrix's block size -> M·x mod 256 per block.
    func encode(_ text: String, configuration: LinearEncoderConfiguration) throws -> Data

    /// Reverses encode(_:configuration:) via M⁻¹ mod 256 per block
    /// (computed from the adjugate, never from a truncated real
    /// inverse), then strips the length-prefix padding.
    func decode(_ data: Data, configuration: LinearEncoderConfiguration) throws -> String
}

enum LinearEncoderError: Error, Equatable {
    case invalidPayloadType
    case invalidBlockAlignment
    case corruptedLengthPrefix
    case invalidUTF8
    case messageTooLarge
    case matrixNotUnimodular
}
