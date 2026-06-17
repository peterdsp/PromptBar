//
//  AppPreferences.swift
//  PromptBar
//

import Foundation
import SwiftUI

enum WindowMode: String, Codable, CaseIterable {
    case menubar
    case window

    var displayName: String {
        switch self {
        case .menubar: return "Menubar"
        case .window: return "Window"
        }
    }
}

final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    private let onboardingKey = "promptbar.hasCompletedOnboarding.v1"
    private let modeKey = "promptbar.windowMode.v1"

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: onboardingKey) }
    }

    @Published var windowMode: WindowMode {
        didSet { UserDefaults.standard.set(windowMode.rawValue, forKey: modeKey) }
    }

    private init() {
        let d = UserDefaults.standard
        self.hasCompletedOnboarding = d.bool(forKey: onboardingKey)
        let raw = d.string(forKey: modeKey) ?? WindowMode.menubar.rawValue
        self.windowMode = WindowMode(rawValue: raw) ?? .menubar
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}
