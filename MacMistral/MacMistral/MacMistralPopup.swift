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
    override func loadView() {
        // create a hosting controller with your SwiftUI view
        let hostingController = NSHostingController(rootView: MainUI())
        self.view = hostingController.view
        self.view.frame = CGRect(origin: .zero, size: .init(width: 500, height: 600))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let appDelegate: AppDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        var size = appDelegate.popover?.contentSize ?? CGSize.zero
        size.width += event.deltaX
        size.height += event.deltaY
        // Update popover size depend on your reference
        appDelegate.popover?.contentSize = size
    }
}

struct MainUI: View {
    @State private var action = WebViewAction.idle
    @State private var state = WebViewState.empty
    @State private var address = "https://chat.mistral.ai/chat/"

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
            //Image(systemName: "arrow.down")
        }
        .onAppear {
            if let url = URL(string: address) {
                self.action = .load(URLRequest(url: url))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

enum WebViewHelper {
    static func clean() {
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        print("[WebCacheCleaner] All cookies deleted")

        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
                print("[WebCacheCleaner] Record \(record) deleted")
            }
        }
    }
}

struct MainUI_Previews: PreviewProvider {
    static var previews: some View {
        MainUI()
    }
}
