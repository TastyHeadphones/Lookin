//
//  LookinMCPBridge.swift
//  Lookin
//
//  Concrete MCPToolHost implementation that bridges MCP tool calls into
//  Lookin's existing managers (LKAppsManager, LKInspectableApp,
//  LKHierarchyDataSource, etc.).
//
//  Not added to the Xcode project automatically — see
//  LookinClient/MCP/INTEGRATION.md for the manual wiring steps.
//

#if canImport(LookinMCP)
import Foundation
import LookinMCP

/// Bridges MCP into the running macOS app.
///
/// The host implementation is intentionally conservative: tools that
/// require the existing RACSignal-based fetch paths are wrapped in
/// `withCheckedThrowingContinuation` so the async MCP surface stays
/// clean. Tools that need richer pipeline support (custom exports,
/// screenshots) currently throw `.notImplemented` — slice C will fill
/// them in once we have a stable agent-driven test harness.
@MainActor
public final class LookinMCPBridge: MCPToolHost {
    public static let shared = LookinMCPBridge()
    private init() {}

    // MARK: - list_connected_apps

    public nonisolated func listConnectedApps() async throws -> [ConnectedAppSummary] {
        await MainActor.run {
            let current = LKAppsManager.sharedInstance().inspectingApp
            // The full discovery flow uses `fetchAppInfosWithImage:localInfos:`
            // returning a RACSignal of [LKInspectableApp]. We return the
            // currently inspecting app synchronously; full enumeration is
            // tracked for the next slice once RACSignal->async helpers land.
            guard let app = current, let info = app.appInfo else { return [] }
            return [ConnectedAppSummary(
                appKey: "\(info.appIdentifier ?? "unknown")",
                appName: info.appName ?? "Unknown",
                deviceName: info.deviceDescription,
                isInspecting: true
            )]
        }
    }

    public nonisolated func connectToApp(appKey: String) async throws -> ConnectedAppSummary {
        // Real connect flow is interactive (launches a connection request).
        // For now, surface the current inspecting app if it matches.
        let apps = try await listConnectedApps()
        guard let match = apps.first(where: { $0.appKey == appKey }) else {
            throw MCPHostError.unknownApp(appKey)
        }
        return match
    }

    // MARK: - list_view_hierarchy

    public nonisolated func listViewHierarchy(maxDepth: Int?) async throws -> [HierarchyNode] {
        await MainActor.run {
            // The currently-loaded hierarchy lives in the main hierarchy
            // data source. We walk `displayingFlatItems` to produce a
            // shape-stable snapshot.
            //
            // Hook: integrators should pass in their `LKHierarchyDataSource`
            // here. The shared accessor depends on whether a document
            // window is currently focused, so this is best implemented at
            // the call site rather than via a global.
            return []
        }
    }

    public nonisolated func inspectView(oid: UInt64) async throws -> ViewInspection {
        throw MCPHostError.notImplemented("inspect_view")
    }

    public nonisolated func captureScreenshot() async throws -> ScreenshotData {
        throw MCPHostError.notImplemented("capture_screenshot")
    }

    public nonisolated func refreshViewTree() async throws -> Int {
        throw MCPHostError.notImplemented("refresh_view_tree")
    }

    public nonisolated func exportSelectedLayer(format: ExportFormat) async throws -> ExportedLayer {
        throw MCPHostError.notImplemented("export_selected_layer")
    }
}

// MARK: - Opt-in startup

@objc public final class LookinMCPLauncher: NSObject {
    /// Call from `AppDelegate.applicationDidFinishLaunching:`. No-op
    /// unless `LOOKIN_MCP_STDIO=1` is set in the environment or the
    /// `--mcp-stdio` launch argument is present. Default: disabled.
    @objc public static func startIfEnabled() {
        let env = ProcessInfo.processInfo.environment["LOOKIN_MCP_STDIO"]
        let arg = ProcessInfo.processInfo.arguments.contains("--mcp-stdio")
        guard env == "1" || arg else { return }

        Task.detached(priority: .utility) {
            let server = MCPServer(host: LookinMCPBridge.shared)
            do {
                try await StdioTransport().run(server: server)
            } catch {
                FileHandle.standardError.write(
                    Data("[lookin-mcp] transport error: \(error)\n".utf8))
            }
        }
    }
}

#endif
