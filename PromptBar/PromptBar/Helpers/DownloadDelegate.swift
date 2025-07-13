//
//  DownloadDelegate.swift
//  PromptBar
//
//  Created by Petros Dhespollari on 13/07/2025.
//

import Foundation
import WebKit

final class DownloadDelegate: NSObject, WKNavigationDelegate, WKDownloadDelegate {
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true

        panel.begin { result in
            if result == .OK {
                completionHandler(panel.url)
            } else {
                download.cancel()
                completionHandler(nil)
            }
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        print("✅ Download finished.")
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        print("❌ Download failed: \(error)")
    }
}
