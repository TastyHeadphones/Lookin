import Foundation

/// MCP server implementing the subset of the spec we need:
///   - initialize         (handshake)
///   - notifications/initialized
///   - tools/list         (advertise the 7 Lookin tools)
///   - tools/call         (dispatch by name into MCPToolHost)
///   - ping
///
/// The server is transport-agnostic — feed it raw JSON-RPC request
/// strings, get back response strings. `StdioTransport` is the default
/// transport for local-agent use.
public actor MCPServer {
    public static let protocolVersion = "2024-11-05"
    public static let serverName = "lookin-mcp"
    public static let serverVersion = "0.1.0"

    private let host: MCPToolHost
    private var didInitialize = false

    public init(host: MCPToolHost) {
        self.host = host
    }

    /// Process one incoming JSON-RPC message. Returns the response JSON
    /// as a UTF-8 string, or `nil` if the message was a notification
    /// (notifications get no reply per JSON-RPC 2.0).
    public func handle(rawMessage data: Data) async -> String? {
        let decoder = JSONDecoder()
        let request: JSONRPCRequest
        do {
            request = try decoder.decode(JSONRPCRequest.self, from: data)
        } catch {
            return Self.encode(JSONRPCResponse(id: nil, error: .parseError))
        }
        return await handle(request: request)
    }

    func handle(request: JSONRPCRequest) async -> String? {
        let isNotification = request.id == nil

        do {
            let result = try await dispatch(method: request.method, params: request.params)
            if isNotification { return nil }
            return Self.encode(JSONRPCResponse(id: request.id, result: result))
        } catch let err as JSONRPCError {
            if isNotification { return nil }
            return Self.encode(JSONRPCResponse(id: request.id, error: err))
        } catch let err as MCPHostError {
            if isNotification { return nil }
            return Self.encode(JSONRPCResponse(id: request.id, error:
                JSONRPCError(code: -32000, message: err.message)))
        } catch {
            if isNotification { return nil }
            return Self.encode(JSONRPCResponse(id: request.id, error:
                JSONRPCError(code: -32603, message: "Internal error: \(error)")))
        }
    }

    private func dispatch(method: String, params: JSONValue?) async throws -> JSONValue {
        switch method {
        case "initialize":
            didInitialize = true
            return .object([
                "protocolVersion": .string(Self.protocolVersion),
                "capabilities": .object([
                    "tools": .object(["listChanged": .bool(false)]),
                ]),
                "serverInfo": .object([
                    "name": .string(Self.serverName),
                    "version": .string(Self.serverVersion),
                ]),
            ])

        case "notifications/initialized":
            return .null  // notification, no result returned to client

        case "ping":
            return .object([:])

        case "tools/list":
            return .object(["tools": .array(LookinTools.all.map { $0.descriptor })])

        case "tools/call":
            guard let obj = params?.objectValue,
                  let name = obj["name"]?.stringValue else {
                throw JSONRPCError.invalidParams
            }
            let args = obj["arguments"]?.objectValue ?? [:]
            return try await callTool(name: name, arguments: args)

        default:
            throw JSONRPCError.methodNotFound
        }
    }

    private func callTool(name: String, arguments: [String: JSONValue]) async throws -> JSONValue {
        guard let tool = LookinTools.byName[name] else {
            throw JSONRPCError(code: -32601, message: "Unknown tool: \(name)")
        }
        let payload = try await tool.invoke(host: host, arguments: arguments)
        return .object([
            "content": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(payload.text),
                ])
            ]),
            "isError": .bool(false),
            "structuredContent": payload.structured,
        ])
    }

    static func encode<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(value),
              let s = String(data: data, encoding: .utf8) else {
            return #"{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"encode failed"}}"#
        }
        return s
    }
}
