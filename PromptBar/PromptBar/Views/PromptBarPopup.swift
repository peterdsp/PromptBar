//
//  PromptBarPopup.swift
//  PromptBar
//

import AppKit
import SwiftUI
import WebKit

/// Popup root displayed inside the menubar NSPopover.
/// Hosts either a WebView (for user-added web chats) or a native chat view
/// (for user-added OpenAI-compatible API endpoints), whichever target is selected.
struct PopupRootView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var showingQuickAdd = false
    @State private var showingAPIAdd = false

    @State private var address: String = ""
    @State private var webAction: WebViewAction = .idle
    @State private var webState: WebViewState = .empty
    @ObservedObject private var reloadState = WebViewHelper.reloadState

    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 0) {
                topBar
                Divider().opacity(0.3)
                content
            }
        }
        .onAppear { syncAddressToSelection() }
        .onChange(of: store.selectedTarget) { _, _ in
            syncAddressToSelection()
        }
        .onReceive(reloadState.$shouldReload) { reload in
            guard reload else { return }
            if let url = URL(string: address) {
                webAction = .load(URLRequest(url: url))
            }
            reloadState.shouldReload = false
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddView().environmentObject(store)
        }
        .sheet(isPresented: $showingAPIAdd) {
            APIEndpointForm(mode: .add).environmentObject(store)
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.services) { service in
                        webPill(service)
                    }
                    ForEach(store.endpoints) { endpoint in
                        apiPill(endpoint)
                    }
                    addMenu
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            Spacer(minLength: 0)
            actionsCluster
                .padding(.trailing, 10)
        }
        .frame(height: 44)
        .background(.thinMaterial)
    }

    private func webPill(_ service: ChatService) -> some View {
        let isActive: Bool = {
            if case .web(let id) = store.selectedTarget { return id == service.id }
            return false
        }()
        return Button {
            store.select(service)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: service.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                Text(service.name).lineLimit(1)
            }
        }
        .buttonStyle(GlassPillStyle(
            isActive: isActive,
            tint: Color(hex: service.tintHex)
        ))
        .contextMenu {
            Button("Remove", role: .destructive) { store.remove(service) }
        }
    }

    private func apiPill(_ endpoint: APIEndpoint) -> some View {
        let isActive: Bool = {
            if case .api(let id) = store.selectedTarget { return id == endpoint.id }
            return false
        }()
        return Button {
            store.select(endpoint)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: endpoint.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                Text(endpoint.name).lineLimit(1)
                Image(systemName: "key.fill")
                    .font(.system(size: 8))
                    .opacity(0.6)
            }
        }
        .buttonStyle(GlassPillStyle(
            isActive: isActive,
            tint: Color(hex: endpoint.tintHex)
        ))
        .contextMenu {
            Button("Remove", role: .destructive) { store.remove(endpoint) }
        }
    }

    private var addMenu: some View {
        Menu {
            Button {
                showingQuickAdd = true
            } label: {
                Label("Web Chat", systemImage: "globe")
            }
            Button {
                showingAPIAdd = true
            } label: {
                Label("API Endpoint (BYO Key)", systemImage: "key.fill")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text(store.services.isEmpty && store.endpoints.isEmpty ? "Add" : "")
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.2))
            )
            .foregroundStyle(Color.accentColor)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var actionsCluster: some View {
        HStack(spacing: 4) {
            if case .web = store.selectedTarget {
                actionButton(symbol: "arrow.clockwise", help: "Reload") {
                    if let url = URL(string: address) {
                        webAction = .load(URLRequest(url: url))
                    }
                }
                actionButton(symbol: "arrow.left", help: "Back") {
                    webAction = .goBack
                }
                .disabled(!webState.canGoBack)
                actionButton(symbol: "arrow.right", help: "Forward") {
                    webAction = .goForward
                }
                .disabled(!webState.canGoForward)
            }
            actionButton(symbol: "gearshape", help: "Settings") {
                (NSApp.delegate as? AppDelegate)?
                    .perform(NSSelectorFromString("openSettings"))
            }
        }
    }

    private func actionButton(symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(Circle().fill(.thickMaterial))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch store.selectedTarget {
        case .web(let id):
            if let service = store.services.first(where: { $0.id == id }) {
                webContent(service)
            } else {
                emptyState
            }
        case .api(let id):
            if let endpoint = store.endpoints.first(where: { $0.id == id }) {
                NativeChatView(endpoint: endpoint)
                    .environmentObject(store)
                    .id(endpoint.id)
            } else {
                emptyState
            }
        case .none:
            emptyState
        }
    }

    @ViewBuilder
    private func webContent(_ service: ChatService) -> some View {
        if URL(string: service.urlString) != nil {
            ZStack {
                WebView(
                    config: WebViewConfig(),
                    action: $webAction,
                    state: $webState
                )
                if webState.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(8)
                        .background(.regularMaterial, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(10)
                }
            }
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            addWebAction: { showingQuickAdd = true },
            addAPIAction: { showingAPIAdd = true }
        )
    }

    // MARK: Sync

    private func syncAddressToSelection() {
        guard case .web(let id) = store.selectedTarget,
              let service = store.services.first(where: { $0.id == id }) else {
            address = ""
            return
        }
        address = service.urlString
        if let target = URL(string: address) {
            webAction = .load(URLRequest(url: target))
        }
    }
}

private struct EmptyStateView: View {
    let addWebAction: () -> Void
    let addAPIAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.regularMaterial)
                    .frame(width: 110, height: 110)
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("Two ways to chat")
                    .font(.title3.weight(.semibold))
                Text("Wrap any web chat in your menubar, or bring your own API key for a native streaming chat. Both are private, both are yours.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding(.horizontal, 28)
            }

            HStack(spacing: 10) {
                Button(action: addWebAction) {
                    Label("Add Web Chat", systemImage: "globe")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                Button(action: addAPIAction) {
                    Label("Add API Endpoint", systemImage: "key.fill")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Legacy NSViewController kept for compatibility; not used by the new hosting flow.
class PromptBarPopup: NSViewController {
    override func loadView() { view = NSView() }
}
