//
//  AppPreferences.swift
//  PromptBar
//

import AppKit
import Foundation
import SwiftUI

/// Window mode is applied by bootForCurrentMode() at launch only: it sets the
/// activation policy and builds the status item and main menu, and there's no
/// teardown path to run it twice. So changing mode means relaunching. Shared
/// so Settings and the menubar menu do the same thing.
enum AppRelauncher {
    static func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}

enum WindowMode: String, Codable, CaseIterable {
    case menubar    // status item + popover, no Dock icon. The default.
    case window     // Dock icon, regular window
    case hidden     // background only, no Dock, hotkey-summoned

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
        let onboarded = d.bool(forKey: onboardingKey)
        self.hasCompletedOnboarding = onboarded

        // Fresh installs default to .menubar; PromptBar is a menubar app.
        //
        // Anyone updating from <= 2.0 must keep .window, or their Dock icon
        // and window vanish on update. They can't be told apart by the mode
        // key alone: this init assigns the property directly, and Swift
        // doesn't fire didSet from an initializer, so the key was never
        // written for the many users who never opened the picker. Completed
        // onboarding is the reliable "this install predates 2.1" signal.
        if let raw = d.string(forKey: modeKey), let stored = WindowMode(rawValue: raw) {
            self.windowMode = stored
        } else {
            let migrated: WindowMode = onboarded ? .window : .menubar
            self.windowMode = migrated
            // Persist the resolved choice so this only decides once. Written
            // directly because didSet hasn't armed yet during init.
            d.set(migrated.rawValue, forKey: modeKey)
        }

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
