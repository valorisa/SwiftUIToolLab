import Foundation

/// The Configuration type LinearEncoderServicing fixes
/// ConfigurableTransformer's associatedtype to. Deliberately a
/// separate struct from LinearOperator's MatrixAnalysisConfiguration
/// — the two carry different reasons to change (one just wraps a
/// matrix to analyze, this one wraps a matrix plus the exact-integer
/// view the mod-256 encode/decode pipeline needs).
struct LinearEncoderConfiguration: Codable, Equatable {
    /// Reuses LinearOperator's validated Matrix type by direct
    /// reference — see LinearEncoderServicing.swift's doc comment for
    /// why this is a documented exception to "each feature only
    /// communicates through Core/Protocols/", not a silent violation
    /// of it.
    let matrix: Matrix

    /// Exact integer view of matrix.values, validated once here.
    /// Matrix stores Double (for compatibility with
    /// LinearOperatorService's Gaussian-elimination-based analysis),
    /// but the adjugate/mod-256 pipeline needs exact integers — every
    /// later encode/decode call trusts this was already checked,
    /// instead of re-validating per call.
    let integerMatrix: [[Int]]

    enum ConfigurationError: Error, Equatable {
        case nonIntegerMatrixValues
        case matrixNotSquare
    }

    init(matrix: Matrix) throws {
        guard matrix.isSquare else {
            throw ConfigurationError.matrixNotSquare
        }
        var converted: [[Int]] = []
        for row in matrix.values {
            var intRow: [Int] = []
            for value in row {
                guard let intValue = Int(exactly: value) else {
                    throw ConfigurationError.nonIntegerMatrixValues
                }
                intRow.append(intValue)
            }
            converted.append(intRow)
        }
        self.matrix = matrix
        self.integerMatrix = converted
    }
}

// MARK: - Codable (manual, re-derives integerMatrix on decode)

extension LinearEncoderConfiguration {
    private enum CodingKeys: String, CodingKey {
        case matrix
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedMatrix = try container.decode(Matrix.self, forKey: .matrix)
        try self.init(matrix: decodedMatrix)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matrix, forKey: .matrix)
    }
}
