//
//  LicenseStore.swift
//  PromptBar
//

#if EXTERNAL_DISTRIBUTION

import Foundation
import SwiftUI

final class LicenseStore: ObservableObject {
    static let shared = LicenseStore()

    private let keychainAccount = "license.v1"
    private let trialAccount = "trial.start.v1"
    private let licensedEmailKey = "promptbar.licensedEmail.v1"

    /// Length of the free-trial grace period before activation becomes mandatory.
    static let trialDuration: TimeInterval = 7 * 24 * 60 * 60

    @Published private(set) var licensedEmail: String?
    @Published private(set) var trialStartedAt: Date?

    /// Lightweight ticker so SwiftUI views recompute trialDaysRemaining without
    /// us recomputing on every Date() call. Toggled in startTrialIfNeeded and
    /// nudged by a periodic refresh inside AppDelegate.
    @Published var trialTick: Date = Date()

    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private init() {
        if let blob = KeychainHelper.read(account: keychainAccount),
           case .success(let license) = LicenseValidator.validate(blob) {
            licensedEmail = license.email
            UserDefaults.standard.set(license.email, forKey: licensedEmailKey)
        }
        if let raw = KeychainHelper.read(account: trialAccount),
           let date = iso.date(from: raw) {
            trialStartedAt = date
        }
    }

    // MARK: - Derived state

    var isLicensed: Bool { licensedEmail != nil }

    var isInTrial: Bool {
        guard !isLicensed else { return false }
        guard let start = trialStartedAt else { return false }
        return Date() < start.addingTimeInterval(Self.trialDuration)
    }

    /// True when the trial has run out and no license is on file.
    var trialExpired: Bool {
        guard !isLicensed else { return false }
        guard let start = trialStartedAt else { return false }
        return Date() >= start.addingTimeInterval(Self.trialDuration)
    }

    /// Allowed to use the rest of the app right now.
    var canUseApp: Bool { isLicensed || isInTrial }

    var trialDaysRemaining: Int {
        _ = trialTick   // re-evaluates when the ticker advances
        guard !isLicensed, let start = trialStartedAt else { return 0 }
        let end = start.addingTimeInterval(Self.trialDuration)
        let seconds = end.timeIntervalSinceNow
        guard seconds > 0 else { return 0 }
        return Int(ceil(seconds / (24 * 60 * 60)))
    }

    // MARK: - Mutations

    /// Stamp the trial start on first launch if it hasn't been recorded yet
    /// and the user isn't already licensed. Idempotent.
    func startTrialIfNeeded() {
        guard !isLicensed, trialStartedAt == nil else { return }
        let now = Date()
        try? KeychainHelper.save(iso.string(from: now), account: trialAccount)
        trialStartedAt = now
        trialTick = now
    }

    @discardableResult
    func install(_ rawText: String) -> Result<License, LicenseError> {
        let result = LicenseValidator.validate(rawText)
        if case .success(let license) = result {
            try? KeychainHelper.save(rawText, account: keychainAccount)
            licensedEmail = license.email
            UserDefaults.standard.set(license.email, forKey: licensedEmailKey)
        }
        return result
    }

    func reset() {
        KeychainHelper.delete(account: keychainAccount)
        KeychainHelper.delete(account: trialAccount)
        UserDefaults.standard.removeObject(forKey: licensedEmailKey)
        licensedEmail = nil
        trialStartedAt = nil
        trialTick = Date()
    }
}

#endif
