//
//  APIEndpoint.swift
//  PromptBar
//
//  Generic OpenAI-compatible chat-completions endpoint provided by the user.
//  No third-party brand names are baked in. The user supplies a name, base URL,
//  model identifier, API key, and an optional system prompt.
//

import Foundation

struct APIEndpoint: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var baseURL: String        // e.g. https://api.example.com/v1
    var modelName: String      // e.g. gpt-4o-mini, llama-3.1-70b, etc.
    var systemPrompt: String
    var symbolName: String
    var tintHex: String
    var streamingEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        modelName: String,
        systemPrompt: String = "",
        symbolName: String = "wand.and.stars",
        tintHex: String = "#3DBE8B",
        streamingEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.modelName = modelName
        self.systemPrompt = systemPrompt
        self.symbolName = symbolName
        self.tintHex = tintHex
        self.streamingEnabled = streamingEnabled
    }

    var keychainAccount: String { "endpoint.\(id.uuidString)" }

    var chatCompletionsURL: URL? {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/") { trimmed.removeLast() }
        if trimmed.hasSuffix("/chat/completions") {
            return URL(string: trimmed)
        }
        return URL(string: trimmed + "/chat/completions")
    }

    static func sanitized(name: String, baseURL: String, model: String) -> APIEndpoint? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var u = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, !u.isEmpty, !m.isEmpty else { return nil }
        if !u.lowercased().hasPrefix("http://"),
           !u.lowercased().hasPrefix("https://") {
            u = "https://" + u
        }
        guard URL(string: u) != nil else { return nil }
        return APIEndpoint(name: n, baseURL: u, modelName: m)
    }
}
