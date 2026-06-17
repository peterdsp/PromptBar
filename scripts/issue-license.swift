#!/usr/bin/env xcrun --sdk macosx swift

import Foundation
import CryptoKit

// PromptBar license issuer.
//
// First time: generate the keypair.
//
//   swift scripts/issue-license.swift --keygen
//
// The script writes scripts/license-private.key (gitignored) and prints the
// public key. Paste the public key string into PUBLIC_KEY_BASE64 inside
// Helpers/LicenseValidator.swift.
//
// Per customer: issue a signed license.
//
//   swift scripts/issue-license.swift <email> <kofi-order-id> [min-version] > license.promptbar
//
// Email the resulting .promptbar file to the buyer.

let args = CommandLine.arguments
let privateKeyPath = "scripts/license-private.key"

if args.count > 1 && args[1] == "--keygen" {
    let key = Curve25519.Signing.PrivateKey()
    let privateB64 = key.rawRepresentation.base64EncodedString()
    let publicB64 = key.publicKey.rawRepresentation.base64EncodedString()
    try privateB64.write(toFile: privateKeyPath, atomically: true, encoding: .utf8)
    FileManager.default.createFile(atPath: privateKeyPath, contents: Data(privateB64.utf8))
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: privateKeyPath)
    print("Private key written to \(privateKeyPath) (mode 600).")
    print("DO NOT commit it. It is gitignored.")
    print("")
    print("Public key (paste into PUBLIC_KEY_BASE64 in LicenseValidator.swift):")
    print(publicB64)
    exit(0)
}

guard
    let privateData = try? String(contentsOfFile: privateKeyPath, encoding: .utf8),
    let rawKey = Data(base64Encoded: privateData.trimmingCharacters(in: .whitespacesAndNewlines)),
    let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: rawKey)
else {
    FileHandle.standardError.write(Data("ERROR: \(privateKeyPath) missing or invalid. Run: swift scripts/issue-license.swift --keygen\n".utf8))
    exit(1)
}

guard args.count >= 3 else {
    FileHandle.standardError.write(Data("Usage: swift scripts/issue-license.swift <email> <order-id> [min-version]\n".utf8))
    exit(1)
}

let email = args[1].lowercased()
let orderID = args[2]
let minVersion = args.count >= 4 ? args[3] : "2.0.0"

let iso = ISO8601DateFormatter()
iso.formatOptions = [.withInternetDateTime]
let issuedAt = iso.string(from: Date())

// Canonical payload (signature is computed over this exact JSON byte sequence,
// keys sorted, no whitespace).
let canonical: [String: Any] = [
    "email": email,
    "issued_at": issuedAt,
    "order_id": orderID,
    "product": "PromptBar",
    "min_version": minVersion
]

guard let payload = try? JSONSerialization.data(withJSONObject: canonical, options: [.sortedKeys]) else {
    FileHandle.standardError.write(Data("ERROR: failed to serialize payload\n".utf8))
    exit(1)
}

let signature: Data
do {
    signature = try privateKey.signature(for: payload)
} catch {
    FileHandle.standardError.write(Data("ERROR: signing failed: \(error)\n".utf8))
    exit(1)
}

let license: [String: Any] = [
    "email": email,
    "issued_at": issuedAt,
    "order_id": orderID,
    "product": "PromptBar",
    "min_version": minVersion,
    "signature": signature.base64EncodedString()
]

if let out = try? JSONSerialization.data(withJSONObject: license, options: [.prettyPrinted, .sortedKeys]),
   let text = String(data: out, encoding: .utf8) {
    print(text)
}
