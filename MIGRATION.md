# Migration guide

This fork modernizes the Lookin + LookinServer codebase. The notes
below cover what moved, what to change in your iOS project to consume
the new SPM package, and where Swift 6 / iOS 16 / macOS 13 floors land.

## Floor versions

| Component | Floor | Why |
|---|---|---|
| `LookinServer` (iOS lib) | **iOS 16** | Set in [Package.swift](Package.swift). |
| `Lookin.app` (macOS) | **macOS 13** | Set in `Lookin.xcodeproj` and `Podfile`. Matches the Homebrew Cask's `depends_on macos: ">= :ventura"`. |
| `LookinMCP` (macOS lib) | **macOS 13** | Set in [MCP/Package.swift](MCP/Package.swift). |

## From CocoaPods to SPM

The old integration:

```ruby
# Podfile
pod 'LookinServer', :subspecs => ['Swift'], :configurations => ['Debug']
```

The new integration via this fork:

```swift
// Package.swift consumer
.package(url: "https://github.com/TastyHeadphones/Lookin.git", branch: "Develop"),
```

```swift
// Target dependency
.product(name: "LookinServer", package: "Lookin"),
```

```swift
// In your code
#if DEBUG
import LookinServer
LookinServer.shared.start()  // or however your app entry-point initialises it
#endif
```

The package uses upstream's `SHOULD_COMPILE_LOOKIN_SERVER` define gated
on the SPM `.debug` configuration, so **Release builds will not include
the server code** even if you skip the `#if DEBUG` wrapper. The
explicit `#if DEBUG` is still recommended as belt-and-braces.

You can keep consuming upstream directly
(`https://github.com/QMUI/LookinServer/`) if you don't need this
fork's iOS 16 floor or Swift 6 work. Both manifests target the same
underlying sources via the submodule at `Vendor/LookinServer`.

## Swift 6 status

| Module | Swift language mode | Notes |
|---|---|---|
| `LookinMCP` | **6.0** | Written Sendable-first; covered by unit tests. |
| `LookinServer` (ObjC) | n/a | Pure Objective-C. |
| `LookinServerSwift` | 5.0 | One file (`LKS_SwiftTraceManager.swift`). Single-threaded mirror-walk code — likely Swift-6-clean, but touches `UIView` / `UIViewController` which became `@MainActor`-isolated in the iOS 18 SDK. Flip to `.v6` once you've verified it compiles in Xcode 16. |
| `LookinClient` (macOS app) | 5.0 | Per-file `SWIFT_VERSION = 5.0` in `Lookin.xcodeproj`. Flipping to 6.0 is a per-file effort across the app target — start with leaf files and use `@preconcurrency` imports for ReactiveObjC, which is not Sendable-aware. The recommended order: |
| | | 1. Set `SWIFT_VERSION = 6.0` on one Swift file at a time via Xcode's File Inspector. |
| | | 2. For files that use ReactiveObjC, add `@preconcurrency import ReactiveObjC` at the top — the framework predates Sendable and is not getting annotated upstream. |
| | | 3. For `LKHelper` and other globals accessed from the main thread, prefer `@MainActor` over `nonisolated(unsafe)`. |
| | | 4. Treat any `@unchecked Sendable` as a TODO; leave a comment explaining what guarantees the unchecked claim. |

## Building

```sh
# Resolve and build the iOS SPM package
swift package resolve
xcodebuild -scheme LookinServer -destination 'generic/platform=iOS Simulator' build

# Build the MCP package (macOS)
cd MCP && swift build && swift test

# Build the macOS app (after pod install)
pod install
xcodebuild -workspace Lookin.xcworkspace -scheme LookinClient -destination 'platform=macOS' build
```

`pod install` still uses the existing `LookinShared` pod from
`QMUI/LookinServer`. Migrating the macOS app off CocoaPods is a
separate future task — it would mean wiring the same sources via SPM
into the Xcode project, which is straightforward but invasive.

## Known follow-ups

- `LookinClient/MCP/LookinMCPBridge.swift` only implements
  `list_connected_apps` and `connect_to_app` against the live
  managers. The other five MCP tools return `MCPHostError.notImplemented`
  until RACSignal-to-async helpers land for `fetchHierarchyData`,
  `fetchImageWithImageViewOid:`, and the focused-document hierarchy
  accessor.
- The macOS app target's `SWIFT_VERSION` stays at `5.0`; the per-file
  flip is best done from inside Xcode 16 with the build feedback loop.
- `Lookin.xcodeproj` still has `Pods.xcodeproj` referenced from the
  workspace. Migrating to SPM-in-Xcode would remove the dual-project
  workspace and the `post_install` hook in `Podfile`.
