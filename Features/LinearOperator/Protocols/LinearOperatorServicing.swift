import Foundation

/// Fixes ConfigurableTransformer's associated Configuration type to
/// MatrixAnalysisConfiguration via a same-type constraint (SE-0309,
/// available since Swift 5.7 — this repo targets 5.9). This is what
/// should let LinearOperatorServicing be used as a type (e.g.
/// `LinearOperatorServicing.self` passed to ServiceLocator) the same
/// way Base64Servicing/CryptoServicing/FileImportExportServicing
/// already are — without touching
/// Core/Protocols/ConfigurableTransformer.swift.
///
/// UNVERIFIED (open question, not resolved by v2-E): no ViewModel in
/// this repo registers or resolves LinearOperatorServicing via
/// ServiceLocator — v2-E deliberately ships no UI (Option Y). Whether
/// `ServiceLocator.register(LinearOperatorServicing.self, instance:)`
/// actually compiles is therefore untested by this phase's CI run.
/// Left open for whichever future phase (v2-E-bis) adds a ViewModel —
/// do not assume it works without that phase's own CI confirming it.
protocol LinearOperatorServicing: ConfigurableTransformer where Configuration == MatrixAnalysisConfiguration {
    /// Parses a grid of whitespace-separated integers (one row per
    /// line) into an ASCII code grid, then validates it into a Matrix.
    func parseASCIIGrid(from text: String) throws -> [[Int]]

    /// Validates a raw ASCII grid into a Matrix.
    func loadMatrix(fromASCIIGrid grid: [[Int]]) throws -> Matrix

    /// Computes rank, invertibility, and condition number for a given
    /// matrix. Pure computation — measures, does not assert.
    func analyze(_ matrix: Matrix) -> MatrixAnalysis
}

enum LinearOperatorError: Error, Equatable {
    case invalidVectorFormat
    case dimensionMismatch(expected: Int, actual: Int)
    case matrixNotInvertible
    case matrixNotSquare
}

enum FixtureParsingError: Error, Equatable {
    case emptyContent
    case invalidInteger(line: Int, token: String)
    case irregularRowLength
}
