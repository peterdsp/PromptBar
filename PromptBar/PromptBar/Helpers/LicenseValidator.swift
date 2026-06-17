//
//  LicenseValidator.swift
//  PromptBar
//
//  Verifies offline Ed25519-signed licenses issued to Ko-fi buyers.
//  Only compiled into the EXTERNAL_DISTRIBUTION build configuration so the
//  App Store binary contains no license-check code at all (avoids 3.x review
//  problems and keeps that channel free).
//

#if EXTERNAL_DISTRIBUTION

import CryptoKit
import Foundation

struct License: Codable, Equatable {
    let email: String
    let issuedAt: String
    let orderID: String
    let product: String
    let minVersion: String
    let signature: String   // base64

    enum CodingKeys: String, CodingKey {
        case email
        case issuedAt = "issued_at"
        case orderID  = "order_id"
        case product
        case minVersion = "min_version"
        case signature
    }
}

enum LicenseError: LocalizedError {
    case malformed
    case wrongProduct
    case versionTooOld
    case badSignature

    var errorDescription: String? {
        switch self {
        case .malformed:     return "The file isn't a valid PromptBar license."
        case .wrongProduct:  return "This license isn't for PromptBar."
        case .versionTooOld: return "This license is for an older version of PromptBar."
        case .badSignature:  return "The license signature is invalid or has been tampered with."
        }
    }
}

enum LicenseValidator {
    /// Public Ed25519 key (base64). Pairs with scripts/license-private.key.
    /// Replace this string when rotating keys.
    private static let publicKeyBase64 = "p6N4XJLDCrc9J9BhnT4PlLCQ9QLbENOdmuAE4oM5cCY="

    /// Parse a license JSON string (whatever the user pasted or imported)
    /// and verify the embedded signature against the embedded public key.
    static func validate(_ source: String) -> Result<License, LicenseError> {
        guard let data = source.data(using: .utf8) else {
            return .failure(.malformed)
        }
        let decoder = JSONDecoder()
        guard let license = try? decoder.decode(License.self, from: data) else {
            return .failure(.malformed)
        }

        guard license.product.lowercased() == "promptbar" else {
            return .failure(.wrongProduct)
        }

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        if VersionComparator.isVersionNewer(current: currentVersion, latest: license.minVersion) {
            // Current version is older than min_version, license isn't for this build.
            return .failure(.versionTooOld)
        }

        // Reconstruct the canonical signed payload, must match exactly what the
        // issuer signed: keys sorted, no whitespace, no signature field.
        let canonical: [String: Any] = [
            "email":       license.email,
            "issued_at":   license.issuedAt,
            "order_id":    license.orderID,
            "product":     license.product,
            "min_version": license.minVersion
        ]
        guard
            let payload = try? JSONSerialization.data(withJSONObject: canonical, options: [.sortedKeys]),
            let pubKeyData = Data(base64Encoded: publicKeyBase64),
            let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: pubKeyData),
            let signatureData = Data(base64Encoded: license.signature)
        else {
            return .failure(.malformed)
        }

        guard publicKey.isValidSignature(signatureData, for: payload) else {
            return .failure(.badSignature)
        }

        return .success(license)
    }
}

#endif
