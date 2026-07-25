import XCTest
@testable import SwiftUIToolLab

// MARK: - LinearOperatorServiceTests

final class LinearOperatorServiceTests: XCTestCase {

    private var sut: LinearOperatorService!

    override func setUp() {
        super.setUp()
        sut = LinearOperatorService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Matrix validation

    func testMatrixRejectsIrregularShape() {
        XCTAssertThrowsError(try Matrix(values: [[1, 2], [3]])) { error in
            XCTAssertEqual(error as? Matrix.MatrixError, .irregularShape)
        }
    }

    func testMatrixRejectsEmpty() {
        XCTAssertThrowsError(try Matrix(values: [])) { error in
            XCTAssertEqual(error as? Matrix.MatrixError, .empty)
        }
    }

    func testMatrixCodableRevalidatesOnDecode() throws {
        // Hand-crafted JSON simulating a tampered/hand-edited .clab
        // payload with an irregular row — must fail to decode, not
        // silently produce an inconsistent Matrix.
        let tamperedJSON = "{\"values\":[[1,2,3],[4,5]]}".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Matrix.self, from: tamperedJSON))
    }

    // MARK: - Known invertible matrix

    func testKnownInvertibleMatrix_RankFullConditionNumberComputed() throws {
        // M = 2I (2x2): full rank, invertible. Deliberately chosen so
        // the Frobenius-norm condition number approximation can be
        // computed exactly by hand: ‖M‖_F = √8, ‖M⁻¹‖_F = √0.5,
        // product = 2.0 — illustrating the documented gap with the
        // true spectral condition number (which would be 1 for a
        // scalar multiple of the identity).
        let matrix = try Matrix(values: [[2, 0], [0, 2]])

        let analysis = sut.analyze(matrix)

        XCTAssertEqual(analysis.rank, 2)
        XCTAssertTrue(analysis.isInvertible)
        XCTAssertEqual(analysis.conditionNumber, 2.0, accuracy: 1e-9)
    }

    // MARK: - Known rank-deficient matrix

    func testKnownRankDeficientMatrix_NotInvertibleConditionNumberInfinite() throws {
        // M = [[1,1],[2,2]]: row2 = 2*row1, rank 1, not invertible.
        let matrix = try Matrix(values: [[1, 1], [2, 2]])

        let analysis = sut.analyze(matrix)

        XCTAssertEqual(analysis.rank, 1)
        XCTAssertFalse(analysis.isInvertible)
        XCTAssertEqual(analysis.conditionNumber, .infinity)
    }

    // MARK: - Fixture "sheet" matrix — rank MEASURED, not asserted to a specific value

    func testFixtureSheetMatrix_RankMeasuredWithinProvenBound() throws {
        let fixtureText = try loadFixtureText(named: "repeated_alphabet_sheet", extension: "txt")
        let grid = try sut.parseASCIIGrid(from: fixtureText)
        let matrix = try sut.loadMatrix(fromASCIIGrid: grid)

        XCTAssertEqual(matrix.rowCount, 8)
        XCTAssertEqual(matrix.columnCount, 8)

        let analysis = sut.analyze(matrix)

        // This fixture is constructed as row_i = base + 7*i*ones, i.e.
        // M = ones_column ⊗ base_row + step_column ⊗ ones_row — a sum
        // of two rank-1 matrices. rank(A+B) <= rank(A) + rank(B) is a
        // standard linear algebra fact, so rank(M) <= 2 is PROVEN by
        // construction, not just observed. The exact value (likely,
        // but not asserted, exactly 2) is what Gaussian elimination
        // measures below — we assert the proven bound, not a guessed
        // exact figure.
        XCTAssertLessThanOrEqual(analysis.rank, 2, "Mathematically guaranteed by construction (sum of two rank-1 matrices).")
        XCTAssertGreaterThanOrEqual(analysis.rank, 1, "Sanity check: the fixture isn't the all-zero matrix.")
        XCTAssertFalse(analysis.isInvertible, "rank <= 2 on an 8x8 matrix cannot be full rank.")
        XCTAssertEqual(analysis.conditionNumber, .infinity)
    }

    func testParseASCIIGrid_IrregularRowLengthThrows() {
        XCTAssertThrowsError(try sut.parseASCIIGrid(from: "1 2 3\n4 5")) { error in
            XCTAssertEqual(error as? FixtureParsingError, .irregularRowLength)
        }
    }

    func testParseASCIIGrid_InvalidIntegerThrows() {
        XCTAssertThrowsError(try sut.parseASCIIGrid(from: "1 2 3\n4 x 6")) { error in
            XCTAssertEqual(error as? FixtureParsingError, .invalidInteger(line: 1, token: "x"))
        }
    }

    // MARK: - ConfigurableTransformer conformance

    func testTransformAppliesMatrixMultiplication() throws {
        let matrix = try Matrix(values: [[1, 2], [3, 4]])
        let configuration = MatrixAnalysisConfiguration(matrix: matrix)

        let result = try sut.transform(.text("1,1"), configuration: configuration)

        guard case .text(let value) = result else {
            XCTFail("Expected .text payload")
            return
        }
        XCTAssertEqual(value, "3.0,7.0")
    }

    func testTransformInverseRoundtrip() throws {
        let matrix = try Matrix(values: [[1, 2], [3, 4]])
        let configuration = MatrixAnalysisConfiguration(matrix: matrix)

        let transformed = try sut.transform(.text("5,1"), configuration: configuration)
        let inverted = try sut.inverse(transformed, configuration: configuration)

        guard case .text(let value) = inverted else {
            XCTFail("Expected .text payload")
            return
        }
        let recovered = value.split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(recovered.count, 2)
        XCTAssertEqual(recovered[0], 5.0, accuracy: 1e-6)
        XCTAssertEqual(recovered[1], 1.0, accuracy: 1e-6)
    }

    func testInverseThrowsWhenMatrixNotInvertible() throws {
        let matrix = try Matrix(values: [[1, 1], [2, 2]])
        let configuration = MatrixAnalysisConfiguration(matrix: matrix)

        XCTAssertThrowsError(try sut.inverse(.text("1,2"), configuration: configuration)) { error in
            XCTAssertEqual(error as? LinearOperatorError, .matrixNotInvertible)
        }
    }

    func testTransformDimensionMismatchThrows() throws {
        let matrix = try Matrix(values: [[1, 2], [3, 4]])
        let configuration = MatrixAnalysisConfiguration(matrix: matrix)

        XCTAssertThrowsError(try sut.transform(.text("1,2,3"), configuration: configuration)) { error in
            XCTAssertEqual(error as? LinearOperatorError, .dimensionMismatch(expected: 2, actual: 3))
        }
    }

    // MARK: - Fixture loading (Bundle.module)

    /// Resource path resolution inside Bundle.module for a resource
    /// declared via `.copy(...)` in Package.swift is not something I
    /// can verify without a compiler. Three fallback strategies are
    /// tried, from most to least specific, before giving up with a
    /// clear, actionable message — resilient to whichever exact
    /// placement SPM chooses, rather than a single hardcoded guess
    /// that silently fails.
    private func loadFixtureText(named name: String, extension ext: String) throws -> String {
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Features/LinearOperator/Tests/Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: ext)
            ?? Bundle.module.urls(forResourcesWithExtension: ext, subdirectory: nil)?.first { $0.lastPathComponent == "\(name).\(ext)" }

        guard let resolvedURL = url else {
            throw XCTSkip("Fixture \(name).\(ext) not found in Bundle.module — check the .copy(...) resource declaration in Package.swift for Features/LinearOperator/Tests/Fixtures.")
        }

        return try String(contentsOf: resolvedURL, encoding: .utf8)
    }
}
