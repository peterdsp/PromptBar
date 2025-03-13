//
//  ContentView.swift
//  Mistralis
//
//  Created by Petros Dhespollari on 16/3/24.
//

import Foundation
import SwiftUI
@preconcurrency import WebKit

public enum WebViewAction: Equatable {
    case idle
    case
        load(URLRequest)
    case
        loadHTML(String)
    case
        reload,
        goBack,
        goForward
    case
        evaluateJS(String, (Result<Any?, Error>) -> Void)

    public static func == (lhs: WebViewAction, rhs: WebViewAction) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
            (.reload, .reload),
            (.goBack, .goBack),
            (.goForward, .goForward):
            return true
        case let (.load(requestLHS), .load(requestRHS)):
            return requestLHS == requestRHS
        case let (.loadHTML(htmlLHS), .loadHTML(htmlRHS)):
            return htmlLHS == htmlRHS
        case let (.evaluateJS(commandLHS, _), .evaluateJS(commandRHS, _)):
            return commandLHS == commandRHS
        default:
            return false
        }
    }
}

public struct WebViewState: Equatable {
    public internal(set) var isLoading: Bool
    public internal(set) var pageURL: String?
    public internal(set) var pageTitle: String?
    public internal(set) var pageHTML: String?
    public internal(set) var error: Error?
    public internal(set) var canGoBack: Bool
    public internal(set) var canGoForward: Bool

    public static let empty = WebViewState(
        isLoading: false,
        pageURL: nil,
        pageTitle: nil,
        pageHTML: nil,
        error: nil,
        canGoBack: false,
        canGoForward: false)

    public static func == (lhs: WebViewState, rhs: WebViewState) -> Bool {
        return lhs.isLoading == rhs.isLoading
            && lhs.pageURL == rhs.pageURL
            && lhs.pageTitle == rhs.pageTitle
            && lhs.pageHTML == rhs.pageHTML
            && lhs.error?.localizedDescription
                == rhs.error?.localizedDescription
            && lhs.canGoBack == rhs.canGoBack
            && lhs.canGoForward == rhs.canGoForward
    }
}

public class ContentView: NSObject {
    private let webView: WebView
    var actionInProgress = false

    init(webView: WebView) {
        self.webView = webView
    }

    func setLoading(
        _ isLoading: Bool,
        canGoBack: Bool? = nil,
        canGoForward: Bool? = nil,
        error: Error? = nil
    ) {
        var newState = webView.state
        newState.isLoading = isLoading
        if let canGoBack = canGoBack {
            newState.canGoBack = canGoBack
        }
        if let canGoForward = canGoForward {
            newState.canGoForward = canGoForward
        }
        if let error = error {
            newState.error = error
        }
        webView.state = newState
        webView.action = .idle
        actionInProgress = false
    }
}

extension ContentView: WKNavigationDelegate {
    public func webView(
        _ webView: WKWebView, didFinish navigation: WKNavigation!
    ) {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.hideLoadingView()  // Hide loader when navigation finishes
        }
        setLoading(
            false,
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward
        )

        // ✅ Update page title
        webView.evaluateJavaScript("document.title") { response, _ in
            if let title = response as? String {
                self.updateState(pageTitle: title)
            }
        }

        // ✅ Update page URL
        webView.evaluateJavaScript("document.URL.toString()") { response, _ in
            if let url = response as? String {
                self.updateState(pageURL: url)
            }
        }

        // ✅ Update page HTML if required
        if self.webView.htmlInState {
            webView.evaluateJavaScript(
                "document.documentElement.outerHTML.toString()"
            ) { response, _ in
                if let html = response as? String {
                    self.updateState(pageHTML: html)
                }
            }
        }

        // ✅ Get the "subscriptions" list from AppDelegate
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            let removeTextsJSArray = appDelegate.removeTexts
                .map { "\"\($0)\"" }
                .joined(separator: ", ")

            let removeUpgradeButtonsJS = """
                    (function() {
                        const removeTexts = [\(removeTextsJSArray)];

                        function removeUpgradeElements() {
                            let upgradeElements = [...document.querySelectorAll("a, button, li")]
                                .filter(el => removeTexts.some(text => el.innerText.includes(text)));
                            upgradeElements.forEach(el => el.remove());
                        }

                        // Run immediately in case elements are already present
                        removeUpgradeElements();

                        // Set up a MutationObserver to handle dynamically loaded elements
                        let observer = new MutationObserver(() => removeUpgradeElements());
                        observer.observe(document.body, { childList: true, subtree: true });
                    })();
                """

