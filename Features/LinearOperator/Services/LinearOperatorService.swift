import Foundation

// MARK: - Origin story (Chantier 6 — mandatory in-code narrative)

/// # Where this feature comes from
///
/// SwiftUIToolLab began with a laser-printer test sheet: a grid of
/// characters (see the IMG_* photo kept in the repo, D-v2-5). The
/// project's original intuition (Bertrand) was that this grid could
/// work as a conversion tool if read as a square matrix — even, in the
/// loosest sense, as a "Jacobian": the matrix of a function's partial
/// derivatives.
///
/// That intuition is mathematically real in one narrow, correct sense:
/// for a LINEAR function f(x) = M·x, the Jacobian of f at any point is
/// M itself (the partial derivatives of a linear map are constant,
/// equal to its coefficients). But "Jacobian" ordinarily evokes a
/// matrix that VARIES with the point of evaluation — the local
/// linearization of a non-linear system. That richer meaning doesn't
/// apply here. To avoid implying more than this code delivers, the
/// word "Jacobian" is kept OUT of every symbol in this feature (types,
/// protocols, methods) and reserved for this narrative comment alone.
/// What the code below actually implements is a plain linear operator:
/// a matrix M and the map x ↦ M·x.
///
/// This feature (v2-E, "🅰️") does NOT attempt to turn the sheet into a
/// working encoder. It MEASURES a matrix's rank and condition number
/// and reports the numbers honestly — including if they show a given
/// matrix cannot function as a reversible code. A repeating,
/// unstructured grid is expected to be rank-deficient; even an
/// invertible matrix read from a real photograph would still need to
/// be well-conditioned to survive the noise of a pliure, du papier
/// froissé, or de l'encre qui bave. Building an operator that actually
/// encodes reversibly — by deliberately constructing a matrix with the
/// right properties (unimodular determinant so the inverse stays
/// integer-valued, explicit handling of products falling outside
/// 0-255) — is a separate, harder problem, tracked as 🅱️ / v2-F,
/// motivated by whatever numbers this feature reports, not solved
/// here.
enum LinearOperatorOrigin {}

// MARK: - LinearOperatorService

final class LinearOperatorService: LinearOperatorServicing {

    /// A pivot below this magnitude is treated as zero. NOT a
    /// universal numerical-analysis constant — a deliberate choice for
    /// this demonstrator, appropriate for exact-integer ASCII inputs
    /// with no measurement noise (unlike values that would come from
    /// actually reading the photographed sheet, which would need a
    /// much looser, empirically-tuned tolerance).
    private static let pivotTolerance = 1e-9

    // MARK: - Fixture parsing

    func parseASCIIGrid(from text: String) throws -> [[Int]] {
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { throw FixtureParsingError.emptyContent }

        var grid: [[Int]] = []
        for (index, line) in lines.enumerated() {
            let tokens = line.split(separator: " ").map(String.init)
            var row: [Int] = []
            for token in tokens {
                guard let value = Int(token) else {
                    throw FixtureParsingError.invalidInteger(line: index, token: token)
                }
                row.append(value)
            }
            grid.append(row)
        }

        let width = grid[0].count
        guard grid.allSatisfy({ $0.count == width }) else {
            throw FixtureParsingError.irregularRowLength
        }

        return grid
    }

    func loadMatrix(fromASCIIGrid grid: [[Int]]) throws -> Matrix {
        try Matrix(asciiGrid: grid)
    }

    // MARK: - Analysis

    func analyze(_ matrix: Matrix) -> MatrixAnalysis {
        let rank = Self.rank(of: matrix.values)
        let isInvertible = matrix.isSquare && rank == matrix.rowCount

        let conditionNumber: Double
        if isInvertible, let inverseValues = try? Self.invert(matrix.values) {
            conditionNumber = Self.frobeniusNorm(matrix.values) * Self.frobeniusNorm(inverseValues)
        } else {
            conditionNumber = .infinity
        }

        return MatrixAnalysis(
            size: MatrixSize(rows: matrix.rowCount, columns: matrix.columnCount),
            rank: rank,
            isInvertible: isInvertible,
            conditionNumber: conditionNumber
        )
    }

    // MARK: - ConfigurableTransformer

    /// Applies M·x to a vector encoded as comma-separated numbers in a
    /// .text Payload (e.g. "1,2,3"), returning the result the same way.
    func transform(_ input: Payload, configuration: MatrixAnalysisConfiguration) throws -> Payload {
        let vector = try Self.parseVector(from: input)
        let matrix = configuration.matrix
        guard vector.count == matrix.columnCount else {
            throw LinearOperatorError.dimensionMismatch(expected: matrix.columnCount, actual: vector.count)
        }
        let result = Self.multiply(matrix.values, vector)
        return .text(Self.formatVector(result))
    }

