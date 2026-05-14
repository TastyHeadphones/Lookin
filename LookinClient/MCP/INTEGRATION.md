# Wiring MCP into the Lookin Xcode project

The MCP server is built as a separate Swift Package at `MCP/Package.swift`
and is **not** added to `Lookin.xcodeproj` automatically — `project.pbxproj`
edits are easy to corrupt outside of Xcode, so this step is manual.

## One-time setup

1. Open `Lookin.xcworkspace` in Xcode 16+.
2. **File → Add Package Dependencies… → Add Local…**
   Select the `MCP/` directory at the repo root.
3. In the dialog, add the `LookinMCP` product to the **LookinClient** target.
4. Drag `LookinClient/MCP/LookinMCPBridge.swift` into the LookinClient
   group in the navigator. Check **LookinClient** in "Add to targets".
5. Edit `LookinClient/AppDelegate.m`:

   ```objc
   #import "Lookin-Swift.h"  // already imported in most files

   - (void)applicationDidFinishLaunching:(NSNotification *)note {
       // …existing code…
       [LookinMCPLauncher startIfEnabled];
   }
   ```

## Running it

The server is **off by default**. Enable it per-launch:

```sh
LOOKIN_MCP_STDIO=1 /Applications/Lookin.app/Contents/MacOS/Lookin
# or
/Applications/Lookin.app/Contents/MacOS/Lookin --mcp-stdio
```

When enabled, the app reads newline-delimited JSON-RPC 2.0 from stdin
and writes responses to stdout. See `Docs/mcp.md` for the wire protocol
and tool catalog.

## Verifying

With the launcher wired in but the env var unset, launching Lookin
normally must show no MCP activity (no stdout chatter, no extra
threads). The unit tests in `MCP/Tests/LookinMCPTests` cover the
protocol layer without the GUI.
