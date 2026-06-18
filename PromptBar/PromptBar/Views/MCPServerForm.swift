//
//  MCPServerForm.swift
//  PromptBar
//

import SwiftUI

struct MCPServerForm: View {
    enum Mode {
        case add
        case edit(MCPServer)
    }

    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var name: String
    @State private var baseURL: String
    @State private var authHeader: String
    @State private var symbolName: String
    @State private var tintHex: String
    @State private var errorMessage: String?

    private let symbolOptions: [String] = [
        "powerplug", "bolt.fill", "atom", "puzzlepiece.extension.fill",
        "network", "shippingbox", "doc.text.magnifyingglass", "checklist"
    ]
    private let tintOptions: [String] = [
        "#B96BFF", "#5BC0EB", "#FF7A8A", "#3DBE8B",
        "#F5A623", "#7A7AFF", "#FF8C42", "#00C2FF"
    ]

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _baseURL = State(initialValue: "")
            _authHeader = State(initialValue: "")
            _symbolName = State(initialValue: "powerplug")
            _tintHex = State(initialValue: "#B96BFF")
        case .edit(let server):
            _name = State(initialValue: server.name)
            _baseURL = State(initialValue: server.baseURL)
            _authHeader = State(initialValue: server.authHeader)
            _symbolName = State(initialValue: server.symbolName)
            _tintHex = State(initialValue: server.tintHex)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                labelled("Display Name") {
                    TextField("e.g. Issue Tracker", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                labelled("Server URL") {
                    TextField("https://mcp.example.com/v1", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
                labelled("Auth header (optional)") {
                    TextField("e.g. Authorization: Bearer ...", text: $authHeader)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
                Text("If your server uses a bearer token, paste it as 'Authorization: Bearer <token>'. Custom header keys also work, e.g. 'X-API-Key: <token>'.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                appearance

                if let error = errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button(isEdit ? "Save" : "Add Server") { commit() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 6)
            }
            .padding(22)
        }
        .frame(width: 520, height: 540)
        .background(GlassBackdrop())
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: tintHex).opacity(0.25))
                    .frame(width: 44, height: 44)
                Image(systemName: symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(hex: tintHex))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(isEdit ? "Edit MCP Server" : "Add MCP Server")
                    .font(.title3.weight(.semibold))
                Text("Connect any HTTP MCP server. Tools it exposes become available to your native chats.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                ForEach(symbolOptions, id: \.self) { symbol in
                    Button { symbolName = symbol } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(symbol == symbolName
                                          ? Color(hex: tintHex).opacity(0.35)
                                          : Color.gray.opacity(0.15))
                            )
                            .foregroundStyle(symbol == symbolName ? Color(hex: tintHex) : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Color")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            HStack(spacing: 10) {
                ForEach(tintOptions, id: \.self) { hex in
                    Button { tintHex = hex } label: {
                        Circle().fill(Color(hex: hex)).frame(width: 26, height: 26)
                            .overlay(
                                Circle().strokeBorder(
                                    Color.primary.opacity(hex == tintHex ? 0.9 : 0),
                                    lineWidth: 2
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func labelled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func commit() {
        guard let sanitized = MCPServer.sanitized(name: name, baseURL: baseURL) else {
            errorMessage = "Enter a valid name and URL."
            return
        }
        // Dismiss first, mutate next runloop tick. See QuickAddView.commit().
        let pendingMode = mode
        let pendingSanitized = sanitized
        let pendingAuth = authHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        let pendingSymbol = symbolName
        let pendingTint = tintHex
        dismiss()
        DispatchQueue.main.async {
            switch pendingMode {
            case .add:
                var s = pendingSanitized
                s.authHeader = pendingAuth
                s.symbolName = pendingSymbol
                s.tintHex = pendingTint
                store.addMCPServer(s)
            case .edit(let original):
                var s = original
                s.name = pendingSanitized.name
                s.baseURL = pendingSanitized.baseURL
                s.authHeader = pendingAuth
                s.symbolName = pendingSymbol
                s.tintHex = pendingTint
                store.updateMCPServer(s)
            }
        }
    }
}