    /// Applies M⁻¹·y. Throws matrixNotInvertible if the configured
    /// matrix isn't invertible — expected, correct behavior for a
    /// rank-deficient matrix, not a bug.
    func inverse(_ input: Payload, configuration: MatrixAnalysisConfiguration) throws -> Payload {
        let vector = try Self.parseVector(from: input)
        let matrix = configuration.matrix
        guard matrix.isSquare else {
            throw LinearOperatorError.matrixNotSquare
        }
        guard vector.count == matrix.rowCount else {
            throw LinearOperatorError.dimensionMismatch(expected: matrix.rowCount, actual: vector.count)
        }
        guard let inverseValues = try? Self.invert(matrix.values) else {
            throw LinearOperatorError.matrixNotInvertible
        }
        let result = Self.multiply(inverseValues, vector)
        return .text(Self.formatVector(result))
    }

    // MARK: - Vector <-> Payload

    private static func parseVector(from payload: Payload) throws -> [Double] {
        guard case .text(let string) = payload else {
            throw LinearOperatorError.invalidVectorFormat
        }
        let components = string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let values = components.compactMap(Double.init)
        guard !values.isEmpty, values.count == components.count else {
            throw LinearOperatorError.invalidVectorFormat
        }
        return values
    }

    private static func formatVector(_ vector: [Double]) -> String {
        vector.map { String($0) }.joined(separator: ",")
    }

    // MARK: - Linear algebra (Gaussian elimination, partial pivoting)

    /// Computes matrix rank via Gaussian elimination with partial
    /// pivoting. Foundation only, no Accelerate/LAPACK dependency —
    /// appropriate for matrices at the scale of a printed test sheet
    /// (well under 30x30), not a general-purpose numerical library.
    static func rank(of values: [[Double]]) -> Int {
        var matrix = values
        let rowCount = matrix.count
        guard rowCount > 0 else { return 0 }
        let columnCount = matrix[0].count

        var rank = 0
        var pivotRow = 0

        for column in 0..<columnCount where pivotRow < rowCount {
            var maxRow = pivotRow
            var maxValue = abs(matrix[pivotRow][column])
            for row in (pivotRow + 1)..<rowCount where abs(matrix[row][column]) > maxValue {
                maxValue = abs(matrix[row][column])
                maxRow = row
            }

            guard maxValue > pivotTolerance else { continue }

            matrix.swapAt(pivotRow, maxRow)

            for row in (pivotRow + 1)..<rowCount {
                let factor = matrix[row][column] / matrix[pivotRow][column]
                for col in column..<columnCount {
                    matrix[row][col] -= factor * matrix[pivotRow][col]
                }
            }

            pivotRow += 1
            rank += 1
        }

        return rank
    }

    /// Gauss-Jordan matrix inversion. Throws matrixNotSquare if `n` by
    /// `n` doesn't hold, or matrixNotInvertible if a pivot falls below
    /// pivotTolerance during elimination.
    static func invert(_ values: [[Double]]) throws -> [[Double]] {
        let n = values.count
        guard n > 0, values.allSatisfy({ $0.count == n }) else {
            throw LinearOperatorError.matrixNotSquare
        }

        var augmented: [[Double]] = values.enumerated().map { index, row in
            var identityRow = [Double](repeating: 0, count: n)
            identityRow[index] = 1
            return row + identityRow
        }

        for column in 0..<n {
            var maxRow = column
            var maxValue = abs(augmented[column][column])
            for row in (column + 1)..<n where abs(augmented[row][column]) > maxValue {
                maxValue = abs(augmented[row][column])
                maxRow = row
            }

            guard maxValue > pivotTolerance else {
                throw LinearOperatorError.matrixNotInvertible
            }

            augmented.swapAt(column, maxRow)

            let pivot = augmented[column][column]
            for col in 0..<(2 * n) {
                augmented[column][col] /= pivot
            }

            for row in 0..<n where row != column {
                let factor = augmented[row][column]
                guard factor != 0 else { continue }
                for col in 0..<(2 * n) {
                    augmented[row][col] -= factor * augmented[column][col]
                }
            }
        }

        return augmented.map { Array($0[n...]) }
    }

    /// ‖M‖_F = √(Σ mᵢⱼ²) — see MatrixAnalysis.conditionNumber doc
    /// comment for why Frobenius rather than spectral norm.
    static func frobeniusNorm(_ values: [[Double]]) -> Double {
        sqrt(values.reduce(0) { rowSum, row in
            rowSum + row.reduce(0) { $0 + $1 * $1 }
        })
    }

    private static func multiply(_ matrix: [[Double]], _ vector: [Double]) -> [Double] {
        matrix.map { row in
            zip(row, vector).reduce(0) { $0 + $1.0 * $1.1 }
        }
    }
}
