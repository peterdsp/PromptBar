//
//  AboutView.swift
//  PromptBar
//

import SwiftUI

struct AboutView: View {
    @State private var isChecking = false
    @State private var statusMessage: String?
    @State private var updateURL: URL?
    @State private var updateAvailable = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ","
    }

    var body: some View {
        ZStack {
            GlassBackdrop()

            VStack(spacing: 18) {
                Spacer().frame(height: 6)

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.regularMaterial)
                        .frame(width: 96, height: 96)
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 78, height: 78)
                    } else {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 2) {
                    Text("PromptBar")
                        .font(.title.weight(.semibold))
                    Text("Version \(version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("A lightweight menubar wrapper for any web-based chat. You bring the URL; PromptBar gives it a home.")
                    .multilineTextAlignment(.center)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 28)

                HStack(spacing: 12) {
                    Button {
                        if let url = URL(string: "https://peterdsp.dev") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Developer Site", systemImage: "person.crop.circle")
                    }

                    Group {
                        if updateAvailable {
                            Button(action: checkForUpdates) {
                                Label("Download Update", systemImage: "arrow.down.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(action: checkForUpdates) {
                                if isChecking {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Label("Check for Updates", systemImage: "arrow.clockwise")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .disabled(isChecking)
                }

                if let status = statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(24)
        }
    }

    private func checkForUpdates() {
        if updateAvailable, let url = updateURL {
            NSWorkspace.shared.open(url)
            return
        }
        isChecking = true
        statusMessage = nil
        Task {
            let result = await UpdateChecker.check(currentVersion: version)
            await MainActor.run {
                isChecking = false
                switch result {
                case .upToDate(let v):
                    updateAvailable = false
                    statusMessage = "You're on the latest version (\(v))."
                case .updateAvailable(let latest, let url, _):
                    updateAvailable = true
                    updateURL = url
                    statusMessage = "Version \(latest) is available."
                case .failure:
                    statusMessage = "Couldn't check for updates."
                }
            }
        }
    }
}
