//
//  WebViewHelper.swift
//  PromptBar
//
//  Created by Petros Dhespollari on 10/01/2025.
//

import WebKit

@objc class WebViewHelper: NSObject {
    static let reloadState = ReloadState()

    @objc static func clean(domains: [String] = []) {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            let filteredRecords = domains.isEmpty ? records : records.filter { record in
                domains.contains { record.displayName.contains($0) }
            }
            dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: filteredRecords) {
                self.reloadState.shouldReload = true
            }
        }
    }
}
