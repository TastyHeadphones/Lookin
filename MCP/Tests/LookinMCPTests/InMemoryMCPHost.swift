import Foundation
@testable import LookinMCP

actor InMemoryMCPHost: MCPToolHost {
    var apps: [ConnectedAppSummary] = [
        .init(appKey: "demo-1", appName: "DemoApp", deviceName: "iPhone 15", isInspecting: true),
        .init(appKey: "demo-2", appName: "OtherApp", deviceName: "iPhone 15", isInspecting: false),
    ]
    var inspecting = "demo-1"
    var hierarchy: [HierarchyNode] = [
        .init(oid: 1, className: "UIWindow", title: nil,
              frame: .init(x: 0, y: 0, width: 393, height: 852), depth: 0, childCount: 1),
        .init(oid: 2, className: "UIView", title: "root",
              frame: .init(x: 0, y: 0, width: 393, height: 852), depth: 1, childCount: 0),
    ]

    func listConnectedApps() async throws -> [ConnectedAppSummary] { apps }

    func connectToApp(appKey: String) async throws -> ConnectedAppSummary {
        guard let app = apps.first(where: { $0.appKey == appKey }) else {
            throw MCPHostError.unknownApp(appKey)
        }
        inspecting = appKey
        return app
    }

    func listViewHierarchy(maxDepth: Int?) async throws -> [HierarchyNode] {
        if let cap = maxDepth { return hierarchy.filter { $0.depth <= cap } }
        return hierarchy
    }

    func inspectView(oid: UInt64) async throws -> ViewInspection {
        guard let node = hierarchy.first(where: { $0.oid == oid }) else {
            throw MCPHostError.unknownView(oid)
        }
        return .init(oid: node.oid, className: node.className,
                     attributes: ["title": node.title ?? "", "depth": "\(node.depth)"])
    }

    func captureScreenshot() async throws -> ScreenshotData {
        .init(mimeType: "image/png", base64: "iVBORw0KGgo=")
    }

    func refreshViewTree() async throws -> Int { hierarchy.count }

    func exportSelectedLayer(format: ExportFormat) async throws -> ExportedLayer {
        .init(format: format, filename: "selected.\(format.rawValue)", base64: "ZXhwb3J0")
    }
}
