//
//  MCPServer.swift
//  PromptBar
//
//  User-configured Model Context Protocol server. HTTP transport only
//  (sandbox-compatible). stdio transport is intentionally out of scope
//  for the App Store build, the user can run a stdio server locally and
//  expose it as HTTP if they want.
//

import Foundation

struct MCPServer: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var baseURL: String
    var authHeader: String       // e.g. "Bearer abc123" or "X-API-Key: ..."
    var enabled: Bool
    var symbolName: String
    var tintHex: String

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        authHeader: String = "",
        enabled: Bool = true,
        symbolName: String = "powerplug",
        tintHex: String = "#B96BFF"
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.authHeader = authHeader
        self.enabled = enabled
        self.symbolName = symbolName
        self.tintHex = tintHex
    }

    var url: URL? { URL(string: baseURL) }

    /// Keychain account name for the optional bearer token.
    var keychainAccount: String { "mcp.\(id.uuidString)" }

    static func sanitized(name: String, baseURL: String) -> MCPServer? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var u = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !u.isEmpty else { return nil }
        if !u.lowercased().hasPrefix("http://"), !u.lowercased().hasPrefix("https://") {
            u = "https://" + u
        }
        guard URL(string: u) != nil else { return nil }
        return MCPServer(name: n, baseURL: u)
    }
}
