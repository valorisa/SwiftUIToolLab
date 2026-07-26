import Foundation

/// The single async point of contact in this repository. `size` is an
/// explicit required parameter (not in the brief's literal signature,
/// added deliberately — see conversation history): without it, the
/// service would have to guess the target grid dimension from
/// whatever text length OCR happens to recognize, an implicit
/// decision this protocol makes explicit instead.
///
/// Every other type this feature touches downstream
/// (Matrix.init(asciiGrid:), LinearOperatorService,
/// LinearEncoderService) is synchronous and stays synchronous — none
/// of them gain an async parameter because of this protocol. That is
/// a structural guarantee, not a convention: they simply have no
/// async entry point to call into.
protocol SheetReading {
    /// Reads the sheet image, recognizes its text via Vision, and
    /// re-segments the recognized text into a size x size grid of
    /// ASCII codes.
    func readGrid(from imageURL: URL, size: Int) async throws -> [[Int]]

    /// Same as readGrid, but also reports the average recognition
    /// confidence across the pieces used to build the grid.
    func extractGrid(from imageURL: URL, size: Int) async throws -> GridExtractionResult
}

enum SheetReaderError: Error, Equatable {
    case imageLoadFailed
    case visionRequestFailed(String)
    case noTextRecognized
    case incompleteGrid(expected: Int, found: Int)
    case nonASCIICharacter(Character)
}
