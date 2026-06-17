//
//  UpdateChecker.swift
//  PromptBar
//

import Foundation

struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
    }
}

enum UpdateCheckResult {
    case upToDate(currentVersion: String)
    case updateAvailable(latest: String, url: URL, notes: String?)
    case failure(Error)
}

enum UpdateChecker {
    private static let endpoint = URL(
        string: "https://api.github.com/repos/peterdsp/PromptBar/releases/latest"
    )!

    static func check(currentVersion: String) async -> UpdateCheckResult {
        do {
            var request = URLRequest(url: endpoint)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .upToDate(currentVersion: currentVersion)
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let normalized = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            if VersionComparator.isVersionNewer(current: currentVersion, latest: normalized) {
                return .updateAvailable(latest: normalized, url: release.htmlURL, notes: release.body)
            } else {
                return .upToDate(currentVersion: currentVersion)
            }
        } catch {
            return .failure(error)
        }
    }
}
