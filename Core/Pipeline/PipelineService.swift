import Foundation

/// Composes a sequence of payload transformations, applied in order.
///
/// Deliberately NOT built on a new Transforming protocol — Core already
/// has ReversibleTransformer and SecuredTransformer (Phase 6a), and
/// Base64Service/CryptoService already conform to them. A closure-based
/// design lets both be used here as-is:
///   - Base64Service.transform is passed directly as a method
///     reference — its signature already matches
///     (Payload) throws -> Payload.
///   - CryptoService.transform(_:secret:) is partially applied into a
///     closure by the caller building the pipeline, e.g.
///     `{ try cryptoService.transform($0, secret: .password(pw)) }` —
///     this is also how the password is threaded through, with no
///     dedicated "context" mechanism needed.
///
/// This is a generalization of the manual step-by-step chain already
/// exercised by IntegrationTests/RoundtripTests.swift since Phase 6b
/// (testCompleteRoundtrip_ImportBase64EncryptExportImportDecryptDecode)
/// — not a new capability, a reusable shape for an existing one.
final class PipelineService {
    /// Applies `steps` to `payload` in order. An empty sequence returns
    /// `payload` unchanged. If any step throws, execution stops
    /// immediately and the error propagates — no partial result is
    /// returned.
    func run(_ payload: Payload, through steps: [(Payload) throws -> Payload]) throws -> Payload {
        try steps.reduce(payload) { try $1($0) }
    }
}
