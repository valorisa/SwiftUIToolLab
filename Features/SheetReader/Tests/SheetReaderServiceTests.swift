import XCTest
@testable import SwiftUIToolLab

// MARK: - SheetReaderServiceTests

final class SheetReaderServiceTests: XCTestCase {

    // MARK: - Layer 1: deterministic unit tests (no Vision call)

    func testSegmentIntoGrid_ProducesExpectedGridFromPieces() throws {
        let pieces = [RecognizedTextPiece(text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefg", confidence: 0.9)]
        let result = try SheetReaderService.segmentIntoGrid(pieces: pieces, size: 6, minimumConfidence: 0.5)

        XCTAssertEqual(result.grid.count, 6)
        XCTAssertTrue(result.grid.allSatisfy { $0.count == 6 })
        XCTAssertEqual(result.grid[0][0], Int(Character("A").asciiValue!))
        XCTAssertEqual(result.grid[5][5], Int(Character("9").asciiValue!))
    }

    func testSegmentIntoGrid_FiltersLowConfidencePieces() throws {
        let pieces = [
            RecognizedTextPiece(text: "AAAA", confidence: 0.9),
            RecognizedTextPiece(text: "zzzz", confidence: 0.1),
            RecognizedTextPiece(text: "BBBB", confidence: 0.9)
        ]
        let result = try SheetReaderService.segmentIntoGrid(pieces: pieces, size: 2, minimumConfidence: 0.5)

        // Concatenation of valid-confidence pieces only: "AAAABBBB",
        // first 4 chars used for a 2x2 grid: "AAAA".
        XCTAssertEqual(result.grid, [[65, 65], [65, 65]])
    }

    func testSegmentIntoGrid_ThrowsWhenIncomplete() {
        let pieces = [RecognizedTextPiece(text: "AB", confidence: 0.9)]
        XCTAssertThrowsError(try SheetReaderService.segmentIntoGrid(pieces: pieces, size: 3, minimumConfidence: 0.5)) { error in
            XCTAssertEqual(error as? SheetReaderError, .incompleteGrid(expected: 9, found: 2))
        }
    }

    func testSegmentIntoGrid_ThrowsWhenNoValidPieces() {
        let pieces = [RecognizedTextPiece(text: "AB", confidence: 0.1)]
        XCTAssertThrowsError(try SheetReaderService.segmentIntoGrid(pieces: pieces, size: 2, minimumConfidence: 0.5)) { error in
            XCTAssertEqual(error as? SheetReaderError, .noTextRecognized)
        }
    }

    func testSegmentIntoGrid_ThrowsOnNonASCIICharacter_NoSilentSubstitution() {
        // Deliberately NOT filtered/substituted — the whole point of
        // this test is proving a non-ASCII character is a hard error,
        // not silently dropped or replaced with '?'.
        let pieces = [RecognizedTextPiece(text: "AÉCD", confidence: 0.9)]
        XCTAssertThrowsError(try SheetReaderService.segmentIntoGrid(pieces: pieces, size: 2, minimumConfidence: 0.5)) { error in
            guard case SheetReaderError.nonASCIICharacter = error else {
                XCTFail("Expected nonASCIICharacter, got \(error)")
                return
            }
        }
    }

    func testSegmentIntoGrid_AverageConfidenceComputedOverValidPiecesOnly() throws {
        let pieces = [
            RecognizedTextPiece(text: "AAAA", confidence: 1.0),
            RecognizedTextPiece(text: "BBBB", confidence: 0.6)
        ]
        let result = try SheetReaderService.segmentIntoGrid(pieces: pieces, size: 2, minimumConfidence: 0.5)
        XCTAssertEqual(result.averageConfidence, 0.8, accuracy: 1e-9)
    }

    // MARK: - Layer 2: the single real Vision integration test

    private static var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SheetReaderServiceTests.swift
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // SheetReader/
            .deletingLastPathComponent() // Features/
    }

    private static var sheetImageURL: URL {
        repoRootURL.appendingPathComponent("images/IMG_20260715_125151.jpg")
    }

    /// The ONLY test in this file (and the only test in the feature)
    /// that calls real Vision on the real sheet photo. Asserts stable
    /// STRUCTURAL properties only (grid shape, positive confidence) —
    /// never exact recognized text — so this test does not become
    /// flaky if Vision's model changes slightly between OS versions.
    func testRealSheetOCR_ProducesPlausibleGrid() async throws {
        guard FileManager.default.fileExists(atPath: Self.sheetImageURL.path) else {
            throw XCTSkip("Sheet image not found at \(Self.sheetImageURL.path) — skipping real Vision OCR test.")
        }

        let service = SheetReaderService()
        let size = 8
        let result = try await service.extractGrid(from: Self.sheetImageURL, size: size)

        XCTAssertEqual(result.grid.count, size)
        XCTAssertTrue(result.grid.allSatisfy { $0.count == size })
        XCTAssertGreaterThan(result.averageConfidence, 0)

        // Sanity check: the grid is at least well-formed enough to
        // build a Matrix from it (proves the [[Int]] contract this
        // feature promises to LinearOperator/LinearEncoder holds for
        // real Vision output, not just synthetic test data).
        let matrix = try Matrix(asciiGrid: result.grid)
        XCTAssertEqual(matrix.rowCount, size)
    }

    // MARK: - Full pipeline: sheet -> OCR -> grid -> Matrix -> measure/encode

    /// Demonstrates the complete loop this feature closes: the real
    /// sheet's OWN matrix (read automatically, not hand-transcribed)
    /// is measured by LinearOperatorService, then an honest attempt
    /// to encode/decode with it is made. Since 🅰️ already proved the
    /// sheet's repeating-alphabet structure is rank-deficient, this
    /// matrix is EXPECTED not to be unimodular — decode is expected
    /// to fail with matrixNotUnimodular. If it unexpectedly turns out
    /// invertible, the test still passes by checking the roundtrip
    /// succeeds instead — no unverified assumption is hard-coded
    /// either way.
    func testPipeline_RealSheetMatrixMeasuredAndHonestlyTestedForEncoding() async throws {
        guard FileManager.default.fileExists(atPath: Self.sheetImageURL.path) else {
            throw XCTSkip("Sheet image not found at \(Self.sheetImageURL.path) — skipping pipeline test.")
        }

        let readerService = SheetReaderService()
        let size = 8
        let grid = try await readerService.readGrid(from: Self.sheetImageURL, size: size)
        let matrix = try Matrix(asciiGrid: grid)

        let analysis = LinearOperatorService().analyze(matrix)

        let encoderConfig = try LinearEncoderConfiguration(matrix: matrix)
        let encoderService = LinearEncoderService()
        let encoded = try encoderService.encode("probe", configuration: encoderConfig)

        if analysis.isInvertible {
            let decoded = try encoderService.decode(encoded, configuration: encoderConfig)
            XCTAssertEqual(decoded, "probe")
        } else {
            XCTAssertThrowsError(try encoderService.decode(encoded, configuration: encoderConfig)) { error in
                XCTAssertEqual(error as? LinearEncoderError, .matrixNotUnimodular)
            }
        }
    }
}
