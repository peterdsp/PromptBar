//
//  OnboardingView.swift
//  PromptBar
//
//  Shown once on first launch. Tells the user what PromptBar is,
//  why it is different, and asks how they want to use it
//  (menubar popover, or proper window like Safari/Claude).
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: (WindowMode) -> Void

    @State private var page: Int = 0
    @State private var pickedMode: WindowMode = .menubar

    private let totalPages = 2

    var body: some View {
        ZStack {
            GlassBackdrop()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    introPage.tag(0)
                    modePage.tag(1)
                }
                .tabViewStyle(.automatic)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
        }
        .frame(width: 620, height: 560)
    }

    // MARK: Page 1, intro

    private var introPage: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 10)

            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.regularMaterial)
                    .frame(width: 108, height: 108)
                if let icon = NSImage(named: "AppIcon") {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                } else {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 4) {
                Text("Welcome to PromptBar")
                    .font(.title.weight(.semibold))
                Text("Any chat. Any model. One keystroke away.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                bullet(
                    "sparkles",
                    title: "Yours to shape",
                    body: "Ships empty. No bundled providers, no third-party logos. You add the URLs and the keys you actually use."
                )
                bullet(
                    "key.fill",
                    title: "Bring your own API key",
                    body: "Native streaming chat against any chat-completions endpoint. Keys live in the macOS Keychain, never UserDefaults, never iCloud."
                )
                bullet(
                    "lock.shield.fill",
                    title: "Private by design",
                    body: "No analytics, no telemetry, no remote config. Updates check GitHub Releases directly."
                )
            }
            .padding(.horizontal, 36)
            .frame(maxWidth: 560)

            Spacer()
        }
        .padding(.top, 18)
    }

    private func bullet(_ symbol: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.20))
                    .frame(width: 32, height: 32)
                Image(systemName: symbol)
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(body).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Page 2, pick mode

    private var modePage: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 4)

            VStack(spacing: 4) {
                Text("How do you want to use it?")
                    .font(.title2.weight(.semibold))
                Text("You can change this later in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            HStack(spacing: 14) {
                modeCard(
                    mode: .menubar,
                    symbol: "menubar.dock.rectangle",
                    title: "Menubar",
                    body: "Lives at the top of your screen. Press ⌥⌘O from anywhere to summon the popover. No Dock icon, no window chrome."
                )
                modeCard(
                    mode: .window,
                    symbol: "macwindow",
                    title: "Window",
                    body: "Acts like Safari or Claude. Gets a Dock icon and its own window. The menubar icon stays as a quick toggle."
                )
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }

    private func modeCard(mode: WindowMode, symbol: String, title: String, body: String) -> some View {
        let selected = mode == pickedMode
        return Button {
            pickedMode = mode
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selected ? Color.accentColor.opacity(0.30) : Color.gray.opacity(0.18))
                        .frame(width: 60, height: 60)
                    Image(systemName: symbol)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(selected ? Color.accentColor : .primary)
                }
                Text(title).font(.title3.weight(.semibold))
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.accentColor : .secondary)
                    Text(selected ? "Selected" : "Tap to pick")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selected ? Color.accentColor : .secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        selected ? Color.accentColor.opacity(0.7) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Footer (Back / Continue / Get Started)

    private var footer: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { i in
                Circle()
                    .fill(i == page ? Color.accentColor : Color.gray.opacity(0.4))
                    .frame(width: 6, height: 6)
            }

            Spacer()

            if page > 0 {
                Button("Back") {
                    withAnimation { page -= 1 }
                }
                .keyboardShortcut(.cancelAction)
            }

            if page < totalPages - 1 {
                Button("Continue") {
                    withAnimation { page += 1 }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Get Started") {
                    onFinish(pickedMode)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }
}
