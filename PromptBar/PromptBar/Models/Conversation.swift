//
//  Conversation.swift
//  PromptBar
//

import Foundation

struct ChatMessage: Identifiable, Codable, Equatable, Hashable {
    enum Role: String, Codable {
        case system, user, assistant
    }

    var id: UUID = UUID()
    var role: Role
    var content: String
    var createdAt: Date = Date()
}

struct Conversation: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var endpointID: UUID
    var title: String
    var messages: [ChatMessage]
    var updatedAt: Date = Date()

    static func empty(for endpointID: UUID, systemPrompt: String) -> Conversation {
        var messages: [ChatMessage] = []
        let trimmed = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            messages.append(ChatMessage(role: .system, content: trimmed))
        }
        return Conversation(endpointID: endpointID, title: "New Chat", messages: messages)
    }

    mutating func appendUser(_ text: String) {
        messages.append(ChatMessage(role: .user, content: text))
        updatedAt = Date()
        updateTitleIfNeeded(from: text)
    }

    mutating func appendAssistant(_ text: String) {
        messages.append(ChatMessage(role: .assistant, content: text))
        updatedAt = Date()
    }

    private mutating func updateTitleIfNeeded(from firstUserMessage: String) {
        guard title == "New Chat" else { return }
        let trimmed = firstUserMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let oneLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
        title = String(oneLine.prefix(60))
    }
}
