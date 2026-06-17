//
//  ChatStore.swift
//  PromptBar
//

import Foundation
import SwiftUI

/// A selection in the popup's pill bar can be either a web wrap or an API endpoint.
enum ActiveTarget: Equatable, Hashable, Codable {
    case web(UUID)
    case api(UUID)
}

final class ChatStore: ObservableObject {
    static let shared = ChatStore()

    // Persistence keys
    private let servicesKey = "promptbar.services.v2"
    private let endpointsKey = "promptbar.endpoints.v1"
    private let selectedKey = "promptbar.selectedTarget.v1"
    private let conversationsKey = "promptbar.conversations.v1"
    private let promptsKey = "promptbar.prompts.v1"

    @Published private(set) var services: [ChatService] = []
    @Published private(set) var endpoints: [APIEndpoint] = []
    @Published var selectedTarget: ActiveTarget?

    @Published private(set) var conversations: [Conversation] = []
    @Published var activeConversationID: UUID?

    @Published private(set) var prompts: [PromptItem] = []

    private init() {
        load()
    }

    // MARK: - Web services

    func add(_ service: ChatService) {
        guard !services.contains(where: {
            $0.urlString.caseInsensitiveCompare(service.urlString) == .orderedSame
        }) else { return }
        services.append(service)
        if selectedTarget == nil { selectedTarget = .web(service.id) }
        save()
    }

    func update(_ service: ChatService) {
        guard let i = services.firstIndex(where: { $0.id == service.id }) else { return }
        services[i] = service
        save()
    }

    func remove(_ service: ChatService) {
        services.removeAll(where: { $0.id == service.id })
        if case .web(let id) = selectedTarget, id == service.id {
            selectedTarget = firstAvailableTarget()
        }
        save()
    }

    func moveServices(from source: IndexSet, to destination: Int) {
        services.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func select(_ service: ChatService) {
        selectedTarget = .web(service.id)
        save()
    }

    // MARK: - API endpoints

    func add(_ endpoint: APIEndpoint, apiKey: String) {
        try? KeychainHelper.save(apiKey, account: endpoint.keychainAccount)
        endpoints.append(endpoint)
        if selectedTarget == nil { selectedTarget = .api(endpoint.id) }
        save()
    }

    func update(_ endpoint: APIEndpoint, apiKey: String?) {
        guard let i = endpoints.firstIndex(where: { $0.id == endpoint.id }) else { return }
        endpoints[i] = endpoint
        if let key = apiKey, !key.isEmpty {
            try? KeychainHelper.save(key, account: endpoint.keychainAccount)
        }
        save()
    }

    func remove(_ endpoint: APIEndpoint) {
        KeychainHelper.delete(account: endpoint.keychainAccount)
        endpoints.removeAll(where: { $0.id == endpoint.id })
        conversations.removeAll(where: { $0.endpointID == endpoint.id })
        if case .api(let id) = selectedTarget, id == endpoint.id {
            selectedTarget = firstAvailableTarget()
        }
        save()
    }

    func moveEndpoints(from source: IndexSet, to destination: Int) {
        endpoints.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func select(_ endpoint: APIEndpoint) {
        selectedTarget = .api(endpoint.id)
        save()
    }

    // MARK: - Conversations (only used by API endpoints)

    func conversations(for endpointID: UUID) -> [Conversation] {
        conversations
            .filter { $0.endpointID == endpointID }
            .sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    func startNewConversation(for endpoint: APIEndpoint) -> Conversation {
        let convo = Conversation.empty(for: endpoint.id, systemPrompt: endpoint.systemPrompt)
        conversations.append(convo)
        activeConversationID = convo.id
        save()
        return convo
    }

    func updateConversation(_ convo: Conversation) {
        if let i = conversations.firstIndex(where: { $0.id == convo.id }) {
            conversations[i] = convo
        } else {
            conversations.append(convo)
        }
        save()
    }

    func deleteConversation(_ convo: Conversation) {
        conversations.removeAll(where: { $0.id == convo.id })
        if activeConversationID == convo.id { activeConversationID = nil }
        save()
    }

    // MARK: - Prompt library

    func addPrompt(_ item: PromptItem) {
        prompts.append(item)
        save()
    }

    func updatePrompt(_ item: PromptItem) {
        guard let i = prompts.firstIndex(where: { $0.id == item.id }) else { return }
        prompts[i] = item
        save()
    }

    func deletePrompt(_ item: PromptItem) {
        prompts.removeAll(where: { $0.id == item.id })
        save()
    }

    // MARK: - Helpers

    var selectedService: ChatService? {
        guard case .web(let id) = selectedTarget else { return nil }
        return services.first(where: { $0.id == id })
    }

    var selectedEndpoint: APIEndpoint? {
        guard case .api(let id) = selectedTarget else { return nil }
        return endpoints.first(where: { $0.id == id })
    }

    private func firstAvailableTarget() -> ActiveTarget? {
        if let first = services.first { return .web(first.id) }
        if let first = endpoints.first { return .api(first.id) }
        return nil
    }

    // MARK: - Persistence

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: servicesKey),
           let decoded = try? JSONDecoder().decode([ChatService].self, from: data) {
            services = decoded
        }
        if let data = d.data(forKey: endpointsKey),
           let decoded = try? JSONDecoder().decode([APIEndpoint].self, from: data) {
            endpoints = decoded
        }
        if let data = d.data(forKey: conversationsKey),
           let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = decoded
        }
        if let data = d.data(forKey: promptsKey),
           let decoded = try? JSONDecoder().decode([PromptItem].self, from: data) {
            prompts = decoded
        }
        if let raw = d.string(forKey: selectedKey),
           let decoded = try? JSONDecoder().decode(ActiveTarget.self,
                                                   from: Data(raw.utf8)) {
            selectedTarget = decoded
        } else {
            selectedTarget = firstAvailableTarget()
        }
    }

    private func save() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(services) {
            d.set(data, forKey: servicesKey)
        }
        if let data = try? JSONEncoder().encode(endpoints) {
            d.set(data, forKey: endpointsKey)
        }
        if let data = try? JSONEncoder().encode(conversations) {
            d.set(data, forKey: conversationsKey)
        }
        if let data = try? JSONEncoder().encode(prompts) {
            d.set(data, forKey: promptsKey)
        }
        if let target = selectedTarget,
           let data = try? JSONEncoder().encode(target),
           let str = String(data: data, encoding: .utf8) {
            d.set(str, forKey: selectedKey)
        }
    }
}
