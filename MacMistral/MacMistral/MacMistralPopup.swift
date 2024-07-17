//
//  MacMistralPopup.swift
//  MacMistral
//
//  Created by Petros Dhespollari on 16/3/24.
//

import AppKit
import SwiftUI
import WebKit

class MacMistralPopup: NSViewController {
    var hostingController: NSHostingController<MainUI>?

    override func loadView() {
        let appDelegate = NSApp.delegate as? AppDelegate
        let selectedAIChatTitle = appDelegate?.selectedAIChatTitle
        let initialAddress: String?
        if let selectedAIChatTitle = selectedAIChatTitle, let chatOptions = appDelegate?.chatOptions, let url = chatOptions[selectedAIChatTitle] {
            initialAddress = url
        } else if let chatOptions = appDelegate?.chatOptions, let firstUrl = chatOptions.values.first {
            initialAddress = firstUrl
        } else {
            initialAddress = nil
        }
        self.hostingController = NSHostingController(rootView: MainUI(initialAddress: initialAddress ?? ""))
        self.view = self.hostingController!.view
        self.view.frame = CGRect(origin: .zero, size: appDelegate?.windowSizeOptions["Medium"] ?? CGSize(width: 500, height: 600))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let appDelegate: AppDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        var size = appDelegate.popover?.contentSize ?? CGSize.zero
        size.width += event.deltaX
        size.height += event.deltaY
        appDelegate.popover?.contentSize = size
    }
}

struct MainUI: View {
    @State private var action = WebViewAction.idle
    @State private var state = WebViewState.empty
    @State private var address: String
    @ObservedObject private var reloadState = WebViewHelper.reloadState

    public func reloadWebView() {
        self.action = .reload
    }

    init(initialAddress: String = "https://chat.mistral.ai/chat/") {
        self._address = State(initialValue: initialAddress)
    }

    public func updateAddress(_ newAddress: String) {
        self.address = newAddress
        if let url = URL(string: newAddress) {
            self.action = .load(URLRequest(url: url))
        }
    }

    var webConfig: WebViewConfig {
        var defaultC = WebViewConfig.default
        return defaultC
    }

    var body: some View {
        VStack(spacing: 0.0) {
            WebView(config: self.webConfig,
                    action: self.$action,
                    state: self.$state,
                    restrictedPages: nil)
                .onReceive(self.reloadState.$shouldReload) { shouldReload in
                    if shouldReload {
                        if let url = URL(string: address) {
                            self.action = .load(URLRequest(url: url))
                        }
                        self.reloadState.shouldReload = false
                    }
                }
        }
        .onAppear {
            if let url = URL(string: address) {
                self.action = .load(URLRequest(url: url))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Button("r", action: {
                print("Cmd+R pressed")
                self.reloadWebView()
            })
            .keyboardShortcut(KeyEquivalent("r"), modifiers: [.command])
            .opacity(0.0)
        )
    }
}

enum WebViewHelper {
    static let reloadState = ReloadState()

    static func clean() {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        print("[WebCacheCleaner] All cookies deleted")

        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                print("[WebCacheCleaner] Record \(record) deleted")
            }
            self.reloadState.shouldReload = true
        }
    }
}

struct MainUI_Previews: PreviewProvider {
    static var previews: some View {
        MainUI()
    }
}