            webView.evaluateJavaScript(removeUpgradeButtonsJS) { _, error in
                if let error = error {
                    print("⚠️ Failed to remove subscription items: \(error)")
                }
            }
        }
    }

    // ✅ Helper function to update the WebViewState
    private func updateState(
        pageTitle: String? = nil, pageURL: String? = nil,
        pageHTML: String? = nil
    ) {
        var newState = self.webView.state
        if let title = pageTitle { newState.pageTitle = title }
        if let url = pageURL { newState.pageURL = url }
        if let html = pageHTML { newState.pageHTML = html }
        self.webView.state = newState
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        setLoading(false)
    }

    public func webView(
        _ webView: WKWebView, didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        setLoading(false, error: error)
    }

    public func webView(
        _ webView: WKWebView, didCommit navigation: WKNavigation!
    ) {
        setLoading(true)
    }

    public func webView(
        _ webView: WKWebView,
        didStartProvisionalNavigation navigation: WKNavigation!
    ) {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.showLoadingView()  // Show loader when navigation starts
        }
        setLoading(
            true,
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward)
    }
}

extension ContentView: WKUIDelegate {
    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

public struct WebViewConfig {
    public static let `default` = WebViewConfig()
    public let allowsBackForwardNavigationGestures: Bool
    public let allowsInlineMediaPlayback: Bool
    public let mediaTypesRequiringUserActionForPlayback: WKAudiovisualMediaTypes
    public let isScrollEnabled: Bool
    public let isOpaque: Bool
    public let backgroundColor: Color
    public var customUserAgent: String?

    public init(
        allowsBackForwardNavigationGestures: Bool = true,
        allowsInlineMediaPlayback: Bool = true,
        mediaTypesRequiringUserActionForPlayback: WKAudiovisualMediaTypes = [],
        isScrollEnabled: Bool = true,
        isOpaque: Bool = true,
        backgroundColor: Color = .clear,
        customUserAgent: String? = nil
    ) {
        self.allowsBackForwardNavigationGestures =
            allowsBackForwardNavigationGestures
        self.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        self.mediaTypesRequiringUserActionForPlayback =
            mediaTypesRequiringUserActionForPlayback
        self.isScrollEnabled = isScrollEnabled
        self.isOpaque = isOpaque
        self.backgroundColor = backgroundColor
        self.customUserAgent = customUserAgent
    }
}

#if os(macOS)
    public struct WebView: NSViewRepresentable {
        let config: WebViewConfig
        @Binding var action: WebViewAction
        @Binding var state: WebViewState
        let restrictedPages: [String]?
        let htmlInState: Bool
        let schemeHandlers: [String: (URL) -> Void]
        public init(
            config: WebViewConfig = .default,
            action: Binding<WebViewAction>,
            state: Binding<WebViewState>,
            restrictedPages: [String]? = nil,
            htmlInState: Bool = false,
            schemeHandlers: [String: (URL) -> Void] = [:]
        ) {
            self.config = config
            _action = action
            _state = state
            self.restrictedPages = restrictedPages
            self.htmlInState = htmlInState
            self.schemeHandlers = schemeHandlers
        }

        public func makeCoordinator() -> ContentView {
            ContentView(webView: self)
        }

        public func makeNSView(context: Context) -> WKWebView {
            let preferences = WKWebpagePreferences()
            preferences.allowsContentJavaScript = true

            let configuration = WKWebViewConfiguration()
            configuration.defaultWebpagePreferences = preferences
            configuration.websiteDataStore = WKWebsiteDataStore.default()
            configuration.suppressesIncrementalRendering = false

            let webView = WKWebView(
                frame: CGRect.zero, configuration: configuration)
            webView.navigationDelegate = context.coordinator
            webView.uiDelegate = context.coordinator
            webView.allowsBackForwardNavigationGestures =
                config.allowsBackForwardNavigationGestures

            return webView
        }

        public func updateNSView(_ uiView: WKWebView, context: Context) {
            if action == .idle {
                return
            }
            switch action {
            case .idle:
                break
            case let .load(request):
                uiView.load(request)
            case let .loadHTML(html):
                uiView.loadHTMLString(html, baseURL: nil)
            case .reload:
                uiView.reload()
            case .goBack:
                uiView.goBack()
            case .goForward:
                uiView.goForward()
            case let .evaluateJS(command, callback):
                uiView.evaluateJavaScript(command) { result, error in
                    if let error = error {
                        callback(.failure(error))
                    } else {
                        callback(.success(result))
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                action = .idle
            }
        }
    }
#endif
