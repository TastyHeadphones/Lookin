// swift-tools-version:6.0
import PackageDescription

// LookinServer SPM manifest for the TastyHeadphones/Lookin fork.
//
// Sources live in the QMUI/LookinServer submodule under Vendor/LookinServer,
// pinned in .gitmodules. This manifest wraps those sources so consumers can
// depend on this fork directly via SPM:
//
//   .package(url: "https://github.com/TastyHeadphones/Lookin.git", branch: "Develop")
//
// Swift language mode stays at .v5 here; the Swift 6 language-mode migration
// is tracked as a separate workstream.

let debugDefines: [SwiftSetting] = [
    .define("SHOULD_COMPILE_LOOKIN_SERVER", .when(configuration: .debug)),
    .define("SPM_LOOKIN_SERVER_ENABLED", .when(configuration: .debug)),
]

let debugCDefines: [CSetting] = [
    .define("SHOULD_COMPILE_LOOKIN_SERVER", to: "1", .when(configuration: .debug)),
    .define("SPM_LOOKIN_SERVER_ENABLED", to: "1", .when(configuration: .debug)),
]

let package = Package(
    name: "LookinServer",
    platforms: [
        .iOS(.v16),
        .tvOS(.v16),
    ],
    products: [
        .library(name: "LookinServer", targets: ["LookinServer"]),
    ],
    targets: [
        .target(
            name: "LookinServer",
            dependencies: ["LookinServerSwift"],
            path: "Vendor/LookinServer/Src/Main",
            publicHeadersPath: "",
            cSettings: debugCDefines + [
                .headerSearchPath("**"),
                .headerSearchPath("Server"),
                .headerSearchPath("Server/Category"),
                .headerSearchPath("Server/Connection"),
                .headerSearchPath("Server/Connection/RequestHandler"),
                .headerSearchPath("Server/Inspect"),
                .headerSearchPath("Server/Others"),
                .headerSearchPath("Server/Perspective"),
                .headerSearchPath("Shared"),
                .headerSearchPath("Shared/Category"),
                .headerSearchPath("Shared/Message"),
                .headerSearchPath("Shared/Peertalk"),
            ]
        ),
        .target(
            name: "LookinServerSwift",
            dependencies: ["LookinServerBase"],
            path: "Vendor/LookinServer/Src/Swift",
            cSettings: debugCDefines,
            swiftSettings: debugDefines + [
                .swiftLanguageMode(.v5),
            ]
        ),
        .target(
            name: "LookinServerBase",
            path: "Vendor/LookinServer/Src/Base",
            publicHeadersPath: "",
            cSettings: debugCDefines
        ),
    ],
    swiftLanguageModes: [.v5]
)
