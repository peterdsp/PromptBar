//
//  VersionComparator.swift
//  PromptBar
//

import Foundation

enum VersionComparator {
  static func isVersionNewer(current: String, latest: String) -> Bool {
    let currentComponents = current.split(separator: ".").compactMap {
      Int($0)
    }
    let latestComponents = latest.split(separator: ".").compactMap {
      Int($0)
    }

    for (currentPart, latestPart) in zip(
      currentComponents, latestComponents)
    {
      if latestPart > currentPart {
        return true
      } else if latestPart < currentPart {
        return false
      }
    }

    return latestComponents.count > currentComponents.count
  }
}
