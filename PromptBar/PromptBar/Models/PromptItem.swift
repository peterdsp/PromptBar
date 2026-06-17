//
//  PromptItem.swift
//  PromptBar
//

import Foundation

struct PromptItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var title: String
    var body: String
    var tags: [String] = []
    var createdAt: Date = Date()
}
