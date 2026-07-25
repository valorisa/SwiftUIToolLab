import Foundation

// MARK: - Matrix

/// A validated rectangular matrix of Double values. Never a bare
/// `[[Int]]`/`[[Double]]` typealias — a decoded grid whose rows have
/// inconsistent lengths must fail to construct, not silently produce
/// an inconsistent Matrix.
struct Matrix: Equatable {
    let values: [[Double]]
    let rowCount: Int
    let columnCount: Int

    enum MatrixError: Error, Equatable {
        case empty
        case irregularShape
    }

    init(values: [[Double]]) throws {
        guard let firstRow = values.first, !firstRow.isEmpty else {
            throw MatrixError.empty
        }
        let width = firstRow.count
        guard values.allSatisfy({ $0.count == width }) else {
            throw MatrixError.irregularShape
        }
        self.values = values
        self.rowCount = values.count
        self.columnCount = width
    }

    /// Convenience initializer for a grid of ASCII codes (e.g. read
    /// from a text fixture), converted to Double for the Gaussian
    /// elimination pipeline.
    init(asciiGrid: [[Int]]) throws {
        try self.init(values: asciiGrid.map { row in row.map(Double.init) })
    }

    var isSquare: Bool { rowCount == columnCount }
}

// MARK: - Codable (manual, revalidates on decode)

extension Matrix: Codable {
    private enum CodingKeys: String, CodingKey {
        case values
    }

    /// Deliberately NOT the compiler-synthesized Codable conformance.
    /// A synthesized init(from:) would decode `values`/`rowCount`/
    /// `columnCount` independently and trust them blindly — a
    /// hand-edited or tampered .clab payload could produce a Matrix
    /// whose rowCount/columnCount don't match its actual shape. This
    /// custom init re-runs the same rectangularity check as
    /// init(values:) on every decode.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedValues = try container.decode([[Double]].self, forKey: .values)
        try self.init(values: decodedValues)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(values, forKey: .values)
    }
}

// MARK: - MatrixSize

struct MatrixSize: Equatable {
    let rows: Int
    let columns: Int
}

// MARK: - MatrixAnalysis

/// Result of measuring a matrix. Every field here is COMPUTED, never
/// asserted from the matrix's origin story — a matrix built from a
/// repeating pattern is expected to be rank-deficient, but this type
/// reports whatever Gaussian elimination actually finds, including a
/// surprising result.
struct MatrixAnalysis: Equatable {
    let size: MatrixSize
    let rank: Int
    let isInvertible: Bool
    /// Frobenius-norm approximation of the condition number, not the
    /// spectral norm — sufficient for this demonstrator. The true
    /// spectral condition number (σ_max / σ_min) would require an
    /// eigenvalue solver, out of scope for this first pass. .infinity
    /// when the matrix isn't invertible.
    let conditionNumber: Double
}

// MARK: - MatrixAnalysisConfiguration

/// The Configuration type ConfigurableTransformer requires for the
/// LinearOperator feature. Fixed via a same-type constraint in
/// LinearOperatorServicing.swift, not by modifying
/// Core/Protocols/ConfigurableTransformer.swift.
struct MatrixAnalysisConfiguration: Codable, Equatable {
    let matrix: Matrix
}
