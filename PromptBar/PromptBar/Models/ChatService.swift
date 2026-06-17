//
//  ChatService.swift
//  PromptBar
//

import Foundation

struct ChatService: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var urlString: String
    var symbolName: String
    var tintHex: String

    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        symbolName: String = "bubble.left.and.bubble.right",
        tintHex: String = "#7A7AFF"
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.symbolName = symbolName
        self.tintHex = tintHex
    }

    var url: URL? { URL(string: urlString) }

    static func sanitized(name: String, urlString: String) -> ChatService? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedURL.isEmpty else { return nil }

        if !trimmedURL.lowercased().hasPrefix("http://"),
           !trimmedURL.lowercased().hasPrefix("https://") {
            trimmedURL = "https://" + trimmedURL
        }

        guard
            let components = URLComponents(string: trimmedURL),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            components.host?.isEmpty == false
        else { return nil }

        return ChatService(name: trimmedName, urlString: trimmedURL)
    }
}
