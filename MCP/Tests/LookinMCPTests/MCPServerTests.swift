import XCTest
@testable import LookinMCP

final class MCPServerTests: XCTestCase {
    private func makeServer() -> MCPServer {
        MCPServer(host: InMemoryMCPHost())
    }

    private func send(_ json: String, to server: MCPServer) async -> [String: Any]? {
        guard let data = json.data(using: .utf8),
              let reply = await server.handle(rawMessage: data),
              let replyData = reply.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: replyData) as? [String: Any]
        else { return nil }
        return parsed
    }

    func testInitializeHandshake() async throws {
        let server = makeServer()
        let reply = await send(#"{"jsonrpc":"2.0","id":1,"method":"initialize"}"#, to: server)
        XCTAssertEqual(reply?["jsonrpc"] as? String, "2.0")
        let result = reply?["result"] as? [String: Any]
        XCTAssertEqual(result?["protocolVersion"] as? String, MCPServer.protocolVersion)
        let info = result?["serverInfo"] as? [String: Any]
        XCTAssertEqual(info?["name"] as? String, MCPServer.serverName)
    }

    func testToolsListReturnsAllSevenTools() async throws {
        let server = makeServer()
        let reply = await send(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#, to: server)
        let result = reply?["result"] as? [String: Any]
        let tools = result?["tools"] as? [[String: Any]]
        XCTAssertEqual(tools?.count, 7)
        let names = Set(tools?.compactMap { $0["name"] as? String } ?? [])
        XCTAssertEqual(names, [
            "list_connected_apps", "connect_to_app", "list_view_hierarchy",
            "inspect_view", "capture_screenshot", "refresh_view_tree",
            "export_selected_layer",
        ])
    }

    func testToolsCallListConnectedApps() async throws {
        let server = makeServer()
        let req = #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_connected_apps","arguments":{}}}"#
        let reply = await send(req, to: server)
        let result = reply?["result"] as? [String: Any]
        let content = result?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.first?["type"] as? String, "text")
        let structured = result?["structuredContent"] as? [[String: Any]]
        XCTAssertEqual(structured?.count, 2)
        XCTAssertEqual(structured?.first?["appName"] as? String, "DemoApp")
    }

    func testToolsCallInspectViewUnknownOidIsHostError() async throws {
        let server = makeServer()
        let req = #"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"inspect_view","arguments":{"oid":999}}}"#
        let reply = await send(req, to: server)
        let error = reply?["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? Int, -32000)
        XCTAssertTrue((error?["message"] as? String ?? "").contains("oid 999"))
    }

    func testToolsCallMissingRequiredArgIsInvalidParams() async throws {
        let server = makeServer()
        let req = #"{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"connect_to_app","arguments":{}}}"#
        let reply = await send(req, to: server)
        let error = reply?["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? Int, -32602)
    }

    func testUnknownMethodIsMethodNotFound() async throws {
        let server = makeServer()
        let reply = await send(#"{"jsonrpc":"2.0","id":6,"method":"does_not_exist"}"#, to: makeServer())
        _ = server
        let error = reply?["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? Int, -32601)
    }

    func testNotificationProducesNoReply() async throws {
        let server = makeServer()
        let data = #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#.data(using: .utf8)!
        let reply = await server.handle(rawMessage: data)
        XCTAssertNil(reply)
    }

    func testMalformedJSONReturnsParseError() async throws {
        let server = makeServer()
        let reply = await send("not json", to: server)
        let error = reply?["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? Int, -32700)
    }
}
