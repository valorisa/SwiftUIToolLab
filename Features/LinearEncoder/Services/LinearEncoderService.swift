import Foundation

// MARK: - Origin story, continued (Chantier 8)

/// # Where this continues the story
///
/// LinearOperatorOrigin (see Features/LinearOperator/Services/
/// LinearOperatorService.swift) told the first half: the project's
/// spark was a laser-printer test sheet, read as a candidate matrix —
/// and in the loosest sense, a "Jacobian" (a linear map's Jacobian
/// equals the map's own matrix, at any point). That first feature
/// (🅰️, v2-E) MEASURED the sheet's actual matrix and found it
/// rank-deficient: honest, but a dead end for "the sheet codes".
///
/// This feature (🅱️, v2-F) is where the idea finally finds ground
/// that codes. Instead of reading a matrix from the sheet, it
/// CONSTRUCTS one deterministically — a product of elementary
/// integer row operations guaranteed to have determinant ±1
/// (unimodular), so its inverse stays exactly integer-valued, no
/// division, no rounding. Encoding a message is x ↦ M·x mod 256 per
/// block of bytes; decoding is the same operation with M⁻¹, obtained
/// from M's adjugate — never from a truncated real-valued inverse.
/// "Jacobian" still names none of the symbols below (kept out of the
/// code deliberately, as in LinearOperator) — but this is the file
/// where the sheet's original intuition becomes an actual,
/// roundtrip-tested conversion tool.
enum LinearEncoderOrigin {}

// MARK: - Deterministic seeded generator (no external dependency)

/// SplitMix64-based generator. Fully deterministic given a seed —
/// used to choose WHICH elementary operations to apply, not to
/// gamble on hitting determinant ±1 by chance (that would be the
/// rejected Approach B). The composition of unimodular elementary
/// matrices is unimodular by construction, regardless of which
/// specific operations this generator happens to pick.
private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func nextUInt64() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func next(upperBound: Int) -> Int {
        Int(nextUInt64() % UInt64(upperBound))
    }
}

// MARK: - LinearEncoderService

final class LinearEncoderService: LinearEncoderServicing {

    // MARK: - Chantier 2: deterministic unimodular construction

    private static let kOptions = [-2, -1, 1, 2]

    func generateConfiguration(size: Int, seed: UInt64, operationCount: Int) throws -> LinearEncoderConfiguration {
        let integerValues = Self.generateUnimodularMatrix(size: size, seed: seed, operationCount: operationCount)
        let doubleValues = integerValues.map { $0.map(Double.init) }
        let matrix = try Matrix(values: doubleValues)
        return try LinearEncoderConfiguration(matrix: matrix)
    }

    /// Starts from the identity and applies `operationCount`
    /// elementary integer row operations (add an integer multiple of
    /// one row to another, swap two rows, negate a row) — each one
    /// individually preserves |det| = 1, so their product is
    /// guaranteed unimodular regardless of how many are applied or in
    /// which order. Deterministic given `seed`: no flakiness, no
    /// rejection loop.
    static func generateUnimodularMatrix(size: Int, seed: UInt64, operationCount: Int) -> [[Int]] {
        var matrix = identityMatrix(size: size)
        var rng = SeededGenerator(seed: seed)

        for _ in 0..<operationCount {
            switch rng.next(upperBound: 3) {
            case 0:
                let i = rng.next(upperBound: size)
                var j = rng.next(upperBound: size)
                while j == i { j = rng.next(upperBound: size) }
                let k = kOptions[rng.next(upperBound: kOptions.count)]
                for col in 0..<size {
                    matrix[j][col] += k * matrix[i][col]
                }
            case 1:
                let i = rng.next(upperBound: size)
                var j = rng.next(upperBound: size)
                while j == i { j = rng.next(upperBound: size) }
                matrix.swapAt(i, j)
            default:
                let i = rng.next(upperBound: size)
                for col in 0..<size {
                    matrix[i][col] = -matrix[i][col]
                }
            }
        }

        return matrix
    }

    private static func identityMatrix(size: Int) -> [[Int]] {
        (0..<size).map { row in (0..<size).map { col in row == col ? 1 : 0 } }
    }

    // MARK: - Chantier 3: determinant, adjugate, mod-256 inversion

    /// Recursive cofactor-expansion determinant. O(n!) naive
    /// complexity — acceptable for the block sizes this feature
    /// targets (4-16), not intended for n approaching 20+.
    static func determinant(of matrix: [[Int]]) -> Int {
        let n = matrix.count
        if n == 1 { return matrix[0][0] }
        if n == 2 { return matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0] }

