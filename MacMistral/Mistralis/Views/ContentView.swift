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
        setLoading(
            false,
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward)

        webView.evaluateJavaScript("document.title") { response, error in
            if let error = error {
            } else if let title = response as? String {
                var newState = self.webView.state
                newState.pageTitle = title
                self.webView.state = newState
            }
        }

        webView.evaluateJavaScript("document.URL.toString()") {
            response, error in
            if let error = error {
            } else if let url = response as? String {
                var newState = self.webView.state
                newState.pageURL = url
                self.webView.state = newState
            }
        }

        if self.webView.htmlInState {
            webView.evaluateJavaScript(
                "document.documentElement.outerHTML.toString()"
            ) { response, error in
                if let error = error {
                } else if let html = response as? String {
                    var newState = self.webView.state
                    newState.pageHTML = html
                    self.webView.state = newState
                }
            }
        }
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
        setLoading(
            true,
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward)
    }

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let host = navigationAction.request.url?.host,
            self.webView.restrictedPages?.first(where: { host.contains($0) })
                != nil
        {
            decisionHandler(.cancel)
            setLoading(false)
            return
        }
        if let url = navigationAction.request.url,
            let scheme = url.scheme,
            let schemeHandler = self.webView.schemeHandlers[scheme]
        {
            schemeHandler(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
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
            configuration.applicationNameForUserAgent =
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15"
            configuration.defaultWebpagePreferences = preferences
            configuration.websiteDataStore = WKWebsiteDataStore.default()
            configuration.suppressesIncrementalRendering = false

            // Apply custom user agent if provided
            if let customUserAgent = config.customUserAgent {
                configuration.applicationNameForUserAgent = customUserAgent
            }

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
