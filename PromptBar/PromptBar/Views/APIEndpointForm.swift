//
//  APIEndpointForm.swift
//  PromptBar
//

import SwiftUI

struct APIEndpointForm: View {
    enum Mode {
        case add
        case edit(APIEndpoint)
    }

    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var name: String
    @State private var baseURL: String
    @State private var modelName: String
    @State private var systemPrompt: String
    @State private var apiKey: String = ""
    @State private var symbolName: String
    @State private var tintHex: String
    @State private var streamingEnabled: Bool
    @State private var errorMessage: String?

    /// Generic, non-branded URL hints. Plain text only.
    private let urlSuggestions: [String] = [
        "https://api.openai.com/v1",
        "https://api.groq.com/openai/v1",
        "https://api.together.xyz/v1",
        "https://api.deepinfra.com/v1/openai",
        "http://localhost:11434/v1",
        "http://localhost:1234/v1"
    ]

    private let symbolOptions: [String] = [
        "wand.and.stars", "sparkles", "brain.head.profile", "bolt.fill",
        "atom", "lightbulb", "terminal", "doc.text.magnifyingglass",
        "globe", "graduationcap", "cpu", "books.vertical"
    ]

    private let tintOptions: [String] = [
        "#3DBE8B", "#7A7AFF", "#FF7A8A", "#F5A623",
        "#00C2FF", "#B96BFF", "#FF8C42", "#5BC0EB"
    ]

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _baseURL = State(initialValue: "")
            _modelName = State(initialValue: "")
            _systemPrompt = State(initialValue: "")
            _symbolName = State(initialValue: "wand.and.stars")
            _tintHex = State(initialValue: "#3DBE8B")
            _streamingEnabled = State(initialValue: true)
        case .edit(let endpoint):
            _name = State(initialValue: endpoint.name)
            _baseURL = State(initialValue: endpoint.baseURL)
            _modelName = State(initialValue: endpoint.modelName)
            _systemPrompt = State(initialValue: endpoint.systemPrompt)
            _symbolName = State(initialValue: endpoint.symbolName)
            _tintHex = State(initialValue: endpoint.tintHex)
            _streamingEnabled = State(initialValue: endpoint.streamingEnabled)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                fields
                appearance
                advanced
                suggestions

                if let error = errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                footer
            }
            .padding(22)
        }
        .frame(width: 560, height: 700)
        .background(GlassBackdrop())
    }

    // MARK: Sections

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
                Text(isEdit ? "Edit Endpoint" : "Add API Endpoint")
                    .font(.title3.weight(.semibold))
                Text("Connect any chat-completions endpoint (standard schema).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 10) {
            labelled("Display Name") {
                TextField("e.g. My Inference Server", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            labelled("Base URL") {
                TextField("https://api.example.com/v1", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
            labelled("Model") {
                TextField("e.g. gpt-4o-mini, llama-3.1-70b", text: $modelName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
            labelled("API Key") {
                SecureField(isEdit ? "Leave blank to keep existing" : "Paste your API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            Text("API keys are stored in the macOS Keychain. They never leave your Mac except when sent to the URL above.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            labelled("System Prompt (optional)") {
                TextEditor(text: $systemPrompt)
                    .frame(minHeight: 70)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(.regularMaterial)
                    )
            }
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(symbolOptions, id: \.self) { symbol in
                    Button { symbolName = symbol } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(symbol == symbolName
                                          ? Color(hex: tintHex).opacity(0.35)
                                          : Color.gray.opacity(0.15))
                            )
                            .foregroundStyle(symbol == symbolName ? Color(hex: tintHex) : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Color").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 4)
            HStack(spacing: 10) {
                ForEach(tintOptions, id: \.self) { hex in
                    Button { tintHex = hex } label: {
                        Circle().fill(Color(hex: hex)).frame(width: 26, height: 26)
                            .overlay(
                                Circle().strokeBorder(
                                    Color.primary.opacity(hex == tintHex ? 0.9 : 0), lineWidth: 2
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var advanced: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Stream responses (Server-Sent Events)", isOn: $streamingEnabled)
            Text("Disable if your endpoint doesn't support streaming.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Common base URLs")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(urlSuggestions, id: \.self) { u in
                    Button { baseURL = u } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link").font(.system(size: 10)).foregroundStyle(.secondary)
                            Text(u).font(.system(size: 11, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 7).fill(.regularMaterial))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(isEdit ? "Save" : "Add Endpoint") { commit() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: Helpers

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func labelled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func commit() {
        guard let sanitized = APIEndpoint.sanitized(
            name: name,
            baseURL: baseURL,
            model: modelName
        ) else {
            errorMessage = "Enter a valid name, URL, and model."
            return
        }

        switch mode {
        case .add:
            guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "An API key is required."
                return
            }
            var endpoint = sanitized
            endpoint.symbolName = symbolName
            endpoint.tintHex = tintHex
            endpoint.systemPrompt = systemPrompt
            endpoint.streamingEnabled = streamingEnabled
            store.add(endpoint, apiKey: apiKey)
        case .edit(let original):
            var updated = original
            updated.name = sanitized.name
            updated.baseURL = sanitized.baseURL
            updated.modelName = sanitized.modelName
            updated.systemPrompt = systemPrompt
            updated.symbolName = symbolName
            updated.tintHex = tintHex
            updated.streamingEnabled = streamingEnabled
            store.update(updated, apiKey: apiKey.isEmpty ? nil : apiKey)
        }

        dismiss()
    }
}
