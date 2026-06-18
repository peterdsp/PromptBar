//
//  PromptLibraryView.swift
//  PromptBar
//

import SwiftUI

struct PromptLibraryView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var editing: PromptItem?
    @State private var showingAdd = false
    @State private var query: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt Library")
                        .font(.title2.weight(.semibold))
                    Text("Save your best prompts. Reuse them in any chat with ⌘P.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showingAdd = true
                } label: {
                    Label("New Prompt", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)

            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search prompts and tags…", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Divider().opacity(0.3)

            if store.prompts.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filtered) { item in
                        promptRow(item)
                            .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAdd) {
            PromptEditorSheet(mode: .add).environmentObject(store)
        }
        .sheet(item: $editing) { item in
            PromptEditorSheet(mode: .edit(item)).environmentObject(store)
        }
    }

    private var filtered: [PromptItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.prompts }
        return store.prompts.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.body.localizedCaseInsensitiveContains(q) ||
            $0.tags.joined(separator: " ").localizedCaseInsensitiveContains(q)
        }
    }

    private func promptRow(_ item: PromptItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.25))
                    .frame(width: 32, height: 32)
                Image(systemName: "doc.text").foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.headline)
                Text(item.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !item.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(item.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.gray.opacity(0.2)))
                        }
                    }
                }
            }
            Spacer()
            Button { editing = item } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
            Button(role: .destructive) {
                store.deletePrompt(item)
            } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("No prompts saved").font(.headline)
            Text("Add a prompt, it'll be one tap away in every chat.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct PromptEditorSheet: View {
    enum Mode {
        case add
        case edit(PromptItem)
    }

    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    @State private var titleText: String
    @State private var bodyText: String
    @State private var tagsText: String

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add:
            _titleText = State(initialValue: "")
            _bodyText = State(initialValue: "")
            _tagsText = State(initialValue: "")
        case .edit(let item):
            _titleText = State(initialValue: item.title)
            _bodyText = State(initialValue: item.body)
            _tagsText = State(initialValue: item.tags.joined(separator: ", "))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isEdit ? "Edit Prompt" : "New Prompt")
                .font(.title3.weight(.semibold))

            TextField("Title", text: $titleText).textFieldStyle(.roundedBorder)

            TextEditor(text: $bodyText)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))

            TextField("Tags (comma-separated, optional)", text: $tagsText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") { commit() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 460)
        .background(GlassBackdrop())
    }

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func commit() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Dismiss first, mutate next runloop tick. See QuickAddView.commit().
        let pendingMode = mode
        let pendingTitle = titleText
        let pendingBody = bodyText
        dismiss()
        DispatchQueue.main.async {
            switch pendingMode {
            case .add:
                store.addPrompt(PromptItem(title: pendingTitle, body: pendingBody, tags: tags))
            case .edit(let item):
                var updated = item
                updated.title = pendingTitle
                updated.body = pendingBody
                updated.tags = tags
                store.updatePrompt(updated)
            }
        }
    }
}
