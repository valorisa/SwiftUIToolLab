// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftUIToolLab",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SwiftUIToolLab", targets: ["SwiftUIToolLab"])
    ],
    targets: [
        // MARK: - TODO: split into a library target (Core + Features) once
        // features start depending on real implementations, keeping this
        // executable target as a thin App/ entry point only.
        .executableTarget(
            name: "SwiftUIToolLab",
            path: ".",
            exclude: [
                "IntegrationTests",
                "README.md",
                "README.fr.md",
                "LICENSE",
                ".markdownlint.json",
                ".gitignore",
                ".git"
            ],
            sources: [
                "App",
                "Features",
                "Core"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SwiftUIToolLabTests",
            dependencies: ["SwiftUIToolLab"],
            path: "IntegrationTests"
        )
    ]
)
