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

## Architecture

```text
SwiftUIToolLab/
├── App/
├── Features/
│   ├── Base64/
│   ├── Crypto/
│   ├── FileImportExport/
│   └── Settings/
├── Core/
│   ├── Workspace/
│   ├── Protocols/
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
| `ConfigurableTransformer` | Parameters, no secret | Image resizing |
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
- [ ] Phase 5 — Full FileImportExport implementation with passing tests
- [ ] Phase 6 — Cross-feature integration and roundtrip tests

## Contributing

Contributions follow Conventional Commits and a `main` / `dev` / `backup` branch strategy. Pull
requests are squash-merged and the source branch is deleted after merge.

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## Author

Maintained by [@valorisa](https://github.com/valorisa).
