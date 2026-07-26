import Foundation

/// A single piece of recognized text, decoupled from Vision's own
/// VNRecognizedTextObservation type. Introduced because
/// VNRecognizedTextObservation has no public initializer — it can
/// only be produced by Vision itself, never constructed by hand for
/// a test. This struct is the boundary that makes the segmentation
/// logic (SheetReaderService.segmentIntoGrid) testable without ever
/// calling Vision.
struct RecognizedTextPiece: Equatable {
    let text: String
    let confidence: Float
}

/// Result of extracting a grid from a sheet image. Exposes the
/// average confidence alongside the grid rather than discarding it —
/// consistent with 🅰️'s "measure, don't just assert" discipline for
/// rank/condition number.
struct GridExtractionResult: Equatable {
    let grid: [[Int]]
    let averageConfidence: Double
}
