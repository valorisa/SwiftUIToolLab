import Foundation
import Vision
import ImageIO
import CoreGraphics

// MARK: - Origin story, closing the loop

/// # Where this closes the loop
///
/// LinearOperatorOrigin (🅰️) and LinearEncoderOrigin (🅱️) told the
/// first two thirds of the story: a laser-printer test sheet sparked
/// the idea of the sheet as a matrix, or in the loosest sense a
/// "Jacobian" — 🅰️ measured a hand-modeled version of that idea and
/// found it rank-deficient (honest, but the sheet itself was never
/// actually read); 🅱️ built a working reversible encoder, but from a
/// CONSTRUCTED matrix, not the sheet's own.
///
/// This feature reads the real photograph automatically, via Vision
/// (Apple's on-device OCR), and produces a grid in the exact format
/// 🅰️'s Matrix(asciiGrid:) expects — closing the gap between "the
/// sheet as an idea" and "the sheet as actually read". Visually, the
/// real sheet turned out to be a continuous block of repeating text
/// (the printable alphabet, shifted by one character per line), not
/// a native grid — this feature's segmentation step is what turns
/// that continuous text into the square grid the rest of the
/// pipeline expects. "Jacobian" still names nothing in this file,
/// deliberately, as in the two features before it.
enum SheetReaderOrigin {}

// MARK: - SheetReaderService

final class SheetReaderService: SheetReading {

    static let defaultMinimumConfidence: Float = 0.5

    private let minimumConfidence: Float

    init(minimumConfidence: Float = SheetReaderService.defaultMinimumConfidence) {
        self.minimumConfidence = minimumConfidence
    }

    // MARK: - SheetReading

    func readGrid(from imageURL: URL, size: Int) async throws -> [[Int]] {
        try await extractGrid(from: imageURL, size: size).grid
    }

    func extractGrid(from imageURL: URL, size: Int) async throws -> GridExtractionResult {
        let image = try Self.loadCGImage(from: imageURL)
        let pieces = try await recognizeTextPieces(in: image)
        return try Self.segmentIntoGrid(pieces: pieces, size: size, minimumConfidence: minimumConfidence)
    }

    // MARK: - Chantier 3/4: synchronous, testable segmentation logic

    /// Everything below this point is pure, synchronous Swift over
    /// [RecognizedTextPiece] — no Vision type ever appears here. This
    /// is what Layer-1 unit tests exercise directly, with hand-built
    /// pieces, entirely independent of Vision or the sheet image.
    ///
    /// The real sheet is a CONTINUOUS block of repeating text (not a
    /// native grid), and two side-by-side columns separated by a
    /// center margin. This function concatenates all above-confidence
    /// pieces in the order Vision returns them (its natural reading
    /// order) — it does NOT attempt to detect or reorder the two
    /// columns explicitly. KNOWN LIMITATION, documented rather than
    /// hidden: if Vision's reading order interleaves the two columns
    /// instead of reading one fully before the other, the resulting
    /// grid reflects that interleaving. This wasn't correctable
    /// without assuming a column layout that hasn't been independently
    /// confirmed to be Vision's actual behavior on this image.
    static func segmentIntoGrid(pieces: [RecognizedTextPiece], size: Int, minimumConfidence: Float) throws -> GridExtractionResult {
        let validPieces = pieces.filter { $0.confidence >= minimumConfidence }
        guard !validPieces.isEmpty else {
            throw SheetReaderError.noTextRecognized
        }

        let concatenated = validPieces.map(\.text).joined()
        let requiredCount = size * size
        guard concatenated.count >= requiredCount else {
            throw SheetReaderError.incompleteGrid(expected: requiredCount, found: concatenated.count)
        }

        var codes: [Int] = []
        codes.reserveCapacity(requiredCount)
        for character in concatenated.prefix(requiredCount) {
            guard let asciiValue = character.asciiValue else {
                throw SheetReaderError.nonASCIICharacter(character)
            }
            codes.append(Int(asciiValue))
        }

        var grid: [[Int]] = []
        grid.reserveCapacity(size)
        for row in 0..<size {
            let start = row * size
            grid.append(Array(codes[start..<(start + size)]))
        }

        let averageConfidence = validPieces.map { Double($0.confidence) }.reduce(0, +) / Double(validPieces.count)

        return GridExtractionResult(grid: grid, averageConfidence: averageConfidence)
    }

    // MARK: - Chantier 2: the single async point of contact

    /// The ONLY asynchronous call in this feature (and in the whole
    /// repository, as of this phase). Converts Vision's own
    /// VNRecognizedTextObservation (which has no public initializer,
    /// hence not directly testable) into RecognizedTextPiece, which
    /// is. Language correction is deliberately disabled: the sheet's
    /// text is not real words (it's the printable alphabet/digits/
    /// punctuation repeated with a shifting offset), so Vision's
    /// autocorrect would actively corrupt the reading rather than
    /// help it.
    private func recognizeTextPieces(in image: CGImage) async throws -> [RecognizedTextPiece] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: SheetReaderError.visionRequestFailed(error.localizedDescription))
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let pieces = observations.compactMap { observation -> RecognizedTextPiece? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedTextPiece(text: candidate.string, confidence: candidate.confidence)
                }
                continuation.resume(returning: pieces)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: SheetReaderError.visionRequestFailed(error.localizedDescription))
            }
        }
    }

    private static func loadCGImage(from url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw SheetReaderError.imageLoadFailed
        }
        return image
    }
}
