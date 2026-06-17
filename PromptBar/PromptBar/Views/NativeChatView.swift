//
//  NativeChatView.swift
//  PromptBar
//
//  Native streaming chat against a user-provided OpenAI-compatible endpoint.
//

import SwiftUI

struct NativeChatView: View {
    let endpoint: APIEndpoint
    @EnvironmentObject private var store: ChatStore

    @State private var conversation: Conversation
    @State private var input: String = ""
    @State private var isStreaming = false
    @State private var streamTask: Task<Void, Never>?
    @State private var liveDelta: String = ""
    @State private var errorMessage: String?
    @State private var showingPromptPicker = false

    init(endpoint: APIEndpoint) {
        self.endpoint = endpoint
        _conversation = State(initialValue:
            Conversation.empty(for: endpoint.id, systemPrompt: endpoint.systemPrompt)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            transcript
            Divider().opacity(0.3)
            composer
        }
        .background(GlassBackdrop())
        .sheet(isPresented: $showingPromptPicker) {
            PromptPickerSheet { item in
                if input.isEmpty { input = item.body }
                else { input += "\n\n" + item.body }
                showingPromptPicker = false
            }
            .environmentObject(store)
        }
        .onAppear { loadActiveConversation() }
        .onChange(of: store.activeConversationID) { _, _ in
            loadActiveConversation()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: endpoint.tintHex).opacity(0.25))
                    .frame(width: 26, height: 26)
                Image(systemName: endpoint.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: endpoint.tintHex))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(conversation.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(endpoint.modelName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            Menu {
                Button("New Chat") { newConversation() }
                Divider()
                ForEach(store.conversations(for: endpoint.id)) { c in
                    Button(c.title) {
                        conversation = c
                        store.activeConversationID = c.id
                    }
                }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.thickMaterial))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Conversation history")
            .frame(width: 32)

            Button {
                if isStreaming {
                    cancelStream()
                } else {
                    newConversation()
                }
            } label: {
                Image(systemName: isStreaming ? "stop.fill" : "plus.bubble")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.thickMaterial))
            }
            .buttonStyle(.plain)
            .help(isStreaming ? "Stop" : "New chat")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    // MARK: Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(visibleMessages) { msg in
                        MessageBubble(message: msg, tint: Color(hex: endpoint.tintHex))
                            .id(msg.id)
                    }
                    if isStreaming && !liveDelta.isEmpty {
                        MessageBubble(
                            message: ChatMessage(role: .assistant, content: liveDelta),
                            tint: Color(hex: endpoint.tintHex),
                            showCursor: true
                        )
                        .id("live")
                    }
                    if let err = errorMessage {
                        ErrorBanner(message: err)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .onChange(of: conversation.messages.count) { _, _ in
                withAnimation {
                    if let last = visibleMessages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    } else {
                        proxy.scrollTo("live", anchor: .bottom)
                    }
                }
            }
            .onChange(of: liveDelta) { _, _ in
                proxy.scrollTo("live", anchor: .bottom)
            }
        }
    }

    private var visibleMessages: [ChatMessage] {
        conversation.messages.filter { $0.role != .system }
    }

    // MARK: Composer

    /// Composer auto-grows from 1 line to a max of 6 lines as the user types.
    /// Approximation by line count is good enough; the chat composer doesn't
    /// need pixel-perfect wrap-aware sizing.
    private var composerHeight: CGFloat {
        let lineHeight: CGFloat = 18
        let minLines: CGFloat = 1
        let maxLines: CGFloat = 6
        let typedLines = CGFloat(input.components(separatedBy: "\n").count)
        let lines = min(maxLines, max(minLines, typedLines))
        return lines * lineHeight + 6
    }

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 6) {
                Button {
                    showingPromptPicker = true
                } label: {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.thinMaterial))
                }
                .buttonStyle(.plain)
                .help("Insert prompt from library")

                ZStack(alignment: .topLeading) {
                    if input.isEmpty {
                        Text("Message…")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $input)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                }
                .frame(height: composerHeight)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.regularMaterial)
                )

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(
                                input.trimmed.isEmpty || isStreaming
                                ? Color.gray.opacity(0.3)
                                : Color.accentColor
                            )
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(input.trimmed.isEmpty || isStreaming)
                .help("Send (⌘↩)")
            }

            Text("Your messages are sent directly from this Mac to the endpoint URL you configured. No relay.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
    }

    // MARK: Actions

    private func loadActiveConversation() {
        if let id = store.activeConversationID,
           let active = store.conversations.first(where: { $0.id == id }) {
            conversation = active
        } else {
            newConversation()
        }
    }

    private func newConversation() {
        cancelStream()
        let fresh = store.startNewConversation(for: endpoint)
        conversation = fresh
        errorMessage = nil
    }

    private func send() {
        let text = input.trimmed
        guard !text.isEmpty else { return }
        input = ""
        errorMessage = nil
        liveDelta = ""

        conversation.appendUser(text)
        store.updateConversation(conversation)

        let messagesForRequest = conversation.messages
        isStreaming = true

        streamTask = Task { @MainActor in
            let client = ChatAPIClient(endpoint: endpoint)
            var buffer = ""
            do {
                for try await delta in client.stream(messages: messagesForRequest) {
                    buffer += delta
                    liveDelta = buffer
                }
                conversation.appendAssistant(buffer.isEmpty ? "(no content)" : buffer)
                store.updateConversation(conversation)
            } catch {
                errorMessage = error.localizedDescription
            }
            liveDelta = ""
            isStreaming = false
        }
    }

    private func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
        if !liveDelta.isEmpty {
            conversation.appendAssistant(liveDelta + " …")
            store.updateConversation(conversation)
        }
        liveDelta = ""
        isStreaming = false
    }
}

// MARK: - Subviews

private struct MessageBubble: View {
    let message: ChatMessage
    let tint: Color
    var showCursor: Bool = false

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 4) {
                Text(isUser ? "You" : "Assistant")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(message.content + (showCursor ? "▍" : ""))
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isUser
                                  ? tint.opacity(0.22)
                                  : Color.gray.opacity(0.12))
                    )
            }
            .frame(maxWidth: 360, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

private struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.system(size: 11))
                .lineLimit(3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.red.opacity(0.18))
        )
        .foregroundStyle(.red)
    }
}

// MARK: - Prompt Picker sheet (used here AND from web chats)

struct PromptPickerSheet: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    let onPick: (PromptItem) -> Void

    @State private var query: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search prompts…", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(filtered) { item in
                        Button {
                            onPick(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.system(size: 13, weight: .semibold))
                                Text(item.body)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.thinMaterial)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if store.prompts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray").font(.title)
                                .foregroundStyle(.secondary)
                            Text("No saved prompts yet")
                                .font(.subheadline)
                            Text("Add prompts from Settings → Prompts.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 30)
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 420, height: 480)
        .background(GlassBackdrop())
    }

    private var filtered: [PromptItem] {
        guard !query.trimmed.isEmpty else { return store.prompts }
        return store.prompts.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.body.localizedCaseInsensitiveContains(query)
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
