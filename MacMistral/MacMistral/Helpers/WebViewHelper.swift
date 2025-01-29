//
//  WebViewHelper.swift
//  MacMistral
//
//  Created by Petros Dhespollari on 10/01/2025.
//

import WebKit

@objc class WebViewHelper: NSObject {  // Add @objc to expose to Objective-C
    static let reloadState = ReloadState()

    @objc static func clean() {  // Add @objc to make it accessible to #selector
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)

        WKWebsiteDataStore.default().fetchDataRecords(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()
        ) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(
                    ofTypes: record.dataTypes, for: [record],
                    completionHandler: {})
            }
            self.reloadState.shouldReload = true
        }
    }
}
