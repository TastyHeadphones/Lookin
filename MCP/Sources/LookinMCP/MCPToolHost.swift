import Foundation

/// Abstract bridge the macOS app implements to expose Lookin's debugging
/// surface to MCP clients. Kept Foundation-only so the SwiftPM target has
/// no AppKit dependency — the concrete implementation lives in the app
/// target (see `LookinClient/MCP/LookinMCPBridge.swift`).
///
/// Every method is `async throws` so concrete implementations can hop to
/// the main actor when calling into UI-bound APIs without forcing this
/// protocol to be `@MainActor`.
public protocol MCPToolHost: Sendable {
    func listConnectedApps() async throws -> [ConnectedAppSummary]
    func connectToApp(appKey: String) async throws -> ConnectedAppSummary
    func listViewHierarchy(maxDepth: Int?) async throws -> [HierarchyNode]
    func inspectView(oid: UInt64) async throws -> ViewInspection
    func captureScreenshot() async throws -> ScreenshotData
    func refreshViewTree() async throws -> Int  // returns node count
    func exportSelectedLayer(format: ExportFormat) async throws -> ExportedLayer
}

public struct ConnectedAppSummary: Codable, Sendable, Equatable {
    public let appKey: String
    public let appName: String
    public let deviceName: String?
    public let isInspecting: Bool

    public init(appKey: String, appName: String, deviceName: String?, isInspecting: Bool) {
        self.appKey = appKey
        self.appName = appName
        self.deviceName = deviceName
        self.isInspecting = isInspecting
    }
}

public struct HierarchyNode: Codable, Sendable, Equatable {
    public let oid: UInt64
    public let className: String
    public let title: String?
    public let frame: CGRectCodable?
    public let depth: Int
    public let childCount: Int

    public init(oid: UInt64, className: String, title: String?, frame: CGRectCodable?, depth: Int, childCount: Int) {
        self.oid = oid; self.className = className; self.title = title
        self.frame = frame; self.depth = depth; self.childCount = childCount
    }
}

public struct CGRectCodable: Codable, Sendable, Equatable {
    public let x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

public struct ViewInspection: Codable, Sendable, Equatable {
    public let oid: UInt64
    public let className: String
    public let attributes: [String: String]

    public init(oid: UInt64, className: String, attributes: [String: String]) {
        self.oid = oid; self.className = className; self.attributes = attributes
    }
}

public struct ScreenshotData: Codable, Sendable, Equatable {
    public let mimeType: String
    public let base64: String

    public init(mimeType: String, base64: String) {
        self.mimeType = mimeType; self.base64 = base64
    }
}

public enum ExportFormat: String, Codable, Sendable {
    case json, png, lookin
}

public struct ExportedLayer: Codable, Sendable, Equatable {
    public let format: ExportFormat
    public let filename: String
    public let base64: String

    public init(format: ExportFormat, filename: String, base64: String) {
        self.format = format; self.filename = filename; self.base64 = base64
    }
}

/// Errors a host can raise. Translated to JSON-RPC errors by the server.
public enum MCPHostError: Error, Sendable, Equatable {
    case noAppConnected
    case unknownApp(String)
    case unknownView(UInt64)
    case notImplemented(String)
    case other(String)

    var message: String {
        switch self {
        case .noAppConnected: return "No iOS app is currently connected to Lookin"
        case .unknownApp(let k): return "No connected app with key \(k)"
        case .unknownView(let o): return "No view with oid \(o) in the current hierarchy"
        case .notImplemented(let n): return "Tool \(n) is not implemented in this build"
        case .other(let m): return m
        }
    }
}
