//
//  SettingsView.swift
//  PromptBar
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var selection: Section = .web

    enum Section: Hashable {
        case web
        case endpoints
        case prompts
        case general
        case about
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            HStack(spacing: 0) {
                sidebar
                Divider().opacity(0.3)
                detail
            }
        }
        .frame(minWidth: 720, minHeight: 560)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PromptBar")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.top, 24)
                .padding(.bottom, 18)

            row(.web, label: "Web Chats", symbol: "globe")
            row(.endpoints, label: "API Endpoints", symbol: "key.fill")
            row(.prompts, label: "Prompts", symbol: "books.vertical")
            row(.general, label: "General", symbol: "gearshape")
            row(.about, label: "About", symbol: "info.circle")

            Spacer()
        }
        .frame(width: 200)
    }

    private func row(_ section: Section, label: String, symbol: String) -> some View {
        Button {
            selection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 18)
                Text(label)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selection == section ? Color.accentColor.opacity(0.22) : Color.clear)
                    .padding(.horizontal, 8)
            )
            .foregroundStyle(selection == section ? Color.accentColor : .primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .web: ServicesSettingsPane().environmentObject(store)
        case .endpoints: EndpointsSettingsPane().environmentObject(store)
        case .prompts: PromptLibraryView().environmentObject(store)
        case .general: GeneralSettingsPane()
        case .about: AboutPane()
        }
    }
}

// MARK: - Web services pane

private struct ServicesSettingsPane: View {
    @EnvironmentObject private var store: ChatStore
    @State private var showingQuickAdd = false
    @State private var editing: ChatService?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Web Chats")
                        .font(.title2.weight(.semibold))
                    Text("Wrap any web-based chat URL. You name it; PromptBar wraps it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showingQuickAdd = true
                } label: { Label("Add", systemImage: "plus") }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)

            Divider().opacity(0.3)

            if store.services.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.services) { service in
                        row(service).listRowBackground(Color.clear)
                    }
                    .onMove { source, dest in
                        store.moveServices(from: source, to: dest)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddView().environmentObject(store)
        }
        .sheet(item: $editing) { service in
            EditServiceView(service: service).environmentObject(store)
        }
    }

    private func row(_ service: ChatService) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(hex: service.tintHex).opacity(0.25))
                    .frame(width: 36, height: 36)
                Image(systemName: service.symbolName)
                    .foregroundStyle(Color(hex: service.tintHex))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name).font(.headline)
                Text(service.urlString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button { editing = service } label: { Image(systemName: "pencil") }.buttonStyle(.borderless)
            Button(role: .destructive) { store.remove(service) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("No web chats yet").font(.headline)
            Text("Click Add to wrap your first URL.").foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EditServiceView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    @State var service: ChatService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit Service").font(.title3.weight(.semibold))
            field("Name", $service.name)
            field("URL", $service.urlString)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") {
                    if let sanitized = ChatService.sanitized(name: service.name, urlString: service.urlString) {
                        var updated = service
                        updated.name = sanitized.name
                        updated.urlString = sanitized.urlString
                        store.update(updated)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 420)
        .background(GlassBackdrop())
    }

    private func field(_ title: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: binding).textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - API endpoints pane

private struct EndpointsSettingsPane: View {
    @EnvironmentObject private var store: ChatStore
    @State private var showingAdd = false
    @State private var editing: APIEndpoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Endpoints")
                        .font(.title2.weight(.semibold))
                    Text("Bring your own API key. PromptBar speaks the standard chat-completions schema, so any endpoint that supports it works.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { showingAdd = true } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)

            Divider().opacity(0.3)

            if store.endpoints.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.endpoints) { endpoint in
                        row(endpoint).listRowBackground(Color.clear)
                    }
                    .onMove { source, dest in
                        store.moveEndpoints(from: source, to: dest)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAdd) {
            APIEndpointForm(mode: .add).environmentObject(store)
        }
        .sheet(item: $editing) { endpoint in
            APIEndpointForm(mode: .edit(endpoint)).environmentObject(store)
        }
    }

    private func row(_ endpoint: APIEndpoint) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(hex: endpoint.tintHex).opacity(0.25))
                    .frame(width: 36, height: 36)
                Image(systemName: endpoint.symbolName)
                    .foregroundStyle(Color(hex: endpoint.tintHex))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(endpoint.name).font(.headline)
                    if KeychainHelper.hasKey(account: endpoint.keychainAccount) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "key.slash")
                            .font(.system(size: 9))
                            .foregroundStyle(.orange)
                    }
                }
                Text("\(endpoint.modelName)  •  \(endpoint.baseURL)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button { editing = endpoint } label: { Image(systemName: "pencil") }.buttonStyle(.borderless)
            Button(role: .destructive) { store.remove(endpoint) } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "key")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("No endpoints yet").font(.headline)
            Text("Add a chat-completions endpoint to chat natively from your menubar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 30)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - General

private struct GeneralSettingsPane: View {
    @AppStorage("promptbar.windowSize.v2") private var windowSize: String = "Medium"
    @AppStorage("promptbar.alwaysOnTop.v2") private var alwaysOnTop: Bool = false
    @AppStorage("promptbar.autoUpdateEnabled.v2") private var autoUpdate: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("General").font(.title2.weight(.semibold))

                box("Window") {
                    HStack {
                        Text("Default size")
                        Spacer()
                        Picker("", selection: $windowSize) {
                            ForEach(AppDelegate.windowSizes, id: \.name) { entry in
                                Text(entry.name).tag(entry.name)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                    }
                    Toggle("Always on top", isOn: $alwaysOnTop)
                }

                box("Updates") {
                    Toggle("Check for updates on launch", isOn: $autoUpdate)
                    Text("Updates come from GitHub Releases. No analytics, no tracking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                box("Privacy") {
                    Text("PromptBar does not create accounts and does not collect personal data. Web chats run inside isolated WebViews; API endpoints send your messages directly to the URL you configured. API keys are stored in the macOS Keychain.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Clean Cookies & Cache") { WebViewHelper.clean() }
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func box<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 8) { content() }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(.regularMaterial))
        }
    }
}

private struct AboutPane: View {
    var body: some View { AboutView().padding(.top, 20) }
}
