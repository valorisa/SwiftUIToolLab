![Platform](https://img.shields.io/badge/platform-macOS-blue)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blueviolet)
![License](https://img.shields.io/badge/license-MIT-green)
![CI](https://github.com/valorisa/SwiftUIToolLab/actions/workflows/ci.yml/badge.svg)
![Status](https://img.shields.io/badge/status-in%20development-yellow)

**Read this in other languages: [Français](README.fr.md)**

# SwiftUIToolLab

A native, local, modular, and testable macOS application built with SwiftUI for **reversible data
transformations**: encoding, decoding, encryption, decryption, and file import/export. Visual
transformation of images and printed pages is planned for a later stage.

> **Status:** v1 is complete (Phases 0–6). v2 is in progress: localization, security,
> testability, composition, and a linear-operator demonstrator are done; a reversible
> linear-operator encoder (v2-F) and image/OCR transformation are next.

## Key principles

- 100% local processing, no network dependency, no backend, no cloud features.
- Strict separation between UI, business logic, services, models, and tests.
- Feature-based (vertical slicing) architecture: each feature is a self-contained module.
- MVVM, protocol-oriented design, explicit error handling, no logic in views.

## Features (v1 scope)

- Base64 encoding/decoding of text.
- Import/export of text and binary files.
- Local symmetric encryption with a password (CryptoKit, authenticated).
- Output preview and clipboard copy.
- Unit tests covering roundtrip and error scenarios.

## Features (v2 scope)

v2 hardens and extends v1 along eight axes. All nine phases below are complete and CI-validated.

- **Phase 7 (v2-A) — Localization:** full EN/FR localization of the UI (41 keys), with a robust test
  enforcing key parity, no empty values, and no FR value identical to EN outside an explicit
  allow-list. `FileImportExportError` is localized via `LocalizedError`.
- **Phase 8–9 (v2-B, v2-B-bis) — Security:** complete threat model for real secrets: the password is
  purged after every operation (success or failure); sensitive payloads update `currentPayload` but
  are never added to history (undo skips them); sensitive text is purged on tab change via a global,
  non-cosmetic purge (VMs + reload, not a surface wipe). Base64 is not purged (not a secret by
  construction).
- **Phase 10 (v2-C) — Testability:** injectable panels (`OpenPanelProviding` / `SavePanelProviding`,
  with `OpenPanelWrapper` / `SavePanelWrapper` conformances) make `FileImportExportViewModel`
  testable end-to-end with mocks. Closes v1 debt D5.
- **Phase 11 (v2-D) — Composition:** `PipelineService` (in `Core/`) composes a sequence of transform
  closures via a single `reduce`. No new protocol: it reuses `ReversibleTransformer` /
  `SecuredTransformer`. 8 tests, including behavioral equivalence with the Phase 6b manual chain.
- **Phase 12 (v2-E) — LinearOperator demonstrator:** first real use of `ConfigurableTransformer` (13
  phases after its creation). A `LinearOperator` feature measures a matrix's rank (Gaussian
  elimination, partial pivoting) and condition number (Frobenius-norm approximation) on a
  deterministic fixture (provably rank ≤ 2). It *measures*, it does not build a working encoder —
  that is the next phase. No UI (output is the tests + an in-code origin story that keeps the word
  "Jacobian" out of every symbol).

## Architecture

```text
SwiftUIToolLab/
├── App/
├── Features/
│   ├── Base64/
│   ├── Crypto/
│   ├── FileImportExport/
│   ├── LinearOperator/
│   └── Settings/
├── Core/
│   ├── Workspace/
│   ├── Protocols/
│   ├── Pipeline/
│   ├── Serialization/
│   └── Extensions/
├── IntegrationTests/
├── Resources/
└── README.md
```

Each feature only communicates with others through protocols defined in `Core/Protocols/`. The
`Workspace` is a pure data container: it never implements business logic (no `encrypt()`, no
`base64Encode()`).

### The transformer trinity

Three distinct protocols instead of one generic protocol with a configuration dictionary:

| Protocol | Use case | Example |
|---|---|---|
| `ReversibleTransformer` | No parameters, strict 1:1 | Base64, ROT13 |
| `ConfigurableTransformer` | Parameters, no secret | Image resizing, linear operators (v2-E) |
| `SecuredTransformer` | Authenticated secret | Encryption, signing |

### File format

Every export produces a single versioned `.cryptolab` (or `.clab`) file bundling the payload,
encryption header, and metadata. Users never manage keys, IVs, or metadata separately.

## Requirements

- macOS 14+
- Xcode 15+
- Swift 5.9+

## Getting started

```bash
git clone https://github.com/valorisa/SwiftUIToolLab.git
cd SwiftUIToolLab
open SwiftUIToolLab.xcodeproj
```

## Testing

Each feature follows a strict protocol → test → implementation sequence, with three levels of
coverage: mocked business logic, corrupted-file robustness, and native macOS alert UI.

```bash
xcodebuild test -scheme SwiftUIToolLab -destination 'platform=macOS'
```

## Roadmap

- [x] Phase 0 — Folder structure and empty files with `// MARK: - TODO`
- [x] Phase 1 — Core/Workspace, models, and protocols (compiles)
- [x] Phase 2 — ServiceLocator, dependency injection, one minimal feature (compiles and renders)
- [x] Phase 3 — Full Base64 implementation with passing tests
- [x] Phase 4 — Full Crypto implementation with passing tests
- [x] Phase 5 — Full FileImportExport implementation with passing tests
- [x] Phase 6 — Cross-feature integration and roundtrip tests
- [x] Phase 7 (v2-A) — Localization (41 EN/FR keys, robust test, localized errors)
- [x] Phase 8 (v2-B) — Security: password purge + sensitive payloads excluded from history
- [x] Phase 9 (v2-B-bis) — Security: sensitive text purge on tab change, global anti-cosmetic purge
- [x] Phase 10 (v2-C) — Injectable panels (closes v1 debt D5)
- [x] Phase 11 (v2-D) — Pipeline-service (pure composition in Core/)
- [x] Phase 12 (v2-E) — LinearOperator demonstrator (rank/condition measurement)
- [x] Phase 13 (v2-F) — Reversible linear operator (unimodular matrix, range handling)
- [x] Phase 14 (v2-G) — SheetReader: read the real sheet via Vision OCR (closes the Jacobian loop) — done
- [x] Phase 15 (v2-H) — ImageTransform: reversible image operations (rotate/flip/invert, bit-exact)

## Contributing

Contributions follow Conventional Commits and a `main` / `dev` / `backup` branch strategy. Pull
requests are squash-merged and the source branch is deleted after merge.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## Author

Maintained by [@valorisa](https://github.com/valorisa).