        var result = 0
        for col in 0..<n {
            let minor = minorMatrix(matrix, excludingRow: 0, excludingColumn: col)
            let sign = col % 2 == 0 ? 1 : -1
            result += sign * matrix[0][col] * determinant(of: minor)
        }
        return result
    }

    private static func minorMatrix(_ matrix: [[Int]], excludingRow: Int, excludingColumn: Int) -> [[Int]] {
        matrix.enumerated().compactMap { rowIndex, row -> [Int]? in
            guard rowIndex != excludingRow else { return nil }
            return row.enumerated().compactMap { colIndex, value in
                colIndex == excludingColumn ? nil : value
            }
        }
    }

    private static func cofactorMatrix(of matrix: [[Int]]) -> [[Int]] {
        let n = matrix.count
        var result = Array(repeating: Array(repeating: 0, count: n), count: n)
        for row in 0..<n {
            for col in 0..<n {
                let minor = minorMatrix(matrix, excludingRow: row, excludingColumn: col)
                let sign = (row + col) % 2 == 0 ? 1 : -1
                result[row][col] = sign * determinant(of: minor)
            }
        }
        return result
    }

    /// adj(M) — the transpose of the cofactor matrix. Built entirely
    /// from sums and products of integers (sub-determinants), no
    /// division anywhere, so the result is exactly integer-valued.
    private static func adjugate(of matrix: [[Int]]) -> [[Int]] {
        let cofactors = cofactorMatrix(of: matrix)
        let n = matrix.count
        var result = Array(repeating: Array(repeating: 0, count: n), count: n)
        for row in 0..<n {
            for col in 0..<n {
                result[col][row] = cofactors[row][col]
            }
        }
        return result
    }

    /// M⁻¹ mod 256, computed as (det(M) · adj(M)) mod 256 — since
    /// det(M) = ±1 for a unimodular matrix, M⁻¹ = adj(M)/det(M)
    /// reduces to ±adj(M), never requiring a division. This is
    /// deliberately NOT "compute the real inverse then truncate" —
    /// that would be mathematically wrong; reducing the exact integer
    /// adjugate mod 256 is exact, because modular reduction commutes
    /// with the integer sums/products that built the adjugate.
    static func inverseMod256(of matrix: [[Int]]) throws -> [[Int]] {
        let det = determinant(of: matrix)
        guard det == 1 || det == -1 else {
            throw LinearEncoderError.matrixNotUnimodular
        }
        let adj = adjugate(of: matrix)
        return adj.map { row in row.map { positiveMod($0 * det, 256) } }
    }

    static func positiveMod(_ value: Int, _ modulus: Int) -> Int {
        let result = value % modulus
        return result >= 0 ? result : result + modulus
    }

    static func multiplyMod256(_ matrix: [[Int]], _ vector: [Int]) -> [Int] {
        matrix.map { row in
            let sum = zip(row, vector).reduce(0) { $0 + $1.0 * $1.1 }
            return positiveMod(sum, 256)
        }
    }

    // MARK: - Chantier 4: text <-> blocks pipeline

    /// 4-byte big-endian length prefix — a documented, simple choice
    /// (not PKCS#7): the prefix records the exact plaintext length
    /// once, up front, so decode can strip padding by slicing to a
    /// known length rather than parsing a padding scheme, and no
    /// special case is needed when the padded length is already an
    /// exact multiple of the block size (PKCS#7's classic pitfall).
    private static func bigEndianBytes(of value: UInt32) -> [Int] {
        [
            Int((value >> 24) & 0xFF),
            Int((value >> 16) & 0xFF),
            Int((value >> 8) & 0xFF),
            Int(value & 0xFF)
        ]
    }

    private static func length(fromBigEndianBytes bytes: [Int]) -> Int {
        (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]
    }

    func encode(_ text: String, configuration: LinearEncoderConfiguration) throws -> Data {
        let matrix = configuration.integerMatrix
        let n = matrix.count
        guard n > 0 else { throw LinearEncoderError.matrixNotUnimodular }

        let messageBytes = Array(text.utf8)
        guard messageBytes.count <= Int(UInt32.max) else {
            throw LinearEncoderError.messageTooLarge
        }

        var plaintextInts = Self.bigEndianBytes(of: UInt32(messageBytes.count))
        plaintextInts.append(contentsOf: messageBytes.map(Int.init))

        let remainder = plaintextInts.count % n
        if remainder != 0 {
            plaintextInts.append(contentsOf: Array(repeating: 0, count: n - remainder))
        }

        var outputBytes: [UInt8] = []
        outputBytes.reserveCapacity(plaintextInts.count)
        for blockStart in stride(from: 0, to: plaintextInts.count, by: n) {
            let block = Array(plaintextInts[blockStart..<(blockStart + n)])
            let encodedBlock = Self.multiplyMod256(matrix, block)
            outputBytes.append(contentsOf: encodedBlock.map { UInt8($0) })
        }

        return Data(outputBytes)
    }

    func decode(_ data: Data, configuration: LinearEncoderConfiguration) throws -> String {
        let matrix = configuration.integerMatrix
        let n = matrix.count
        guard n > 0, !data.isEmpty, data.count % n == 0 else {
            throw LinearEncoderError.invalidBlockAlignment
        }

        let inverseMatrix = try Self.inverseMod256(of: matrix)
        let bytes = Array(data)

        var decodedInts: [Int] = []
        decodedInts.reserveCapacity(bytes.count)
        for blockStart in stride(from: 0, to: bytes.count, by: n) {
            let block = bytes[blockStart..<(blockStart + n)].map { Int($0) }
            decodedInts.append(contentsOf: Self.multiplyMod256(inverseMatrix, block))
        }

        guard decodedInts.count >= 4 else { throw LinearEncoderError.corruptedLengthPrefix }
        let messageLength = Self.length(fromBigEndianBytes: Array(decodedInts[0..<4]))
        guard messageLength >= 0, 4 + messageLength <= decodedInts.count else {
            throw LinearEncoderError.corruptedLengthPrefix
        }

        let messageBytes = decodedInts[4..<(4 + messageLength)].map { UInt8($0) }
        guard let text = String(bytes: messageBytes, encoding: .utf8) else {
            throw LinearEncoderError.invalidUTF8
        }
        return text
    }

    // MARK: - ConfigurableTransformer

    func transform(_ input: Payload, configuration: LinearEncoderConfiguration) throws -> Payload {
        guard case .text(let text) = input else {
            throw LinearEncoderError.invalidPayloadType
        }
        return .data(try encode(text, configuration: configuration))
    }

    func inverse(_ input: Payload, configuration: LinearEncoderConfiguration) throws -> Payload {
        guard case .data(let data) = input else {
            throw LinearEncoderError.invalidPayloadType
        }
        return .text(try decode(data, configuration: configuration))
    }
}
