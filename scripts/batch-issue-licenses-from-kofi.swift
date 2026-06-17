#!/usr/bin/env xcrun --sdk macosx swift

// Bulk-issue PromptBar 2.0 licenses for every buyer in a Ko-fi
// Transaction_All.csv export.
//
// Usage:
//   xcrun --sdk macosx swift scripts/batch-issue-licenses-from-kofi.swift \
//     /Users/p.dhespollari/Downloads/Transaction_All.csv \
//     licenses
//
// What it does:
//   - Reads the CSV
//   - Picks rows whose Item column contains "PromptBar"
//   - Dedupes by lowercase email
//   - Signs a license for each unique email with the private key at
//     scripts/license-private.key
//   - Writes <sanitized-email>.promptbar files into the output dir
//   - Writes manifest.csv (email, order_id, license_filename) for
//     mail merge
//
// The license file itself is the JSON the user pastes/drops into
// PromptBar's first-launch screen.

import Foundation
import CryptoKit

guard CommandLine.arguments.count >= 3 else {
    FileHandle.standardError.write(Data(
        "Usage: batch-issue-licenses-from-kofi.swift <csv-path> <output-dir>\n".utf8
    ))
    exit(1)
}

let csvPath = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]

// Load private key
let privateKeyPath = "scripts/license-private.key"
guard
    let privateKeyText = try? String(contentsOfFile: privateKeyPath, encoding: .utf8),
    let rawKey = Data(base64Encoded: privateKeyText.trimmingCharacters(in: .whitespacesAndNewlines)),
    let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: rawKey)
else {
    FileHandle.standardError.write(Data(
        "ERROR: \(privateKeyPath) missing or invalid. Run: swift scripts/issue-license.swift --keygen\n".utf8
    ))
    exit(1)
}

// Load CSV
guard let csvData = try? String(contentsOfFile: csvPath, encoding: .utf8) else {
    FileHandle.standardError.write(Data("ERROR: cannot read \(csvPath)\n".utf8))
    exit(1)
}

// Tiny CSV parser. Ko-fi quotes fields that contain commas, and uses ""
// to escape embedded quotes. We only need column extraction, not full RFC 4180.
func parseLine(_ line: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuote = false
    var iterator = line.makeIterator()
    while let ch = iterator.next() {
        if ch == "\"" {
            if inQuote {
                // Peek for escaped quote
                if let next = iterator.next() {
                    if next == "\"" {
                        current.append("\"")
                    } else if next == "," {
                        fields.append(current)
                        current = ""
                        inQuote = false
                    } else {
                        // End of quoted field with character following
                        inQuote = false
                        current.append(next)
                    }
                } else {
                    inQuote = false
                }
            } else {
                inQuote = true
            }
        } else if ch == "," && !inQuote {
            fields.append(current)
            current = ""
        } else {
            current.append(ch)
        }
    }
    fields.append(current)
    return fields
}

let rawLines = csvData.components(separatedBy: "\n")
guard !rawLines.isEmpty else {
    FileHandle.standardError.write(Data("ERROR: CSV is empty\n".utf8))
    exit(1)
}

let header = parseLine(rawLines[0])

guard
    let itemIdx = header.firstIndex(of: "Item"),
    let emailIdx = header.firstIndex(of: "BuyerEmail"),
    let txIdx = header.firstIndex(of: "TransactionId")
else {
    FileHandle.standardError.write(Data("ERROR: CSV missing required columns Item/BuyerEmail/TransactionId\n".utf8))
    FileHandle.standardError.write(Data("Header was: \(header)\n".utf8))
    exit(1)
}

try? FileManager.default.createDirectory(
    atPath: outDir,
    withIntermediateDirectories: true
)

let iso = ISO8601DateFormatter()
iso.formatOptions = [.withInternetDateTime]
let issuedAt = iso.string(from: Date())

var seenEmails = Set<String>()
var manifestRows: [String] = ["email,order_id,license_file"]
var issued = 0

for line in rawLines.dropFirst() where !line.trimmingCharacters(in: .whitespaces).isEmpty {
    let cols = parseLine(line)
    guard cols.count > max(itemIdx, emailIdx, txIdx) else { continue }

    let item = cols[itemIdx]
    guard item.localizedCaseInsensitiveContains("PromptBar") else { continue }

    let email = cols[emailIdx]
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    guard !email.isEmpty, email.contains("@") else { continue }
    if seenEmails.contains(email) { continue }
    seenEmails.insert(email)

    let orderID = cols[txIdx].trimmingCharacters(in: .whitespacesAndNewlines)
    guard !orderID.isEmpty else { continue }

    let canonical: [String: Any] = [
        "email": email,
        "issued_at": issuedAt,
        "order_id": orderID,
        "product": "PromptBar",
        "min_version": "2.0.0"
    ]

    guard
        let payload = try? JSONSerialization.data(withJSONObject: canonical, options: [.sortedKeys]),
        let signature = try? privateKey.signature(for: payload)
    else {
        FileHandle.standardError.write(Data("WARN: signing failed for \(email), skipped\n".utf8))
        continue
    }

    let license: [String: Any] = [
        "email": email,
        "issued_at": issuedAt,
        "order_id": orderID,
        "product": "PromptBar",
        "min_version": "2.0.0",
        "signature": signature.base64EncodedString()
    ]

    guard
        let licenseData = try? JSONSerialization.data(withJSONObject: license, options: [.prettyPrinted, .sortedKeys]),
        let licenseText = String(data: licenseData, encoding: .utf8)
    else { continue }

    let safeEmail = email
        .replacingOccurrences(of: "@", with: "_at_")
        .replacingOccurrences(of: ".", with: "_")
        .replacingOccurrences(of: "+", with: "_plus_")
    let filename = "\(safeEmail).promptbar"
    let outPath = "\(outDir)/\(filename)"

    do {
        try licenseText.write(toFile: outPath, atomically: true, encoding: .utf8)
        manifestRows.append("\(email),\(orderID),\(filename)")
        issued += 1
    } catch {
        FileHandle.standardError.write(Data("WARN: failed to write \(outPath): \(error)\n".utf8))
    }
}

let manifestPath = "\(outDir)/manifest.csv"
try? manifestRows.joined(separator: "\n")
    .write(toFile: manifestPath, atomically: true, encoding: .utf8)

print("Issued \(issued) licenses to \(outDir)/")
print("Mail-merge manifest: \(manifestPath)")
