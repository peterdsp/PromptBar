//
//  MCPClient.swift
//  PromptBar
//
//  Minimal HTTP JSON-RPC 2.0 client for Model Context Protocol servers.
//  Implements the subset PromptBar needs today (listTools, callTool).
//  The streaming-tool-call loop inside NativeChatView is the next step,
//  this file provides the surface that loop will call.
//

import Foundation

enum MCPError: LocalizedError {
    case invalidURL
    case http(status: Int, body: String)
    case rpc(code: Int, message: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The MCP server URL is invalid."
        case .http(let s, let b):
            return "HTTP \(s)\(b.isEmpty ? "" : ": \(b.prefix(180))")"
        case .rpc(let c, let m):
            return "RPC \(c): \(m)"
        case .decoding(let m):
            return "Couldn't parse the response: \(m)"
        }
    }
}

struct MCPTool: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let description: String?
    let inputSchema: [String: AnyDecodable]?
}

/// Wrapper so we can decode arbitrary JSON Schema objects without modeling them.
struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self) { value = v; return }
        if let v = try? c.decode(Int.self) { value = v; return }
        if let v = try? c.decode(Double.self) { value = v; return }
        if let v = try? c.decode(String.self) { value = v; return }
        if let v = try? c.decode([AnyDecodable].self) { value = v.map(\.value); return }
        if let v = try? c.decode([String: AnyDecodable].self) {
            value = v.mapValues(\.value); return
        }
        if c.decodeNil() { value = NSNull(); return }
        throw DecodingError.dataCorruptedError(
            in: c, debugDescription: "Unknown JSON value")
    }
}

struct MCPClient {
    let server: MCPServer

    func listTools() async throws -> [MCPTool] {
        let result = try await request(method: "tools/list", params: nil)
        guard case .object(let dict) = result,
              case .array(let arr) = dict["tools"] ?? .null else {
            return []
        }
        let data = try JSONSerialization.data(withJSONObject: arr.map(\.asAny))
        return try JSONDecoder().decode([MCPTool].self, from: data)
    }

    func callTool(name: String, arguments: [String: Any]) async throws -> Any {
        let params: JSONValue = .object([
            "name": .string(name),
            "arguments": JSONValue(fromAny: arguments)
        ])
        let result = try await request(method: "tools/call", params: params)
        return result.asAny
    }

    // MARK: - JSON-RPC plumbing

    private func request(method: String, params: JSONValue?) async throws -> JSONValue {
        guard let url = server.url else { throw MCPError.invalidURL }
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": UUID().uuidString,
            "method": method,
            "params": params?.asAny as Any
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !server.authHeader.isEmpty {
            let pair = server.authHeader.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            if pair.count == 2 {
                req.setValue(String(pair[1]).trimmingCharacters(in: .whitespaces),
                             forHTTPHeaderField: String(pair[0]).trimmingCharacters(in: .whitespaces))
            } else {
                req.setValue(server.authHeader, forHTTPHeaderField: "Authorization")
            }
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 30

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw MCPError.http(status: http.statusCode, body: body)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let err = json["error"] as? [String: Any] {
            let code = (err["code"] as? Int) ?? -1
            let message = (err["message"] as? String) ?? "RPC error"
            throw MCPError.rpc(code: code, message: message)
        }
        return JSONValue(fromAny: json["result"] ?? NSNull())
    }
}

// MARK: - Lightweight JSON value bridge

enum JSONValue {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(fromAny v: Any) {
        switch v {
        case is NSNull: self = .null
        case let b as Bool: self = .bool(b)
        case let i as Int: self = .number(Double(i))
        case let d as Double: self = .number(d)
        case let s as String: self = .string(s)
        case let a as [Any]: self = .array(a.map { JSONValue(fromAny: $0) })
        case let o as [String: Any]:
            self = .object(o.mapValues { JSONValue(fromAny: $0) })
        default: self = .null
        }
    }

    var asAny: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let b): return b
        case .number(let n): return n
        case .string(let s): return s
        case .array(let a): return a.map(\.asAny)
        case .object(let o): return o.mapValues(\.asAny)
        }
    }
}
