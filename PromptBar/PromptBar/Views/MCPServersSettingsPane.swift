//
//  MCPServersSettingsPane.swift
//  PromptBar
//

import SwiftUI

struct MCPServersSettingsPane: View {
    @EnvironmentObject private var store: ChatStore
    @State private var showingAdd = false
    @State private var editing: MCPServer?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MCP Servers")
                        .font(.title2.weight(.semibold))
                    Text("Connect Model Context Protocol servers (HTTP). The tools they expose become available inside native chats.")
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

            if store.mcpServers.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.mcpServers) { server in
                        row(server).listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAdd) {
            MCPServerForm(mode: .add).environmentObject(store)
        }
        .sheet(item: $editing) { server in
            MCPServerForm(mode: .edit(server)).environmentObject(store)
        }
    }

    private func row(_ server: MCPServer) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(hex: server.tintHex).opacity(0.25))
                    .frame(width: 36, height: 36)
                Image(systemName: server.symbolName)
                    .foregroundStyle(Color(hex: server.tintHex))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(server.name).font(.headline)
                    Circle()
                        .fill(server.enabled ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                }
                Text(server.baseURL)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { server.enabled },
                set: { _ in store.toggleMCPServer(server) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)

            Button { editing = server } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
            Button(role: .destructive) { store.removeMCPServer(server) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "powerplug")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("No MCP servers yet").font(.headline)
            Text("Add an HTTP MCP server endpoint to extend your chats with real tools.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 30)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
