import Foundation

/// Newline-delimited JSON-RPC over stdin/stdout, per the MCP stdio
/// transport. One message per line; messages must not contain embedded
/// newlines (our JSONEncoder default satisfies this).
///
/// Use:
///   let server = MCPServer(host: bridge)
///   try await StdioTransport().run(server: server)
public struct StdioTransport: Sendable {
    public init() {}

    public func run(server: MCPServer) async throws {
        let stdin = FileHandle.standardInput
        let stdout = FileHandle.standardOutput
        var buffer = Data()

        // Read in chunks rather than line-by-line so we don't block on a
        // partial line. We hand off complete lines to the server.
        while true {
            let chunk = try stdin.read(upToCount: 4096) ?? Data()
            if chunk.isEmpty {
                // EOF — peer closed stdin.
                return
            }
            buffer.append(chunk)

            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = buffer.subdata(in: buffer.startIndex..<nl)
                buffer.removeSubrange(buffer.startIndex...nl)
                if line.isEmpty { continue }

                if let reply = await server.handle(rawMessage: line) {
                    var out = Data(reply.utf8)
                    out.append(0x0A)
                    try stdout.write(contentsOf: out)
                }
            }
        }
    }
}
