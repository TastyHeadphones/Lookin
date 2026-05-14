# Contributing

## Repository layout

```
Lookin/
├── Lookin.xcworkspace            # macOS app workspace (uses CocoaPods)
├── Lookin.xcodeproj              # macOS app project
├── LookinClient/                 # macOS app sources (ObjC + Swift)
│   └── MCP/                      # in-app MCP bridge (Swift)
├── Package.swift                 # iOS SPM manifest for LookinServer
├── Vendor/LookinServer/          # git submodule, pinned to LookinServer 1.2.7
├── MCP/                          # nested SwiftPM package: macOS MCP server
│   ├── Package.swift
│   ├── Sources/LookinMCP/
│   └── Tests/LookinMCPTests/
├── Casks/lookin.rb               # reference Homebrew Cask (publish via tap repo)
├── .github/workflows/
│   ├── ci.yml                    # SPM resolve, iOS-sim build, MCP tests, unsigned macOS build
│   └── release.yml               # signed + notarized macOS app, GitHub Release
└── Docs/
    ├── mcp.md                    # MCP protocol + tool catalog
    ├── homebrew.md               # tap setup
    └── release.md                # release checklist
```

## Initial clone

```sh
git clone --recurse-submodules https://github.com/TastyHeadphones/Lookin.git
cd Lookin
```

If you forgot `--recurse-submodules`:

```sh
git submodule update --init --recursive
```

## Tooling

- **Xcode 16+** for the macOS app and Swift 6 work.
- **CocoaPods** for the macOS app dependencies (`gem install cocoapods`).
- **Ruby 3.2+** if you're touching the Cask (`brew style Casks/lookin.rb`).

## Building each piece

### iOS LookinServer (via SPM)

```sh
swift package resolve
xcodebuild -scheme LookinServer \
  -destination 'generic/platform=iOS Simulator' build
```

### LookinMCP (macOS library + tests)

```sh
cd MCP
swift build
swift test --parallel
```

The MCP package is **Swift 6 language mode** with strict concurrency
enabled. Anything you add here should compile cleanly without
`@unchecked Sendable` workarounds.

### macOS Lookin app

```sh
pod install
open Lookin.xcworkspace
# Or from the command line:
xcodebuild -workspace Lookin.xcworkspace \
  -scheme LookinClient \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

The app target is currently on **`SWIFT_VERSION = 5.0`**. See
[MIGRATION.md](MIGRATION.md) for the per-file Swift 6 migration plan.

## Tests

```sh
# MCP unit tests (the substantive automated suite right now)
cd MCP && swift test --parallel

# macOS app — no test target wired up yet
```

If you add Swift code under `LookinClient/`, prefer XCTest in a new
target rather than the ad-hoc `_runTests` hook in `AppDelegate.m`.

## Pull request checklist

- [ ] `swift test` in `MCP/` passes.
- [ ] `xcodebuild` succeeds for both the iOS LookinServer scheme and
      the macOS LookinClient scheme.
- [ ] No new `@unchecked Sendable` or `nonisolated(unsafe)` without an
      inline comment explaining the invariant.
- [ ] If you touch the Cask or release flow, update [Docs/release.md](Docs/release.md).
- [ ] If you change the MCP wire protocol, update [Docs/mcp.md](Docs/mcp.md).
- [ ] License headers preserved on any file copied from upstream
      `QMUI/LookinServer`. We vendor those sources via submodule
      precisely so we don't have to manage license headers — if you
      find yourself copy-pasting upstream code, push the change into
      the submodule instead.

## Updating the vendored LookinServer

```sh
cd Vendor/LookinServer
git fetch origin
git checkout <new-commit-or-tag>
cd ../..
git add Vendor/LookinServer
git commit -m "vendor: LookinServer <version>"
```

Re-run `swift package resolve` and `swift build` for the root
`Package.swift` to make sure the header search paths still match —
they're declared explicitly in our manifest so a new file landing in a
new subdirectory may need a new `.headerSearchPath(...)` entry.

## Reporting issues

- Bugs in the **macOS app** → this repo's issues.
- Bugs in the **iOS LookinServer** core → consider whether they
  reproduce upstream at `QMUI/LookinServer` first; pure-iOS issues
  belong there. Bugs that only appear under this fork's manifest /
  Swift 6 mode / iOS 16 floor belong here.
- Bugs in **MCP** → this repo's issues, tagged `mcp`.

## Code style

- Objective-C: match the existing style in `LookinClient/`. Header
  comments preserved as-is.
- Swift: standard SwiftLint defaults would be fine but a linter is not
  wired up yet. Don't add one in a drive-by — open an issue first.
