import Foundation

/// Minimal JSON-RPC 2.0 envelope types used by the MCP transport.
///
/// We use `JSONValue` rather than `Any` so the types stay `Sendable` and
/// `Codable` without bridging through `NSDictionary` — important for the
/// Swift 6 migration in slice D.

public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unrecognised JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o } else { return nil }
    }
    public var stringValue: String? {
        if case .string(let s) = self { return s } else { return nil }
    }
    public var intValue: Int? {
        switch self {
        case .int(let v): return v
        case .double(let v): return Int(v)
        default: return nil
        }
    }
}

public struct JSONRPCRequest: Codable, Sendable {
    public let jsonrpc: String
    public let id: JSONValue?
    public let method: String
    public let params: JSONValue?

    public init(id: JSONValue?, method: String, params: JSONValue?) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct JSONRPCError: Codable, Sendable, Error {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code; self.message = message; self.data = data
    }

    public static let parseError      = JSONRPCError(code: -32700, message: "Parse error")
    public static let invalidRequest  = JSONRPCError(code: -32600, message: "Invalid request")
    public static let methodNotFound  = JSONRPCError(code: -32601, message: "Method not found")
    public static let invalidParams   = JSONRPCError(code: -32602, message: "Invalid params")
    public static let internalError   = JSONRPCError(code: -32603, message: "Internal error")
}

public struct JSONRPCResponse: Codable, Sendable {
    public let jsonrpc: String
    public let id: JSONValue?
    public let result: JSONValue?
    public let error: JSONRPCError?

    public init(id: JSONValue?, result: JSONValue) {
        self.jsonrpc = "2.0"; self.id = id; self.result = result; self.error = nil
    }
    public init(id: JSONValue?, error: JSONRPCError) {
        self.jsonrpc = "2.0"; self.id = id; self.result = nil; self.error = error
    }
}
