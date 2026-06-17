//
//  QuickAddView.swift
//  PromptBar
//

import SwiftUI

struct QuickAddView: View {
    @ObservedObject var store: ChatStore = .shared
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var urlString: String = ""
    @State private var symbolName: String = "bubble.left.and.bubble.right"
    @State private var tintHex: String = "#7A7AFF"
    @State private var validationError: String?

    /// Plain-text URL suggestions only. No brand names, no logos, no trademarks.
    /// The user assigns a name themselves. Provided as a convenience so users
    /// don't need to type long URLs by hand.
    private let suggestedURLs: [String] = [
        "https://chat.openai.com/",
        "https://gemini.google.com/app",
        "https://aistudio.google.com/",
        "https://notebooklm.google.com/",
        "https://www.perplexity.ai/",
        "https://chat.mistral.ai/chat/",
        "https://chat.deepseek.com/",
        "https://copilot.microsoft.com/",
        "https://grok.com/",
        "https://www.meta.ai/",
        "https://you.com/",
        "https://poe.com/",
        "https://huggingface.co/chat/"
    ]

    private let symbolOptions: [String] = [
        "bubble.left.and.bubble.right",
        "sparkles",
        "wand.and.stars",
        "brain.head.profile",
        "lightbulb",
        "bolt.fill",
        "atom",
        "graduationcap",
        "globe",
        "terminal",
        "doc.text.magnifyingglass",
        "books.vertical"
    ]

    private let tintOptions: [String] = [
        "#7A7AFF", "#FF7A8A", "#3DBE8B", "#F5A623",
        "#00C2FF", "#B96BFF", "#FF8C42", "#5BC0EB"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                nameAndURLSection

                symbolPicker
                colorPicker

                Divider().opacity(0.4)

                Text("Common URLs")
                    .font(.headline)
                Text("Tap to copy a URL into the field above. You choose the name yourself.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                suggestionGrid

                if let error = validationError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Button("Add Service") { commit() }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.borderedProminent)
                        .disabled(name.trimmed.isEmpty || urlString.trimmed.isEmpty)
                }
                .padding(.top, 8)
            }
            .padding(22)
        }
        .frame(width: 520, height: 620)
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
                Text("Add a Web Chat")
                    .font(.title3.weight(.semibold))
                Text("Wrap any web chat URL in your menubar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var nameAndURLSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Display Name")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("e.g. Work Chat", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("URL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("https://example.com", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(symbolOptions, id: \.self) { symbol in
                    Button {
                        symbolName = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(symbol == symbolName
                                          ? Color(hex: tintHex).opacity(0.35)
                                          : Color.gray.opacity(0.15))
                            )
                            .foregroundStyle(symbol == symbolName ? Color(hex: tintHex) : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(tintOptions, id: \.self) { hex in
                    Button {
                        tintHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.primary.opacity(hex == tintHex ? 0.9 : 0.0), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var suggestionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(suggestedURLs, id: \.self) { url in
                Button {
                    urlString = url
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(url)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.regularMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commit() {
        guard let service = ChatService.sanitized(name: name, urlString: urlString) else {
            validationError = "Enter a valid name and an http(s) URL."
            return
        }
        var prepared = service
        prepared.symbolName = symbolName
        prepared.tintHex = tintHex
        store.add(prepared)
        dismiss()
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
