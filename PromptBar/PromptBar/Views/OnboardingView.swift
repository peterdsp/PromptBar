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
    /// (use case, selected MCP suggestions, show in Dock, hot key enabled)
    let onFinish: (UseCase, [MCPSuggestion], Bool, Bool) -> Void

    @State private var page: Int = 0
    @State private var maxReached: Int = 0
    @State private var pickedUseCase: UseCase = .everyday
    @State private var selectedMCPIDs: Set<UUID> = []
    @State private var showInDock: Bool = true
    @State private var hotKeyEnabled: Bool = true

    private let totalPages = 5

    var body: some View {
        ZStack {
            GlassBackdrop()

            VStack(spacing: 0) {
                progressStrip
                pageContent
                footer
            }
        }
        .frame(width: 660, height: 720)
        .onChange(of: page) { _, newValue in
            if newValue > maxReached { maxReached = newValue }
        }
        .onChange(of: pickedUseCase) { _, newCase in
            selectedMCPIDs = Set(newCase.recommendedMCPs.map(\.id))
        }
        .onAppear {
            selectedMCPIDs = Set(pickedUseCase.recommendedMCPs.map(\.id))
        }
    }

    /// Hairline progress strip across the top edge of the window.
    /// Replaces the default TabView segmented indicator with something subtle.
    private var progressStrip: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.95), Color.accentColor.opacity(0.55)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * progressFraction)
                    .animation(.easeOut(duration: 0.35), value: page)
            }
        }
        .frame(height: 3)
    }

    private var progressFraction: CGFloat {
        // 0 -> 0.25, 1 -> 0.5, 2 -> 0.75, 3 -> 1.0
        return CGFloat(page + 1) / CGFloat(totalPages)
    }

    @ViewBuilder
    private var pageContent: some View {
        ZStack {
            switch page {
            case 0: introPage.transition(.opacity)
            case 1: reviewsPage.transition(.opacity)
            case 2: useCasePage.transition(.opacity)
            case 3: refiningPage.transition(.opacity)
            case 4: readyPage.transition(.opacity)
            default: introPage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                Text("Your AI workbench, one keystroke away.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "command")
                    Text("Press ⌥⌘O from anywhere to summon PromptBar")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(Color.accentColor.opacity(0.15))
                )
                .padding(.top, 4)
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

            kujtoCallout
                .padding(.horizontal, 36)
                .frame(maxWidth: 600)

            Spacer()
        }
        .padding(.top, 16)
    }

    @State private var copiedInstall = false

    private var kujtoCallout: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#FFB347"), Color(hex: "#FF7A8A")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 36, height: 36)
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Companion project: Kujto")
                        .font(.headline)
                    Text("open source")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.gray.opacity(0.25)))
                        .foregroundStyle(.secondary)
                }
                Text("A tiny repo-versioned memory framework. Drop it in your project and every AI you use, including PromptBar, reads your conventions in every session.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button {
                        if let url = URL(string: "https://github.com/peterdsp/kujto") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        let cmd = "curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash"
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cmd, forType: .string)
                        copiedInstall = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            copiedInstall = false
                        }
                    } label: {
                        Label(copiedInstall ? "Copied" : "Copy install command",
                              systemImage: copiedInstall ? "checkmark" : "doc.on.doc")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
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

    // MARK: Page 2, reviews

    private struct Review: Identifiable {
        let id = UUID()
        let name: String
        let handle: String
        let body: String
    }

    /// Lightly edited from public Ko-fi reviews of the developer's earlier macOS
    /// menubar AI client. Third-party brand names are removed so the binary stays
    /// safe under App Store guideline 4.1.
    private let reviews: [Review] = [
        Review(
            name: "Florian Mathieu",
            handle: "@sh4ke",
            body: "After two weeks of use, I can't imagine a day of work without PromptBar. Easy to use, really fast, well integrated into macOS. A must have."
        ),
        Review(
            name: "Tim van der Voord",
            handle: "@timvandervoord",
            body: "Was looking for an AI chat client on Mac to interact without having to open the browser. This does the job. Great work."
        ),
        Review(
            name: "Olivier",
            handle: "@olivier",
            body: "Easy to install, easy to use, well integrated into macOS so it's available everywhere. The configurable keyboard shortcut to invoke PromptBar is a killer feature."
        ),
        Review(
            name: "Nicolas Z.",
            handle: "@nicolaszolotoff",
            body: "Excellent! A pure delight daily with the multiple AIs available. A happy customer."
        ),
        Review(
            name: "Steven",
            handle: "@steven",
            body: "Loving it. 5/5 for sure. The hotkey access from anywhere is exactly what I wanted."
        )
    ]

    private var reviewsPage: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 6)

            VStack(spacing: 4) {
                Text("What people are saying")
                    .font(.title2.weight(.semibold))
                Text("From early supporters of the project on Ko-fi.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(reviews) { review in
                        reviewCard(review)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 8)
            }

            Spacer(minLength: 0)
        }
    }

    private func reviewCard(_ review: Review) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(review.name)
                    .font(.subheadline.weight(.semibold))
                Text(review.handle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.yellow)
                        .font(.system(size: 9))
                }
            }
            Text(review.body)
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer().frame(height: 10)

                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 84, height: 84)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(Color.green)
                }

                VStack(spacing: 4) {
                    Text("You're set")
                        .font(.title.weight(.semibold))
                    Text("Pick which power-ups to install. You can change all of it later.")
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
                }
                .padding(.horizontal, 30)
                .frame(maxWidth: 460)

                if !pickedUseCase.recommendedMCPs.isEmpty {
                    recommendedMCPSection
                        .padding(.horizontal, 30)
                        .frame(maxWidth: 480)
                }

                launchOptions
                    .padding(.horizontal, 30)
                    .frame(maxWidth: 460)

                Spacer(minLength: 12)
            }
            .padding(.bottom, 16)
        }
    }

    private var recommendedMCPSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recommended MCP servers")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(allMCPsSelected ? "Deselect all" : "Select all") {
                    if allMCPsSelected {
                        selectedMCPIDs.removeAll()
                    } else {
                        selectedMCPIDs = Set(pickedUseCase.recommendedMCPs.map(\.id))
                    }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            ForEach(pickedUseCase.recommendedMCPs) { suggestion in
                mcpSuggestionCard(suggestion)
            }
            Text("Most servers need an auth token. Servers needing auth install disabled, flip them on in Settings → MCP Servers after you add the token.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var allMCPsSelected: Bool {
        let ids = pickedUseCase.recommendedMCPs.map(\.id)
        return !ids.isEmpty && ids.allSatisfy { selectedMCPIDs.contains($0) }
    }

    private func mcpSuggestionCard(_ suggestion: MCPSuggestion) -> some View {
        let isSelected = selectedMCPIDs.contains(suggestion.id)
        return Button {
            if isSelected { selectedMCPIDs.remove(suggestion.id) }
            else { selectedMCPIDs.insert(suggestion.id) }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: suggestion.tintHex).opacity(0.25))
                        .frame(width: 36, height: 36)
                    Image(systemName: suggestion.symbol)
                        .foregroundStyle(Color(hex: suggestion.tintHex))
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(suggestion.label).font(.callout.weight(.semibold))
                        if suggestion.needsAuth {
                            Text("auth")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.orange.opacity(0.25)))
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(suggestion.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(suggestion.urlString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.55) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var launchOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How should PromptBar launch?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)

            optionToggle(
                title: "Show in Dock",
                body: showInDock
                    ? "Acts like Safari or Claude with a Dock icon and a real window."
                    : "Runs in the background, no Dock icon. Use the hotkey to summon it.",
                isOn: $showInDock
            )

            optionToggle(
                title: "Enable ⌥⌘O hotkey",
                body: hotKeyEnabled
                    ? "Bring PromptBar forward from any app, even full screen."
                    : "Hotkey disabled. You'll need to click the Dock to open the window.",
                isOn: $hotKeyEnabled
            )

            if !showInDock && !hotKeyEnabled {
                Label("Pick at least one access method or you won't be able to open the app.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
    }

    private func optionToggle(title: String, body: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
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
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { i in
                    let reachable = i <= maxReached
                    Button {
                        guard reachable, i != page else { return }
                        // Don't allow jumping into the refining loader from a dot.
                        guard i != 3 else { return }
                        withAnimation { page = i }
                    } label: {
                        Circle()
                            .fill(i == page ? Color.accentColor : Color.gray.opacity(0.35))
                            .frame(width: 6, height: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(!reachable || i == 3)
                    .help(reachable ? "Go to step \(i + 1)" : "")
                }
            }

            Spacer()

            if page > 0 && page != 3 && page != 4 {
                Button("Back") {
                    withAnimation { page -= 1 }
                }
                .keyboardShortcut(.cancelAction)
            }

            switch page {
            case 0:
                Button("Continue") {
                    withAnimation { page += 1 }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            case 1:
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
                // Refining loader auto-advances; no button.
                Text("").frame(height: 28)
            case 4:
                Button("Get Started") {
                    let picks = pickedUseCase.recommendedMCPs.filter {
                        selectedMCPIDs.contains($0.id)
                    }
                    onFinish(pickedUseCase, picks, showInDock, hotKeyEnabled)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!showInDock && !hotKeyEnabled)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(.thinMaterial)
    }
}
