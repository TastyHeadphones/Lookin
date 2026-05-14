// swift-tools-version:6.0
import PackageDescription

// macOS-only MCP server library for the Lookin client.
//
// This is a separate package from the root LookinServer manifest so the
// iOS-only server target and the macOS-only MCP target never have to
// share a platform list — `swift test` on a macOS host builds only this
// package and never tries to compile UIKit sources for macOS.

let package = Package(
    name: "LookinMCP",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "LookinMCP", targets: ["LookinMCP"]),
    ],
    targets: [
        .target(
            name: "LookinMCP",
            path: "Sources/LookinMCP",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "LookinMCPTests",
            dependencies: ["LookinMCP"],
            path: "Tests/LookinMCPTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
