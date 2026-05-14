import Foundation

/// A single MCP tool: name, schema, and the dispatcher that turns
/// JSON arguments into a host call and the host result back into JSON.
public struct LookinTool: Sendable {
    public let name: String
    public let description: String
    public let inputSchema: JSONValue
    public let invoke: @Sendable (_ host: MCPToolHost, _ arguments: [String: JSONValue]) async throws -> ToolPayload

    public var descriptor: JSONValue {
        .object([
            "name": .string(name),
            "description": .string(description),
            "inputSchema": inputSchema,
        ])
    }
}

public struct ToolPayload: Sendable {
    public let text: String         // human-readable summary
    public let structured: JSONValue // machine-readable result

    public init(text: String, structured: JSONValue) {
        self.text = text; self.structured = structured
    }
}

public enum LookinTools {
    public static let all: [LookinTool] = [
        listConnectedApps,
        connectToApp,
        listViewHierarchy,
        inspectView,
        captureScreenshot,
        refreshViewTree,
        exportSelectedLayer,
    ]

    public static let byName: [String: LookinTool] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })

    // MARK: list_connected_apps

    static let listConnectedApps = LookinTool(
        name: "list_connected_apps",
        description: "List iOS apps currently reachable via LookinServer.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "additionalProperties": .bool(false),
        ]),
        invoke: { host, _ in
            let apps = try await host.listConnectedApps()
            let json = try encodeToJSON(apps)
            let text = apps.isEmpty
                ? "No connected apps."
                : apps.map { "- \($0.appName) [\($0.appKey)]\($0.isInspecting ? " (inspecting)" : "")" }
                      .joined(separator: "\n")
            return ToolPayload(text: text, structured: json)
        }
    )

    // MARK: connect_to_app

    static let connectToApp = LookinTool(
        name: "connect_to_app",
        description: "Make a specific app the active inspection target.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "appKey": .object([
                    "type": .string("string"),
                    "description": .string("Identifier from list_connected_apps"),
                ]),
            ]),
            "required": .array([.string("appKey")]),
            "additionalProperties": .bool(false),
        ]),
        invoke: { host, args in
            guard let key = args["appKey"]?.stringValue else { throw JSONRPCError.invalidParams }
            let app = try await host.connectToApp(appKey: key)
            return ToolPayload(text: "Connected to \(app.appName)",
                               structured: try encodeToJSON(app))
        }
    )

    // MARK: list_view_hierarchy

    static let listViewHierarchy = LookinTool(
        name: "list_view_hierarchy",
        description: "Return a flat list of the current view hierarchy nodes.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "maxDepth": .object([
                    "type": .string("integer"),
                    "description": .string("Optional cap on tree depth"),
                ]),
            ]),
            "additionalProperties": .bool(false),
        ]),
        invoke: { host, args in
            let depth = args["maxDepth"]?.intValue
            let nodes = try await host.listViewHierarchy(maxDepth: depth)
            return ToolPayload(text: "\(nodes.count) nodes", structured: try encodeToJSON(nodes))
        }
    )

    // MARK: inspect_view

    static let inspectView = LookinTool(
        name: "inspect_view",
        description: "Fetch attributes for a single view by its oid.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "oid": .object([
                    "type": .string("integer"),
                    "description": .string("View identifier returned by list_view_hierarchy"),
                ]),
            ]),
            "required": .array([.string("oid")]),
            "additionalProperties": .bool(false),
        ]),
        invoke: { host, args in
            guard let oid = args["oid"]?.intValue else { throw JSONRPCError.invalidParams }
            let view = try await host.inspectView(oid: UInt64(oid))
            return ToolPayload(text: "\(view.className) (oid \(view.oid))",
                               structured: try encodeToJSON(view))
        }
    )

    // MARK: capture_screenshot

    static let captureScreenshot = LookinTool(
        name: "capture_screenshot",
        description: "Capture a screenshot of the currently inspected app.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "additionalProperties": .bool(false),
        ]),
        invoke: { host, _ in
            let shot = try await host.captureScreenshot()
            return ToolPayload(text: "\(shot.mimeType), \(shot.base64.count) base64 chars",
                               structured: try encodeToJSON(shot))
        }
    )

    // MARK: refresh_view_tree

    static let refreshViewTree = LookinTool(
        name: "refresh_view_tree",
        description: "Re-fetch the view hierarchy from the connected app.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "additionalProperties": .bool(false),
        ]),
        invoke: { host, _ in
            let count = try await host.refreshViewTree()
            return ToolPayload(text: "Refreshed, \(count) nodes",
                               structured: .object(["nodeCount": .int(count)]))
        }
    )

    // MARK: export_selected_layer

    static let exportSelectedLayer = LookinTool(
        name: "export_selected_layer",
        description: "Export the currently selected layer as JSON, PNG, or .lookin.",
        inputSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "format": .object([
                    "type": .string("string"),
                    "enum": .array([.string("json"), .string("png"), .string("lookin")]),
                ]),
            ]),
            "required": .array([.string("format")]),
            "additionalProperties": .bool(false),
        ]),
        invoke: { host, args in
            guard let raw = args["format"]?.stringValue,
                  let fmt = ExportFormat(rawValue: raw) else { throw JSONRPCError.invalidParams }
            let result = try await host.exportSelectedLayer(format: fmt)
            return ToolPayload(text: "Exported \(result.filename) (\(result.format.rawValue))",
                               structured: try encodeToJSON(result))
        }
    )
}

/// Encode an Encodable value to our `JSONValue` representation by
/// round-tripping through `Data`. Keeps tool implementations terse.
func encodeToJSON<T: Encodable>(_ value: T) throws -> JSONValue {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(JSONValue.self, from: data)
}
