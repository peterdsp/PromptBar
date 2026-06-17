//
//  ContentView.swift
//  PromptBar
//

import Foundation
import SwiftUI
@preconcurrency import WebKit

// MARK: - WebView action / state

public enum WebViewAction: Equatable {
    case idle
    case load(URLRequest)
    case loadHTML(String)
    case reload
    case goBack
    case goForward
    case evaluateJS(String, (Result<Any?, Error>) -> Void)

    public static func == (lhs: WebViewAction, rhs: WebViewAction) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.reload, .reload), (.goBack, .goBack), (.goForward, .goForward):
            return true
        case let (.load(a), .load(b)):
            return a == b
        case let (.loadHTML(a), .loadHTML(b)):
            return a == b
        case let (.evaluateJS(a, _), .evaluateJS(b, _)):
            return a == b
        default:
            return false
        }
    }
}

public struct WebViewState: Equatable {
    public var isLoading: Bool
    public var pageURL: String?
    public var pageTitle: String?
    public var canGoBack: Bool
    public var canGoForward: Bool
    public var error: String?

    public static let empty = WebViewState(
        isLoading: false,
        pageURL: nil,
        pageTitle: nil,
        canGoBack: false,
        canGoForward: false,
        error: nil
    )
}

// MARK: - WebView config

public struct WebViewConfig {
    public var allowsBackForwardNavigationGestures: Bool = true
    public var allowsInlineMediaPlayback: Bool = true
    public var supportsDownloads: Bool = true
    public var customUserAgent: String? = nil

    public init(
        allowsBackForwardNavigationGestures: Bool = true,
        allowsInlineMediaPlayback: Bool = true,
        supportsDownloads: Bool = true,
        customUserAgent: String? = nil
    ) {
        self.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
        self.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        self.supportsDownloads = supportsDownloads
        self.customUserAgent = customUserAgent
    }
}

// MARK: - WebView (NSViewRepresentable)

public struct WebView: NSViewRepresentable {
    public let config: WebViewConfig
    @Binding public var action: WebViewAction
    @Binding public var state: WebViewState

    public init(
        config: WebViewConfig = WebViewConfig(),
        action: Binding<WebViewAction>,
        state: Binding<WebViewState>
    ) {
        self.config = config
        self._action = action
        self._state = state
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.websiteDataStore = .default()
        configuration.suppressesIncrementalRendering = false

        // Allow uploads / form posts / inline playback
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = config.allowsBackForwardNavigationGestures
        webView.setValue(false, forKey: "drawsBackground")
        if let agent = config.customUserAgent {
            webView.customUserAgent = agent
        }
        return webView
    }

    public func updateNSView(_ webView: WKWebView, context: Context) {
        if action == .idle { return }
        switch action {
        case .idle:
            break
        case let .load(request):
            webView.load(request)
        case let .loadHTML(html):
            webView.loadHTMLString(html, baseURL: nil)
        case .reload:
            webView.reload()
        case .goBack:
            webView.goBack()
        case .goForward:
            webView.goForward()
        case let .evaluateJS(script, callback):
            webView.evaluateJavaScript(script) { result, error in
                if let error = error { callback(.failure(error)) }
                else { callback(.success(result)) }
            }
        }
        DispatchQueue.main.async { action = .idle }
    }

    // MARK: Coordinator

    public final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        private let parent: WebView

        init(parent: WebView) {
            self.parent = parent
        }

        // MARK: Loading lifecycle

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            updateState(webView: webView, loading: true, error: nil)
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateState(webView: webView, loading: false, error: nil)
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            updateState(webView: webView, loading: false, error: error.localizedDescription)
        }

        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            updateState(webView: webView, loading: false, error: error.localizedDescription)
        }

        // MARK: Window / target=_blank

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

        // MARK: File upload (paperclip), Apple Review 2.1 fix

        public func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping ([URL]?) -> Void
        ) {
            // Pin the popover open while the panel is up. Otherwise the popover's
            // .transient behavior dismisses the moment the panel takes key window.
            let popover = (NSApp.delegate as? AppDelegate)?.popover
            let previousBehavior = popover?.behavior
            popover?.behavior = .applicationDefined

            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = parameters.allowsMultipleSelection
                panel.level = .modalPanel

                NSApp.activate(ignoringOtherApps: true)
                panel.begin { response in
                    let urls: [URL]? = (response == .OK) ? panel.urls : nil
                    completionHandler(urls)
                    if let popover = popover, let previous = previousBehavior {
                        popover.behavior = previous
                    }
                }
            }
        }

        // MARK: JS alerts / confirms / prompts

        public func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }

        public func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn)
        }

        // MARK: Downloads

        public func webView(_ webView: WKWebView,
                            navigationResponse: WKNavigationResponse,
                            didBecome download: WKDownload) {
            download.delegate = self
        }

        public func webView(_ webView: WKWebView,
                            navigationAction: WKNavigationAction,
                            didBecome download: WKDownload) {
            download.delegate = self
        }

        public func download(_ download: WKDownload,
                             decideDestinationUsing response: URLResponse,
                             suggestedFilename: String,
                             completionHandler: @escaping (URL?) -> Void) {
            DispatchQueue.main.async {
                let panel = NSSavePanel()
                panel.nameFieldStringValue = suggestedFilename
                panel.canCreateDirectories = true
                panel.level = .modalPanel
                NSApp.activate(ignoringOtherApps: true)
                panel.begin { result in
                    if result == .OK { completionHandler(panel.url) }
                    else {
                        download.cancel()
                        completionHandler(nil)
                    }
                }
            }
        }

        public func downloadDidFinish(_ download: WKDownload) {}
        public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {}

        // MARK: State update

        private func updateState(webView: WKWebView, loading: Bool, error: String?) {
            var new = parent.state
            new.isLoading = loading
            new.canGoBack = webView.canGoBack
            new.canGoForward = webView.canGoForward
            new.pageURL = webView.url?.absoluteString
            new.pageTitle = webView.title
            new.error = error
            parent.state = new
            parent.action = .idle
        }
    }
}
