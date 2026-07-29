![Platform](https://img.shields.io/badge/platform-macOS-blue)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blueviolet)
![License](https://img.shields.io/badge/license-MIT-green)
![CI](https://github.com/valorisa/SwiftUIToolLab/actions/workflows/ci.yml/badge.svg)

**Read this document in French: [Français](README.fr.md)**

# SwiftUIToolLab

## What is it?

SwiftUIToolLab is a macOS application that lets you **transform data reversibly**. "Reversible"
means one simple thing: you can always go back, **without ever losing the original
information**. Applying a transformation and then its inverse gives back exactly the starting
data, byte for byte.

Concretely, the application offers four tabs:

- **Base64** — turn text or a file into plain text, and back;
- **Crypto** — encrypt text with a password, and decrypt it;
- **Files** — import and export text or binary files;
- **Image** — import an image, rotate or flip it, and export it (new).

**Everything happens on your computer.** Nothing is sent over the internet, there is no account
to create, no remote server. Your data never leaves your machine.

## Why this project?

There are many online tools to encode Base64 or encrypt text. The problem: these tools send your
data to servers you do not control. For sensitive data, that is a risk.

SwiftUIToolLab makes the opposite choice: **processing is 100% local**. It is the simplest
possible guarantee for confidentiality — if nothing leaves your computer, nothing can be
intercepted.

It is also, openly, a **learning project**: it explores how to build a macOS application that is
modular (each feature is an independent module), testable (each module is covered by automated
tests), and safe (secrets such as passwords are wiped from memory as soon as they are no longer
needed).

## What can the application do?

Here is a concrete use case for each tab.

### Base64

Base64 is a way to write any data (text, image, PDF…) as plain text, using only letters,
digits, and two symbols (`+` and `/`).

**Use case:** you want to paste a small binary file into an email or a form field that only
accepts text. You encode it to Base64 (it becomes text), paste it, and the recipient decodes it
to recover the **exactly identical** file.

### Crypto

The Crypto tab encrypts text with a password (authenticated symmetric encryption, via Apple's
CryptoKit library). Without the password, the encrypted text is unreadable.

**Use case:** you want to keep a confidential note. You encrypt it with a password and store the
encrypted result. To read it again, you decrypt it with the same password.

**Important security detail:** the password is **wiped from memory** after every operation
(whether it succeeds or fails). Sensitive texts are never kept in the application's history, and
are purged when you switch tabs.

### Files

The Files tab handles importing and exporting files (text or binary).

**Use case:** you import a file, apply a transformation to it, then export the result. Every
export produces a single `.cryptolab` (or `.clab`) file bundling the data, the encryption
header, and the metadata — you never have to manage a key, IV, or metadata separately.

### Image (new)

The Image tab applies **reversible** transformations to real images.

**Use case:** you import a photo (PNG or JPEG), apply an operation (rotate 90°/180°/270°,
flip horizontal or vertical, invert colors), then export the result as PNG. Since the
transformation is reversible, applying the inverse operation would give back the original
image, **byte for byte**.

The export is **always PNG**: even if you type a filename ending in `.jpg`, the code
automatically renames it to `.png`. This is a guarantee **by construction** (the code only ever
produces PNG), not just a checkbox.

> Two features were deliberately left out of this first version of the Image tab: the **visual
> preview** of the image (before/after) and the **chaining** of several transformations. They
> may come later, each as a separate piece of work.

## Reversible transformations, the heart of the project

The whole application revolves around one idea: transformations that can be **undone exactly**.
An analogy: turning a steering wheel 90° right, then 90° left, brings you back exactly to the
starting position. That is what each transformation in the application does, but on data.

To organize these transformations, the code distinguishes three families (three "protocols", in
Swift jargon), according to the nature of the operation:

| Family | In one sentence | Analogy | Examples |
|---|---|---|---|
| `ReversibleTransformer` | No settings, 1:1 reversible | A door | Base64 |
| `ConfigurableTransformer` | With settings, no secret | An adjustable oven | Image, linear operators |
| `SecuredTransformer` | With authenticated secret | A safe | Encryption |

This separation is not cosmetic: it lets the code (and the tests) handle each family by its own
rules — for example, never storing a secret for the third family.

## How is the application built?

This section is for the curious and for developers.

The application follows a **feature-based** architecture: each tab is a self-contained module,
stored in its own folder under `Features/`. Modules only talk to each other through
**protocols** (interface contracts) defined in a shared folder `Core/Protocols/`. Result: you
can modify or test one module without touching the others.

Each tab follows the **MVVM** pattern:

- the **View** (the "face") displays the interface and does **no computation**;
- the **ViewModel** (the "brain") does the work and gives the View what it should display;
- the **Model** (the "data"): the data structures (such as `Payload`, `Matrix`, or `RawImage`)
  that the ViewModel manipulates.

A **ServiceLocator** acts as a central directory: it knows which concrete implementation to use
for each service type. Analogy: a telephone switchboard that connects you to the right
department, without you needing to know its direct number.

### Project tree

```text
SwiftUIToolLab/
├── App/                        (application entry point)
├── Features/                   (one subfolder per tab)
│   ├── Base64/
│   ├── Crypto/
│   ├── FileImportExport/
│   ├── ImageTransform/         (Image tab — new)
│   ├── LinearEncoder/
│   ├── LinearOperator/
│   ├── SheetReader/
│   └── Settings/
├── Core/                       (shared across features)
│   ├── Workspace/
│   ├── Protocols/
│   ├── Pipeline/
│   ├── Serialization/
│   └── Extensions/
├── IntegrationTests/
├── Resources/
├── docs/                       (decision notes, including option-y-reopening.md)
└── README.md
```

## The Image tab and the input/output bridge

The Image tab relies on two recently added building blocks:

1. **Reversible image operations** (`ImageTransformService`): rotation, flip, color inversion,
   all proven invertible and tested **byte for byte**.
2. **The input/output bridge** (`ImageIOBridge`): it reads a real image file (PNG or JPEG) and
   writes a real PNG file. Before it, image transformations only worked on images fabricated in
   memory inside tests — no real image could enter or leave.

For a long time, the project's "computation" features had **no graphical interface**: the logic
was validated first (by tests), and the interface was deferred. This was a method rule nicknamed
**"Option Y"** ("a computation workstream does not mix in a UI decision"). The Image tab marks
the **reopening** of that rule: with the logic and the I/O bridge validated, the interface
became possible.

> For the detail of this decision (why the rule existed, why it was reopened, the choices made,
> the precautions taken), see the dedicated note:
> [`docs/option-y-reopening.md`](docs/option-y-reopening.md) (in French).

## The project history, step by step

The project was built in successive layers, each adding a level of maturity.

**v1 — the foundations.** Setting up the structure, the first three tabs (Base64, Crypto,
Files), and automated tests (including "roundtrip" tests: encoding then decoding must give back
exactly the original data).

**v2 — the hardening.** v2 hardened and extended v1 along **several axes**, grouped below into
five themes (the last one alone gathers four features):

- full **localization** of the interface in French and English;
- **security**: systematic wiping of passwords and sensitive texts from memory;
- **testability**: the file open/save panels can be replaced by mocks in tests;
- **composition**: a service that chains several transformations in sequence;
- a family of **configurable transformers**, declined into four features: a linear-algebra
  demonstrator (measuring a matrix's rank), a reversible linear encoder, a sheet reader using
  optical character recognition (OCR), and image operations.

Each step was validated by **continuous integration** (CI): on every change, the project is
recompiled and all tests are rerun automatically.

## For developers

### Requirements

- macOS 14 or later;
- Xcode 15 or later;
- Swift 5.9 or later.

### Getting started

```bash
git clone https://github.com/valorisa/SwiftUIToolLab.git
cd SwiftUIToolLab
open SwiftUIToolLab.xcodeproj
```

### Running the tests

```bash
xcodebuild test -scheme SwiftUIToolLab -destination 'platform=macOS'
```

Each feature follows a strict sequence: **protocol → test → implementation**. First the contract
(protocol), then the tests, then the code that makes the tests pass.

### Contributing

Contributions follow the **Conventional Commits** convention and a `main` / `dev` / `backup`
branch strategy. Pull requests are **squash-merged** (all commits of a branch are grouped into
one), and the source branch is deleted after merge.

## Roadmap

The following steps are **complete** and CI-validated:

- [x] Phases 0–6 (v1) — structure, Base64, Crypto, Files, integration and roundtrip tests
- [x] Phase 7 (v2-A) — French/English localization (41 keys)
- [x] Phases 8–9 (v2-B, v2-B-bis) — security (secret wiping)
- [x] Phase 10 (v2-C) — injectable file panels (testability)
- [x] Phase 11 (v2-D) — composition service (chaining transformations)
- [x] Phase 12 (v2-E) — linear-operator demonstrator (rank/condition measurement)
- [x] Phase 13 (v2-F) — reversible linear encoder (unimodular matrix)
- [x] Phase 14 (v2-G) — laser-sheet reader via OCR (Vision)
- [x] Phase 15 (v2-H) — reversible image operations (rotate/flip/invert, byte-exact)
- [x] Image I/O bridge (PR #16) — read/write real image files (JPEG in, PNG out)
- [x] Image tab (PR #17) — graphical interface for image transformations
- [x] Option Y decision note (PR #18) — documentation of the rule reopening

**Envisioned ideas** (not planned):

- [ ] Visual preview of the image (before/after) in the Image tab
- [ ] Chaining of several image transformations

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## Author

Maintained by [@valorisa](https://github.com/valorisa).
