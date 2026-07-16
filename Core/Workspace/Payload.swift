import Foundation

// MARK: - TODO
// Represents the data currently held in the Workspace.

enum Payload {
    case text(String)
    case data(Data)
    case image(Data)
    case unknown
}
