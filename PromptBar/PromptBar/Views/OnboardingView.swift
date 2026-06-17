//
//  OnboardingView.swift
//  PromptBar
//
//  Five-page first-launch flow.
//  1. Intro + differentiators.
//  2. Mode picker (menubar / window).
//  3. Use case picker (coding / design / research / ops / everyday / custom).
//  4. Theatrical "Refining your experience" loading screen.
//  5. Ready summary, fires the finish handler.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: (WindowMode, UseCase) -> Void

    @State private var page: Int = 0
    @State private var pickedMode: WindowMode = .menubar
    @State private var pickedUseCase: UseCase = .everyday

    private let totalPages = 5

    var body: some View {
        ZStack {
            GlassBackdrop()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    introPage.tag(0)
                    modePage.tag(1)
                    useCasePage.tag(2)
                    refiningPage.tag(3)
                    readyPage.tag(4)
                }
                .tabViewStyle(.automatic)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
        }
        .frame(width: 660, height: 620)
    }

    // MARK: Page 1, intro

    private var introPage: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)

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
                Text("Your AI workbench in the menubar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                bullet("sparkles",
                       title: "Yours to shape",
                       body: "Ships empty. No bundled providers, no third-party logos. You add the URLs and the keys you actually use.")
                bullet("key.fill",
                       title: "Bring your own API key",
                       body: "Native streaming chat against any chat-completions endpoint. Keys live in the macOS Keychain, never UserDefaults, never iCloud.")
                bullet("powerplug",
                       title: "Wire it to your real tools",
                       body: "Connect MCP servers. Your AI can read and act on your real workspace, design tools, issue trackers, source control, your dashboards.")
                bullet("lock.shield.fill",
                       title: "Private by design",
                       body: "No analytics, no telemetry, no remote config. Updates check GitHub Releases directly.")
            }
            .padding(.horizontal, 36)
            .frame(maxWidth: 600)

            Spacer()
        }
        .padding(.top, 16)
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

    // MARK: Page 3, use case

    private var useCasePage: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 4)

            VStack(spacing: 4) {
                Text("What will you use PromptBar for?")
                    .font(.title2.weight(.semibold))
                Text("Pick the closest one. We'll set up the right defaults.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(UseCase.allCases) { useCase in
                    useCaseCard(useCase)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func useCaseCard(_ useCase: UseCase) -> some View {
        let selected = useCase == pickedUseCase
        return Button {
            pickedUseCase = useCase
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: useCase.tintHex).opacity(selected ? 0.32 : 0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: useCase.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: useCase.tintHex))
                }
                Text(useCase.title).font(.subheadline.weight(.semibold))
                Text(useCase.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(height: 130, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        selected ? Color(hex: useCase.tintHex).opacity(0.85) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Page 4, theatrical refining

    @State private var refineProgress: Double = 0
    @State private var refineStep: Int = 0

    private let refineSteps: [(String, String)] = [
        ("paintbrush.pointed.fill", "Calibrating Liquid Glass…"),
        ("brain.head.profile", "Tuning prompt defaults to your style…"),
        ("books.vertical.fill", "Loading prompt library…"),
        ("powerplug", "Reserving MCP slots for your stack…"),
        ("checkmark.seal.fill", "Almost there…")
    ]

    private var refiningPage: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 22)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
                    .frame(width: 96, height: 96)
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 6) {
                Text("Refining your experience")
                    .font(.title2.weight(.semibold))
                Text("Personalising PromptBar for \(pickedUseCase.title.lowercased()).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            ProgressView(value: refineProgress)
                .progressViewStyle(.linear)
                .tint(Color.accentColor)
                .frame(width: 320)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(refineSteps.indices, id: \.self) { i in
                    HStack(spacing: 10) {
                        Image(systemName: i < refineStep ? "checkmark.circle.fill" : refineSteps[i].0)
                            .foregroundStyle(i < refineStep ? Color.green : .secondary)
                            .frame(width: 18)
                        Text(refineSteps[i].1)
                            .font(.callout)
                            .foregroundStyle(i <= refineStep ? .primary : .secondary)
                        Spacer()
                        if i == refineStep {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 6)
            .frame(maxWidth: 420)

            Spacer()
        }
        .onAppear { runRefineAnimation() }
    }

    private func runRefineAnimation() {
        refineProgress = 0
        refineStep = 0
        // Walk through the steps over ~3 seconds, then auto-advance.
        let stepDuration: Double = 0.55
        for i in 0...refineSteps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.refineStep = i
                    self.refineProgress = Double(i) / Double(self.refineSteps.count)
                }
                if i == self.refineSteps.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation { self.page = 4 }
                    }
                }
            }
        }
    }

    // MARK: Page 5, ready

    private var readyPage: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 18)

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.18))
                    .frame(width: 92, height: 92)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color.green)
            }

            VStack(spacing: 4) {
                Text("You're set")
                    .font(.title.weight(.semibold))
                Text("Here's what we provisioned. You can change all of it later.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                summaryRow("books.vertical.fill",
                           title: "\(pickedUseCase.seedPrompts.count) prompts added",
                           body: pickedUseCase.seedPrompts.isEmpty
                                ? "Add your own from Settings → Prompts."
                                : "Reach them with ⌘P inside any chat.")
                summaryRow("macwindow",
                           title: "\(pickedMode.displayName) mode",
                           body: pickedMode == .menubar
                                ? "⌥⌘O toggles the popover from anywhere."
                                : "⌥⌘O brings the window forward.")
                summaryRow("powerplug",
                           title: "MCP slots ready",
                           body: pickedUseCase.suggestedMCPURLs.isEmpty
                                ? "Add servers from Settings → MCP Servers when you're ready."
                                : "Generic URL hints saved under Settings → MCP Servers.")
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: 460)

            Spacer()
        }
    }

    private func summaryRow(_ symbol: String, title: String, body: String) -> some View {
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

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { i in
                Circle()
                    .fill(i == page ? Color.accentColor : Color.gray.opacity(0.35))
                    .frame(width: 6, height: 6)
            }

            Spacer()

            if page > 0 && page != 3 && page != 4 {
                Button("Back") {
                    withAnimation { page -= 1 }
                }
                .keyboardShortcut(.cancelAction)
            }

            switch page {
            case 0, 1:
                Button("Continue") {
                    withAnimation { page += 1 }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            case 2:
                Button(pickedUseCase == .custom ? "Skip Setup" : "Continue") {
                    withAnimation { page += 1 }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            case 3:
                // Auto-advances; no button.
                Text("").frame(height: 28)
            case 4:
                Button("Get Started") {
                    onFinish(pickedMode, pickedUseCase)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }
}
