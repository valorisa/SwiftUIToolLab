import XCTest
@testable import SwiftUIToolLab

// MARK: - ConfigurableTransformerConformanceTests

/// Regression guard for Core/Protocols/ConfigurableTransformer.swift,
/// added when the protocol was exercised for the first time (v2-E).
/// No implementer existed before LinearOperatorService, so there is no
/// prior BEHAVIOR to compare against — the only meaningful check is
/// that a minimal conforming type still COMPILES against the
/// protocol's current signature. If a future edit to
/// ConfigurableTransformer breaks this file's compilation, that's the
/// intended signal: the contract changed.
private struct DummyConfiguration: Codable, Equatable {
    let value: Int
}

private struct DummyConfigurableTransformer: ConfigurableTransformer {
    typealias Configuration = DummyConfiguration

    func transform(_ input: Payload, configuration: DummyConfiguration) throws -> Payload {
        input
    }

    func inverse(_ input: Payload, configuration: DummyConfiguration) throws -> Payload {
        input
    }
}

final class ConfigurableTransformerConformanceTests: XCTestCase {
    func testMinimalConformingTypeCompilesAndRoundtrips() throws {
        let sut = DummyConfigurableTransformer()
        let configuration = DummyConfiguration(value: 42)
        let payload = Payload.text("unchanged")

        let transformed = try sut.transform(payload, configuration: configuration)
        let inverted = try sut.inverse(transformed, configuration: configuration)

        guard case .text(let value) = inverted else {
            XCTFail("Expected .text payload")
            return
        }
        XCTAssertEqual(value, "unchanged")
    }
}
