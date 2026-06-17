//
//  AppPreferences.swift
//  PromptBar
//

import Foundation
import SwiftUI

enum WindowMode: String, Codable, CaseIterable {
    case menubar    // legacy, kept for compatibility with the Settings picker
    case window     // Dock icon, regular window
    case hidden     // background only, no Dock, no menubar, hotkey-summoned

    var displayName: String {
        switch self {
        case .menubar: return "Menubar"
        case .window: return "Window"
        case .hidden: return "Hidden"
        }
    }
}

final class AppPreferences: ObservableObject {
    static let shared = AppPreferences()

    private let onboardingKey = "promptbar.hasCompletedOnboarding.v1"
    private let modeKey = "promptbar.windowMode.v1"
    private let hotKeyKey = "promptbar.hotKeyEnabled.v1"

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: onboardingKey) }
    }

    @Published var windowMode: WindowMode {
        didSet { UserDefaults.standard.set(windowMode.rawValue, forKey: modeKey) }
    }

    @Published var hotKeyEnabled: Bool {
        didSet { UserDefaults.standard.set(hotKeyEnabled, forKey: hotKeyKey) }
    }

    private init() {
        let d = UserDefaults.standard
        self.hasCompletedOnboarding = d.bool(forKey: onboardingKey)
        let raw = d.string(forKey: modeKey) ?? WindowMode.window.rawValue
        self.windowMode = WindowMode(rawValue: raw) ?? .window
        // Default to hotkey enabled if the key has never been set.
        if d.object(forKey: hotKeyKey) == nil {
            self.hotKeyEnabled = true
        } else {
            self.hotKeyEnabled = d.bool(forKey: hotKeyKey)
        }
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
}
