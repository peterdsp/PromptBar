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
    private let licensedEmailKey = "promptbar.licensedEmail.v1"

    @Published private(set) var licensedEmail: String?

    private init() {
        if let blob = KeychainHelper.read(account: keychainAccount),
           case .success(let license) = LicenseValidator.validate(blob) {
            licensedEmail = license.email
            UserDefaults.standard.set(license.email, forKey: licensedEmailKey)
        }
    }

    var isLicensed: Bool { licensedEmail != nil }

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
        UserDefaults.standard.removeObject(forKey: licensedEmailKey)
        licensedEmail = nil
    }
}

#endif
