# Lookin MCP server

Lookin can expose its iOS-view-debugging surface to AI agents via the
[Model Context Protocol](https://modelcontextprotocol.io). The server
runs **inside the macOS Lookin app**, speaks JSON-RPC 2.0 over stdio,
and is **disabled by default**.

## Enabling

The server is opt-in per launch. Both forms below work:

```sh
LOOKIN_MCP_STDIO=1 /Applications/Lookin.app/Contents/MacOS/Lookin
/Applications/Lookin.app/Contents/MacOS/Lookin --mcp-stdio
```

When neither the environment variable nor the launch argument is set,
no MCP code runs and no extra threads are spawned. Release builds with
no opt-in are observationally identical to a normal Lookin launch.

## Transport

- **Encoding**: UTF-8 newline-delimited JSON. One message per line. No
  Content-Length framing.
- **stdin**: requests / notifications from the client.
- **stdout**: responses / server-initiated notifications.
- **stderr**: human-readable diagnostics. Never JSON-RPC.

Network transports (HTTP, Unix sockets, SSE) are intentionally not
enabled. Adding one would expose Lookin's debugging surface to anything
that can reach the host, which has not been threat-modelled. Local
agent integration is the only supported path today.

## Lifecycle

```jsonc
// client → server
{"jsonrpc":"2.0","id":1,"method":"initialize"}
// server → client
{"jsonrpc":"2.0","id":1,"result":{
  "protocolVersion":"2024-11-05",
  "capabilities":{"tools":{"listChanged":false}},
  "serverInfo":{"name":"lookin-mcp","version":"0.1.0"}
}}

// client → server (notification, no id)
{"jsonrpc":"2.0","method":"notifications/initialized"}
```

## Tools

| name | summary |
|---|---|
| `list_connected_apps` | List iOS apps currently reachable via LookinServer. |
| `connect_to_app` | Make a specific app the active inspection target. |
| `list_view_hierarchy` | Flat list of the current view hierarchy. |
| `inspect_view` | Attributes for a single view by oid. |
| `capture_screenshot` | PNG screenshot of the inspected app. |
| `refresh_view_tree` | Re-fetch the hierarchy from the device. |
| `export_selected_layer` | Export the selected layer as json / png / lookin. |

Discover with `tools/list`:

```jsonc
// →
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
// ←
{"jsonrpc":"2.0","id":2,"result":{"tools":[
  {"name":"list_connected_apps","description":"...","inputSchema":{...}},
  ...
]}}
```

Call with `tools/call`:

```jsonc
// →
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{
  "name":"list_view_hierarchy",
  "arguments":{"maxDepth":3}
}}
// ←
{"jsonrpc":"2.0","id":3,"result":{
  "content":[{"type":"text","text":"42 nodes"}],
  "structuredContent":[{"oid":1,"className":"UIWindow","depth":0,...}],
  "isError":false
}}
```

### Error semantics

| code | meaning |
|---:|---|
| `-32700` | Parse error (malformed JSON) |
| `-32600` | Invalid request |
| `-32601` | Method or tool name unknown |
| `-32602` | Required parameter missing or wrong type |
| `-32603` | Internal server error |
| `-32000` | Host-level error (no app connected, unknown oid, not implemented) |

## Security boundaries

- **No network**: stdio only. The app does not bind any socket on
  behalf of MCP.
- **Opt-in**: server is off by default; no env var → no MCP.
- **Process-local trust**: anything that can write to the Lookin
  process's stdin can issue tool calls. Run only under agents you
  trust.
- **No remote code execution**: tools are limited to the catalog above.
  `tools/call` cannot invoke arbitrary selectors, eval scripts, or
  mutate device state beyond what the existing GUI affordances expose.

## Implementation status

The protocol layer and tool catalog are complete and unit-tested under
`MCP/Tests/LookinMCPTests`. The in-app bridge
(`LookinClient/MCP/LookinMCPBridge.swift`) currently exposes
`list_connected_apps` and `connect_to_app` against the live
`LKAppsManager`; the remaining five tools return a `notImplemented`
host error pending the RACSignal-to-async helpers needed to wrap
`fetchHierarchyData` and `fetchImageWithImageViewOid:` cleanly. The
shape of `tools/list` and the JSON-RPC error semantics will not change
when those land.
