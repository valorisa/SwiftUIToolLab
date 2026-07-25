import XCTest
@testable import SwiftUIToolLab

// MARK: - LinearEncoderServiceTests

final class LinearEncoderServiceTests: XCTestCase {

    private var sut: LinearEncoderService!

    override func setUp() {
        super.setUp()
        sut = LinearEncoderService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Chantier 2: unimodularity + mixing criterion

    func testGeneratedMatrixIsUnimodular() throws {
        for seed: UInt64 in [1, 2, 3, 42] {
            let configuration = try sut.generateConfiguration(size: 4, seed: seed, operationCount: 20)
            let determinant = LinearEncoderService.determinant(of: configuration.integerMatrix)
            XCTAssertTrue(determinant == 1 || determinant == -1, "Expected determinant ±1 for seed \(seed), got \(determinant)")
        }
    }

    func testGeneratedMatrixMeetsMixingCriterion() throws {
        let configuration = try sut.generateConfiguration(size: 4, seed: 7, operationCount: 20)
        let integerMatrix = configuration.integerMatrix
        let size = integerMatrix.count

        var offDiagonalNonZero = 0
        var offDiagonalTotal = 0
        for row in 0..<size {
            for col in 0..<size where row != col {
                offDiagonalTotal += 1
                if integerMatrix[row][col] != 0 {
                    offDiagonalNonZero += 1
                }
            }
        }
        let density = Double(offDiagonalNonZero) / Double(offDiagonalTotal)
        XCTAssertGreaterThan(density, 0.5, "Empirical mixing criterion (not a cryptographic guarantee): expected more than half of off-diagonal entries non-zero.")

        let doubleMatrix = try Matrix(values: integerMatrix.map { $0.map(Double.init) })
        let analysis = LinearOperatorService().analyze(doubleMatrix)
        XCTAssertGreaterThan(analysis.conditionNumber, Double(size), "Condition number must exceed the identity-matrix floor (n), ruling out a near-identity construction.")
    }

    // MARK: - Chantier 3: inverse mod 256 via adjugate

    func testInverseMod256MatchesIdentityWhenComposedWithMatrix() throws {
        let configuration = try sut.generateConfiguration(size: 4, seed: 21, operationCount: 20)
        let matrix = configuration.integerMatrix
        let inverse = try LinearEncoderService.inverseMod256(of: matrix)
        let size = matrix.count

        for row in 0..<size {
            for col in 0..<size {
                var sum = 0
                for k in 0..<size { sum += matrix[row][k] * inverse[k][col] }
                let expected = row == col ? 1 : 0
                XCTAssertEqual(LinearEncoderService.positiveMod(sum, 256), expected, "Mismatch at (\(row),\(col))")
            }
        }
    }

    func testBlockOverflowIsHandledByModularReduction() throws {
        // Hand-verifiable 2x2 example: det([[1,1],[1,2]]) = 1.
        let matrix = [[1, 1], [1, 2]]
        let vector = [200, 200] // M*x in real arithmetic = [400, 600], both > 255

        let encoded = LinearEncoderService.multiplyMod256(matrix, vector)
        XCTAssertEqual(encoded, [144, 88], "400 mod 256 = 144, 600 mod 256 = 88")

        let inverse = try LinearEncoderService.inverseMod256(of: matrix)
        let decoded = LinearEncoderService.multiplyMod256(inverse, encoded)

        XCTAssertEqual(decoded, vector, "Recovering the block requires reducing mod 256 throughout, not truncating the real-valued inverse.")
    }

    // MARK: - Chantier 4: roundtrip + padding

    func testRoundtripSimpleText() throws {
        let configuration = try sut.generateConfiguration(size: 4, seed: 11, operationCount: 20)
        let original = "Hello, LinearEncoder! Accents: éà. Emoji: 🔐."

        let encoded = try sut.encode(original, configuration: configuration)
        let decoded = try sut.decode(encoded, configuration: configuration)

        XCTAssertEqual(decoded, original)
    }

    func testRoundtripEmptyStringIsTheNaturalExactMultipleCase() throws {
        // Empty message: plaintext is just the 4-byte length prefix,
        // already an exact multiple of a 4x4 matrix's block size —
        // the "cas multiple-exact" arising naturally, not engineered.
        let configuration = try sut.generateConfiguration(size: 4, seed: 12, operationCount: 20)

        let encoded = try sut.encode("", configuration: configuration)
        XCTAssertEqual(encoded.count, 4)

        let decoded = try sut.decode(encoded, configuration: configuration)
        XCTAssertEqual(decoded, "")
    }

    func testRoundtripExactMultipleOfBlockSizeEngineeredCase() throws {
        let configuration = try sut.generateConfiguration(size: 4, seed: 13, operationCount: 20)
        let original = "twelve bytes" // 12 UTF-8 bytes + 4-byte prefix = 16 = 4*4
        XCTAssertEqual(original.utf8.count, 12)

        let encoded = try sut.encode(original, configuration: configuration)
        XCTAssertEqual(encoded.count, 16)

        let decoded = try sut.decode(encoded, configuration: configuration)
        XCTAssertEqual(decoded, original)
    }

    func testRoundtripRequiringPadding() throws {
        let configuration = try sut.generateConfiguration(size: 4, seed: 14, operationCount: 20)
        let original = "not a multiple"

        let encoded = try sut.encode(original, configuration: configuration)
        XCTAssertEqual(encoded.count % 4, 0)

        let decoded = try sut.decode(encoded, configuration: configuration)
        XCTAssertEqual(decoded, original)
    }

    func testRoundtripLongerTextLargerBlockSize() throws {
        let configuration = try sut.generateConfiguration(size: 8, seed: 15, operationCount: 40)
        let original = String(repeating: "SwiftUIToolLab LinearEncoder roundtrip test. ", count: 20)

        let encoded = try sut.encode(original, configuration: configuration)
        let decoded = try sut.decode(encoded, configuration: configuration)

        XCTAssertEqual(decoded, original)
    }

    func testDecodeRejectsMisalignedData() throws {
        let configuration = try sut.generateConfiguration(size: 4, seed: 32, operationCount: 20)
        let misaligned = Data([1, 2, 3])

        XCTAssertThrowsError(try sut.decode(misaligned, configuration: configuration)) { error in
            XCTAssertEqual(error as? LinearEncoderError, .invalidBlockAlignment)
        }
    }

    // MARK: - Configuration validation

    func testConfigurationRejectsNonSquareMatrix() throws {
        let nonSquare = try Matrix(values: [[1, 2, 3], [4, 5, 6]])
        XCTAssertThrowsError(try LinearEncoderConfiguration(matrix: nonSquare)) { error in
            XCTAssertEqual(error as? LinearEncoderConfiguration.ConfigurationError, .matrixNotSquare)
        }
    }

    func testConfigurationRejectsNonIntegerValues() throws {
        let nonInteger = try Matrix(values: [[1.5, 0], [0, 1]])
        XCTAssertThrowsError(try LinearEncoderConfiguration(matrix: nonInteger)) { error in
            XCTAssertEqual(error as? LinearEncoderConfiguration.ConfigurationError, .nonIntegerMatrixValues)
        }
    }

    // MARK: - ConfigurableTransformer conformance

    func testTransformInverseRoundtripViaConfigurableTransformerAPI() throws {
        let configuration = try sut.generateConfiguration(size: 4, seed: 30, operationCount: 20)

        let transformed = try sut.transform(.text("via ConfigurableTransformer"), configuration: configuration)
        guard case .data = transformed else {
            XCTFail("Expected .data payload from transform")
            return
        }

        let inverted = try sut.inverse(transformed, configuration: configuration)
        guard case .text(let result) = inverted else {
            XCTFail("Expected .text payload from inverse")
            return
        }
        XCTAssertEqual(result, "via ConfigurableTransformer")
    }

    func testTransformRejectsNonTextPayload() throws {
        let configuration = try sut.generateConfiguration(size: 4, seed: 31, operationCount: 20)
        XCTAssertThrowsError(try sut.transform(.data(Data([1, 2, 3])), configuration: configuration)) { error in
            XCTAssertEqual(error as? LinearEncoderError, .invalidPayloadType)
        }
    }

    // MARK: - Chantier 5: SE-0309 polymorphic coexistence

    /// Exercises the case left open since v2-E's synchronization: two
    /// ConfigurableTransformer conformances with DIFFERENT
    /// Configuration types (MatrixAnalysisConfiguration vs
    /// LinearEncoderConfiguration) coexisting in the same compilation
    /// unit. If this file compiles and this test runs, the polymorphic
    /// case is confirmed here and now — not before.
    func testPolymorphicCoexistenceWithLinearOperatorServicing() throws {
        let operatorService = LinearOperatorService()
        let analysisMatrix = try Matrix(values: [[2, 0], [0, 2]])
        let analysisConfig = MatrixAnalysisConfiguration(matrix: analysisMatrix)
        let analysisResult = try operatorService.transform(.text("1,1"), configuration: analysisConfig)
        guard case .text = analysisResult else {
            XCTFail("Expected .text payload from LinearOperatorService.transform")
            return
        }

        let encoderConfig = try sut.generateConfiguration(size: 4, seed: 1, operationCount: 20)
        let encoded = try sut.transform(.text("hi"), configuration: encoderConfig)
        guard case .data = encoded else {
            XCTFail("Expected .data payload from LinearEncoderService.transform")
            return
        }
    }
}
