//
//  ChatAPIClient.swift
//  PromptBar
//
//  OpenAI-compatible chat-completions client with SSE streaming support.
//  Works against any endpoint that implements the OpenAI POST /chat/completions
//  request/response schema (most popular inference services and local runtimes
//  expose this surface).
//

import Foundation

enum ChatAPIError: LocalizedError {
    case invalidURL
    case missingAPIKey
    case http(status: Int, body: String)
    case decoding(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The endpoint URL is invalid."
        case .missingAPIKey: return "No API key is stored for this endpoint."
        case .http(let s, let b):
            return "HTTP \(s)\(b.isEmpty ? "" : ": \(b.prefix(200))")"
        case .decoding(let m): return "Couldn't parse the response: \(m)"
        case .unknown(let m): return m
        }
    }
}

struct ChatAPIClient {
    let endpoint: APIEndpoint

    private struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        let model: String
        let messages: [Message]
        let stream: Bool
        let temperature: Double?
    }

    private struct ChunkResponse: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let content: String?
            }
            let delta: Delta?
            let finish_reason: String?
        }
        let choices: [Choice]
    }

    private struct FullResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message?
        }
        let choices: [Choice]
    }

    /// Streams text deltas via an `AsyncThrowingStream`.
    func stream(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = endpoint.chatCompletionsURL else {
                        throw ChatAPIError.invalidURL
                    }
                    guard let key = KeychainHelper.read(account: endpoint.keychainAccount),
                          !key.isEmpty
                    else {
                        throw ChatAPIError.missingAPIKey
                    }

                    let body = RequestBody(
                        model: endpoint.modelName,
                        messages: messages.map { .init(role: $0.role.rawValue, content: $0.content) },
                        stream: endpoint.streamingEnabled,
                        temperature: 0.7
                    )

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.httpBody = try JSONEncoder().encode(body)
                    request.timeoutInterval = 120

                    if endpoint.streamingEnabled {
                        let (bytes, response) = try await URLSession.shared.bytes(for: request)
                        try Self.ensureOK(response: response, bytes: bytes)
                        for try await line in bytes.lines {
                            guard line.hasPrefix("data:") else { continue }
                            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                            if payload == "[DONE]" { break }
                            guard let data = payload.data(using: .utf8) else { continue }
                            if let chunk = try? JSONDecoder().decode(ChunkResponse.self, from: data),
                               let delta = chunk.choices.first?.delta?.content {
                                continuation.yield(delta)
                            }
                        }
                    } else {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        try Self.ensureOK(response: response, data: data)
                        let full = try JSONDecoder().decode(FullResponse.self, from: data)
                        if let text = full.choices.first?.message?.content {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func ensureOK(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ChatAPIError.http(status: http.statusCode, body: body)
        }
    }

    private static func ensureOK(response: URLResponse, bytes: URLSession.AsyncBytes) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if !(200..<300).contains(http.statusCode) {
            throw ChatAPIError.http(status: http.statusCode, body: "")
        }
    }
}
