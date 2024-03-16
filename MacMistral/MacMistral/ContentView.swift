//
//  ContentView.swift
//  MacMistral
//
//  Created by Petros Dhespollari on 16/3/24.
//

import Foundation
import SwiftUI
import WebKit

public enum WebViewAction: Equatable {
    case idle,
         load(URLRequest),
         loadHTML(String),
         reload,
         goBack,
         goForward,
         evaluateJS(String, (Result<Any?, Error>) -> Void)
    
    public static func == (lhs: WebViewAction, rhs: WebViewAction) -> Bool {
        if case .idle = lhs,
           case .idle = rhs
        {
            return true
        }
        if case let .load(requestLHS) = lhs,
           case let .load(requestRHS) = rhs
        {
            return requestLHS == requestRHS
        }
        if case let .loadHTML(htmlLHS) = lhs,
           case let .loadHTML(htmlRHS) = rhs
        {
            return htmlLHS == htmlRHS
        }
        if case .reload = lhs,
           case .reload = rhs
        {
            return true
        }
        if case .goBack = lhs,
           case .goBack = rhs
        {
            return true
        }
        if case .goForward = lhs,
           case .goForward = rhs
        {
            return true
        }
        if case let .evaluateJS(commandLHS, _) = lhs,
           case let .evaluateJS(commandRHS, _) = rhs
        {
            return commandLHS == commandRHS
        }
        return false
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
    
    public static let empty = WebViewState(isLoading: false,
                                           pageURL: nil,
                                           pageTitle: nil,
                                           pageHTML: nil,
                                           error: nil,
                                           canGoBack: false,
                                           canGoForward: false)
    
    public static func == (lhs: WebViewState, rhs: WebViewState) -> Bool {
        lhs.isLoading == rhs.isLoading
            && lhs.pageURL == rhs.pageURL
            && lhs.pageTitle == rhs.pageTitle
            && lhs.pageHTML == rhs.pageHTML
            && lhs.error?.localizedDescription == rhs.error?.localizedDescription
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
    
    func setLoading(_ isLoading: Bool,
                    canGoBack: Bool? = nil,
                    canGoForward: Bool? = nil,
                    error: Error? = nil)
    {
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
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        setLoading(false,
                   canGoBack: webView.canGoBack,
                   canGoForward: webView.canGoForward)
        
        webView.evaluateJavaScript("document.title") { response, _ in
            if let title = response as? String {
                var newState = self.webView.state
                newState.pageTitle = title
                self.webView.state = newState
            }
        }
      
        webView.evaluateJavaScript("document.URL.toString()") { response, _ in
            if let url = response as? String {
                var newState = self.webView.state
                newState.pageURL = url
                self.webView.state = newState
            }
        }
        
        if self.webView.htmlInState {
            webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") { response, _ in
                if let html = response as? String {
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
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        setLoading(false, error: error)
    }
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        setLoading(true)
    }
    
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        setLoading(true,
                   canGoBack: webView.canGoBack,
                   canGoForward: webView.canGoForward)
    }
    
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
    {
        if let host = navigationAction.request.url?.host {
            if self.webView.restrictedPages?.first(where: { host.contains($0) }) != nil {
                decisionHandler(.cancel)
                setLoading(false)
                return
            }
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
    public func webView(_ webView: WKWebView,
                        createWebViewWith configuration: WKWebViewConfiguration,
                        for navigationAction: WKNavigationAction,
                        windowFeatures: WKWindowFeatures) -> WKWebView?
    {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

public struct WebViewConfig {
    public static let `default` = WebViewConfig()
    
    public let javaScriptEnabled: Bool
    public let allowsBackForwardNavigationGestures: Bool
    public let allowsInlineMediaPlayback: Bool
    public let mediaTypesRequiringUserActionForPlayback: WKAudiovisualMediaTypes
    public let isScrollEnabled: Bool
    public let isOpaque: Bool
    public let backgroundColor: Color
    public var customUserAgent: String?
    
    public init(javaScriptEnabled: Bool = true,
                allowsBackForwardNavigationGestures: Bool = true,
                allowsInlineMediaPlayback: Bool = true,
                mediaTypesRequiringUserActionForPlayback: WKAudiovisualMediaTypes = [],
                isScrollEnabled: Bool = true,
                isOpaque: Bool = true,
                backgroundColor: Color = .clear,
                customUserAgent: String? = nil)
    {
        self.javaScriptEnabled = javaScriptEnabled
        self.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
        self.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        self.mediaTypesRequiringUserActionForPlayback = mediaTypesRequiringUserActionForPlayback
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
    
    public init(config: WebViewConfig = .default,
                action: Binding<WebViewAction>,
                state: Binding<WebViewState>,
                restrictedPages: [String]? = nil,
                htmlInState: Bool = false,
                schemeHandlers: [String: (URL) -> Void] = [:])
    {
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
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = config.javaScriptEnabled
        
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        
        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = config.customUserAgent
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = config.allowsBackForwardNavigationGestures
        
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
