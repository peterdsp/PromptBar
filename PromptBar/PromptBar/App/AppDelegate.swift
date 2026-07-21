//
//  AppDelegate.swift
//  PromptBar
//

import AppKit
import Combine
import HotKey
import SwiftUI
import SystemConfiguration

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // MARK: Window-size presets

    /// `name` is a stable identity: it's the persisted UserDefaults value and
    /// the menu item's representedObject. Never render it directly, run it
    /// through localizedSizeName() first.
    static let windowSizes: [(name: String, size: CGSize)] = [
        ("Small", CGSize(width: 420, height: 520)),
        ("Medium", CGSize(width: 520, height: 640)),
        ("Large", CGSize(width: 720, height: 820))
    ]

    static let windowSizeMenuID = NSUserInterfaceItemIdentifier("promptbar.menu.windowSize")

    static func localizedSizeName(_ name: String) -> String {
        switch name {
        case "Small": return String(localized: "Small")
        case "Medium": return String(localized: "Medium")
        case "Large": return String(localized: "Large")
        default: return name
        }
    }

    private let windowSizeKey = "promptbar.windowSize.v2"
    private let alwaysOnTopKey = "promptbar.alwaysOnTop.v2"

    // MARK: Mode state

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private(set) var popover: NSPopover!
    private var mainWindow: NSWindow?

    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    private(set) var pendingDownload: (filename: String, handler: (URL?) -> Void, download: AnyObject)? = nil

    // MARK: Hotkeys

    private let globalToggleHotKey = HotKey(key: .o, modifiers: [.option, .command])
    private var localEditHotKeys: [HotKey] = []

    private var alwaysOnTop: Bool {
        get { UserDefaults.standard.bool(forKey: alwaysOnTopKey) }
        set { UserDefaults.standard.set(newValue, forKey: alwaysOnTopKey) }
    }

    private var store: ChatStore { .shared }
    private var prefs: AppPreferences { .shared }
    private var cancellables: Set<AnyCancellable> = []

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        MarketingSeed.runIfRequested()
        #endif
        #if EXTERNAL_DISTRIBUTION
        let licenseStore = LicenseStore.shared
        if !licenseStore.isLicensed {
            // Trial gating: start the clock on first launch, block when it
            // runs out, allow free use in between.
            if licenseStore.trialExpired {
                presentLicenseEntry()
                return
            }
            licenseStore.startTrialIfNeeded()
            scheduleTrialTick()
        }
        #endif

        if !prefs.hasCompletedOnboarding {
            presentOnboarding()
            return
        }
        bootForCurrentMode()
    }

    #if EXTERNAL_DISTRIBUTION
    /// Refresh the trial ticker hourly so the "days remaining" banner stays
    /// honest without us recomputing on every redraw. Cheap.
    private func scheduleTrialTick() {
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let store = LicenseStore.shared
            store.trialTick = Date()
            // If the trial just expired this hour, block immediately.
            if store.trialExpired && !store.isLicensed {
                self.presentLicenseEntry()
            }
        }
    }
    #endif

    @objc func openLicenseEntry() {
        #if EXTERNAL_DISTRIBUTION
        presentLicenseEntry()
        #endif
    }

    #if EXTERNAL_DISTRIBUTION
    private var licenseWindow: NSWindow?

    private func presentLicenseEntry() {
        NSApp.setActivationPolicy(.regular)

        let view = LicenseEntryView { [weak self] _ in
            guard let self = self else { return }
            self.licenseWindow?.close()
            self.licenseWindow = nil
            if !self.prefs.hasCompletedOnboarding {
                self.presentOnboarding()
            } else {
                self.bootForCurrentMode()
            }
        }

        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "PromptBar"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 580, height: 540))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        licenseWindow = window
    }
    #endif

    private func bootForCurrentMode() {
        // The status item now exists in .window too, not just .menubar, so
        // the full menu is always one click away and never depends on the
        // Dock. .hidden is left alone on purpose: no Dock icon and no
        // menubar icon is the entire point of that mode, and forcing an icon
        // there would make it indistinguishable from .menubar.
        if prefs.windowMode != .hidden {
            constructStatusItem()
            constructPopover()
            constructMenu()
        }
        wireGlobalHotKey()
        observeStoreChanges()

        // Window mode needs a real menubar (App / Edit / Window / Help).
        if prefs.windowMode == .window {
            constructAppMainMenu()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch self.prefs.windowMode {
            case .menubar:
                NSApp.setActivationPolicy(.accessory)
            case .window:
                NSApp.setActivationPolicy(.regular)
                self.showMainWindow()
            case .hidden:
                NSApp.setActivationPolicy(.accessory)
                // No window, no menubar icon, hotkey-only access.
            }
        }
    }

    // MARK: - Main menu (window mode only)

    private func constructAppMainMenu() {
        let appName = ProcessInfo.processInfo.processName

        let main = NSMenu()

        // -- Application menu (first slot, displayed as the app's name in bold) --
        let appMenuItem = NSMenuItem()
        main.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(makeItem("About \(appName)", action: #selector(openAbout), key: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(makeItem("Settings…", action: #selector(openSettings), key: ","))
        #if EXTERNAL_DISTRIBUTION
        appMenu.addItem(makeItem("Activate License…", action: #selector(openLicenseEntry), key: ""))
        #endif
        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(servicesItem)
        appMenu.addItem(.separator())

        let hide = NSMenuItem(title: "Hide \(appName)",
                              action: #selector(NSApplication.hide(_:)),
                              keyEquivalent: "h")
        appMenu.addItem(hide)

        let hideOthers = NSMenuItem(title: "Hide Others",
                                    action: #selector(NSApplication.hideOtherApplications(_:)),
                                    keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)

        appMenu.addItem(NSMenuItem(title: "Show All",
                                   action: #selector(NSApplication.unhideAllApplications(_:)),
                                   keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))

        // -- File --
        let fileMenuItem = NSMenuItem()
        main.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(NSMenuItem(title: "Close",
                                    action: #selector(NSWindow.performClose(_:)),
                                    keyEquivalent: "w"))

        // -- Edit --
        let editMenuItem = NSMenuItem()
        main.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(NSMenuItem(title: "Undo",
                                    action: Selector(("undo:")),
                                    keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo",
                              action: Selector(("redo:")),
                              keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut",
                                    action: #selector(NSText.cut(_:)),
                                    keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy",
                                    action: #selector(NSText.copy(_:)),
                                    keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste",
                                    action: #selector(NSText.paste(_:)),
                                    keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Delete",
                                    action: #selector(NSText.delete(_:)),
                                    keyEquivalent: ""))
        editMenu.addItem(NSMenuItem(title: "Select All",
                                    action: #selector(NSStandardKeyBindingResponding.selectAll(_:)),
                                    keyEquivalent: "a"))
        editMenu.addItem(.separator())
        let findItem = NSMenuItem(title: "Find",
                                  action: #selector(NSResponder.complete(_:)),
                                  keyEquivalent: "f")
        editMenu.addItem(findItem)

        // -- View --
        let viewMenuItem = NSMenuItem()
        main.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        for entry in Self.windowSizes {
            let item = NSMenuItem(title: Self.localizedSizeName(entry.name),
                                  action: #selector(changeWindowSize(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = entry.name
            viewMenu.addItem(item)
        }
        viewMenu.addItem(.separator())
        viewMenu.addItem(makeItem(String(localized: "Reload"),
                                  action: #selector(reloadCurrentWebView), key: "r"))

        // -- Window --
        let windowMenuItem = NSMenuItem()
        main.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        let promptbarWindowItem = NSMenuItem(title: "PromptBar",
                                             action: #selector(showOrFocusMainWindow),
                                             keyEquivalent: "0")
        promptbarWindowItem.target = self
        windowMenu.addItem(promptbarWindowItem)
        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(title: "Minimize",
                                      action: #selector(NSWindow.performMiniaturize(_:)),
                                      keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom",
                                      action: #selector(NSWindow.performZoom(_:)),
                                      keyEquivalent: ""))
        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(title: "Bring All to Front",
                                      action: #selector(NSApplication.arrangeInFront(_:)),
                                      keyEquivalent: ""))

        // -- Help --
        let helpMenuItem = NSMenuItem()
        main.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        NSApp.helpMenu = helpMenu
        let github = NSMenuItem(title: "PromptBar on GitHub",
                                action: #selector(openHomepage),
                                keyEquivalent: "")
        github.target = self
        helpMenu.addItem(github)
        #if EXTERNAL_DISTRIBUTION
        helpMenu.addItem(makeItem("Check for Updates", action: #selector(openAbout), key: ""))
        #endif

        NSApp.mainMenu = main
    }

    @objc private func openHomepage() {
        if let url = URL(string: "https://github.com/peterdsp/PromptBar") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Onboarding

    private func presentOnboarding() {
        NSApp.setActivationPolicy(.regular)

        let view = OnboardingView { [weak self] chosenUseCase, selectedMCPs, launchMode, hotKeyEnabled in
            guard let self = self else { return }
            // Onboarding offers menubar or dock only. .hidden strips every
            // affordance at once and stays a deliberate Settings choice
            // rather than something to fall into on first run.
            self.prefs.windowMode = launchMode
            self.prefs.hotKeyEnabled = hotKeyEnabled
            self.prefs.hasCompletedOnboarding = true
            self.applyUseCase(chosenUseCase)
            self.installRecommendedMCPs(selectedMCPs)
            self.onboardingWindow?.close()
            self.onboardingWindow = nil
            self.bootForCurrentMode()
        }
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "Welcome to PromptBar"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 620, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    private func applyUseCase(_ useCase: UseCase) {
        guard useCase != .custom else { return }
        // Only seed if the user hasn't already saved their own prompts.
        guard store.prompts.isEmpty else { return }
        for prompt in useCase.seedPrompts {
            store.addPrompt(prompt)
        }
    }

    private func installRecommendedMCPs(_ suggestions: [MCPSuggestion]) {
        for suggestion in suggestions {
            // Don't double-install if the user re-runs onboarding.
            guard !store.mcpServers.contains(where: {
                $0.baseURL.caseInsensitiveCompare(suggestion.urlString) == .orderedSame
            }) else { continue }
            store.addMCPServer(suggestion.makeServer())
        }
    }

    // MARK: Status item

    private func constructStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        statusItem.behavior = []

        guard let button = statusItem.button else { return }

        // Pick the most visible icon source available. AppIcon (full color) first,
        // then the bundled MenuBarIcon (template), then SF Symbol, then text only.
        if let appIcon = NSImage(named: "AppIcon") {
            let sized = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
                appIcon.draw(in: rect)
                return true
            }
            button.image = sized
        } else if let bundled = NSImage(named: "MenuBarIcon") {
            bundled.isTemplate = true
            button.image = bundled
        } else if let icon = NSImage(systemSymbolName: "bubble.left.and.bubble.right.fill",
                                     accessibilityDescription: "PromptBar") {
            icon.isTemplate = true
            button.image = icon
        }

        // Always set a label too so the slot is wide and impossible to miss.
        button.title = "PromptBar"
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        button.imagePosition = button.image == nil ? .noImage : .imageLeft
        button.imageHugsTitle = true
        button.toolTip = "PromptBar (⌥⌘O)"
        button.action = #selector(handleMenubarClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleMenubarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            removeMenu()
            primaryToggle()
        }
    }

    /// Top-level toggle, swaps based on mode.
    private func primaryToggle() {
        switch prefs.windowMode {
        case .menubar:
            togglePopover()
        case .window, .hidden:
            // In both window-bearing modes the hotkey shows OR hides the window.
            if let window = mainWindow, window.isVisible, window.isKeyWindow {
                window.orderOut(nil)
            } else {
                showMainWindow()
            }
        }
    }

    // MARK: Popover

    private func constructPopover() {
        popover = NSPopover()
        popover.delegate = self
        popover.behavior = .transient
        popover.animates = true
        // Match the Liquid Glass content so the system arrow doesn't look pasted on.
        popover.appearance = NSAppearance(named: .vibrantDark)

        let size = persistedWindowSize()
        popover.contentSize = size
        popover.contentViewController = makePopoverHostingController(size: size)
    }

    private func makePopoverHostingController(size: CGSize) -> NSViewController {
        let root = PopupRootView()
            .environmentObject(store)
            .frame(width: size.width, height: size.height)
        let controller = NSHostingController(rootView: AnyView(root))
        controller.view.frame = CGRect(origin: .zero, size: size)
        return controller
    }

    func refreshPopupContent() {
        if let popover = popover {
            let size = popover.contentSize
            popover.contentViewController = makePopoverHostingController(size: size)
        }
        if let main = mainWindow {
            main.contentViewController = makeWindowHostingController(size: main.contentLayoutRect.size)
        }
    }

    private func persistedWindowSize() -> CGSize {
        let saved = UserDefaults.standard.string(forKey: windowSizeKey) ?? "Medium"
        return Self.windowSizes.first(where: { $0.name == saved })?.size
            ?? CGSize(width: 520, height: 640)
    }

    func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            teardownLocalHotKeys()
        } else {
            NSApplication.shared.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            applyAlwaysOnTopBehavior()
            setupLocalEditHotKeys()
        }
    }

    private func applyAlwaysOnTopBehavior() {
        guard let window = popover.contentViewController?.view.window else { return }
        if alwaysOnTop {
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            popover.behavior = .applicationDefined
        } else {
            window.level = .floating
            popover.behavior = .transient
        }
    }

    // MARK: Main window (window mode)

    private func makeWindowHostingController(size: CGSize) -> NSViewController {
        let root = PopupRootView()
            .environmentObject(store)
            .frame(minWidth: 380, minHeight: 420)
        let controller = NSHostingController(rootView: AnyView(root))
        controller.view.frame = CGRect(origin: .zero, size: size)
        return controller
    }

    private func showMainWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let size = persistedWindowSize()
        let controller = makeWindowHostingController(size: size)
        let window = NSWindow(contentViewController: controller)
        window.title = "PromptBar"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.setContentSize(size)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.minSize = NSSize(width: 380, height: 420)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = window
    }

    /// Window-menu entry that re-opens the main window after the user closed it.
    /// Required by App Store Guideline 4: there must be a way back to the main
    /// window from the menu bar when the user dismisses it.
    @objc func showOrFocusMainWindow() {
        showMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if prefs.windowMode == .window {
            showMainWindow()
            return true
        }
        return false
    }

    // MARK: Right-click menu

    /// The status item's menu. This is the app's complete surface: every
    /// feature has to be reachable from here, because in .menubar mode
    /// (the default) there is no Dock icon and no main menu to fall back on.
    func constructMenu() {
        let m = NSMenu()
        m.delegate = self

        let primaryTitle = prefs.windowMode == .window
            ? String(localized: "Show Window")
            : String(localized: "Open")
        m.addItem(makeItem(primaryTitle, action: #selector(primaryToggleAction), key: ""))
        m.addItem(.separator())

        addTargetItems(to: m)

        m.addItem(makeItem(String(localized: "Prompt Library…"),
                           action: #selector(openPromptLibrary), key: "l"))
        m.addItem(makeItem(String(localized: "MCP Servers…"),
                           action: #selector(openMCPServers), key: ""))

        let addItem = NSMenuItem(title: String(localized: "Add"), action: nil, keyEquivalent: "")
        let addMenu = NSMenu()
        addMenu.addItem(makeItem(String(localized: "Web Chat…"),
                                 action: #selector(openWebChatSettings), key: ""))
        addMenu.addItem(makeItem(String(localized: "API Endpoint…"),
                                 action: #selector(openEndpointSettings), key: ""))
        addItem.submenu = addMenu
        m.addItem(addItem)
        m.addItem(.separator())

        m.addItem(makeItem(String(localized: "Settings…"), action: #selector(openSettings), key: ","))
        m.addItem(makeItem(String(localized: "About PromptBar"), action: #selector(openAbout), key: ""))
        #if EXTERNAL_DISTRIBUTION
        // Previously only in the main menu, which is built for .window mode
        // only. A menubar user had no way to enter a license at all.
        m.addItem(makeItem(String(localized: "Activate License…"),
                           action: #selector(openLicenseEntry), key: ""))
        m.addItem(makeItem(String(localized: "Check for Updates…"),
                           action: #selector(checkForUpdatesAction), key: ""))
        #endif
        m.addItem(.separator())

        let sizeItem = NSMenuItem(title: String(localized: "Window Size"), action: nil, keyEquivalent: "")
        sizeItem.identifier = Self.windowSizeMenuID
        let sizeMenu = NSMenu()
        for entry in Self.windowSizes {
            let item = NSMenuItem(title: Self.localizedSizeName(entry.name),
                                  action: #selector(changeWindowSize(_:)),
                                  keyEquivalent: "")
            item.target = self
            // The unlocalized name is the identity; the title is display only.
            item.representedObject = entry.name
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        m.addItem(sizeItem)

        addWindowModeItems(to: m)

        if prefs.windowMode == .menubar {
            let aotItem = NSMenuItem(title: String(localized: "Always on Top"),
                                     action: #selector(toggleAlwaysOnTop(_:)),
                                     keyEquivalent: "")
            aotItem.target = self
            aotItem.state = alwaysOnTop ? .on : .off
            m.addItem(aotItem)
        }

        m.addItem(.separator())
        m.addItem(makeItem(String(localized: "Reload"), action: #selector(reloadCurrentWebView), key: "r"))
        m.addItem(makeItem(String(localized: "Clean Cookies & Cache"),
                           action: #selector(cleanCookiesAction), key: ""))

        m.addItem(.separator())
        let quitItem = NSMenuItem(title: String(localized: "Quit PromptBar"),
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        m.addItem(quitItem)

        menu = m
        updateWindowSizeMenuState()
    }

    /// Service/endpoint switching and New Chat, which previously existed only
    /// as pills inside the popover.
    private func addTargetItems(to m: NSMenu) {
        guard !store.services.isEmpty || !store.endpoints.isEmpty else {
            // Nothing configured yet: point at the thing that fixes that
            // rather than showing an empty submenu.
            let empty = NSMenuItem(title: String(localized: "No chats yet"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            m.addItem(empty)
            m.addItem(.separator())
            return
        }

        let switchItem = NSMenuItem(title: String(localized: "Switch To"), action: nil, keyEquivalent: "")
        let switchMenu = NSMenu()
        for service in store.services {
            let item = NSMenuItem(title: service.name,
                                  action: #selector(selectWebTarget(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = service.id
            if case .web(let id) = store.selectedTarget, id == service.id { item.state = .on }
            switchMenu.addItem(item)
        }
        if !store.services.isEmpty && !store.endpoints.isEmpty {
            switchMenu.addItem(.separator())
        }
        for endpoint in store.endpoints {
            let item = NSMenuItem(title: endpoint.name,
                                  action: #selector(selectAPITarget(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = endpoint.id
            if case .api(let id) = store.selectedTarget, id == endpoint.id { item.state = .on }
            switchMenu.addItem(item)
        }
        switchItem.submenu = switchMenu
        m.addItem(switchItem)

        // New Chat only means something for API endpoints; web chats are
        // whatever the site shows.
        if case .api = store.selectedTarget {
            m.addItem(makeItem(String(localized: "New Chat"), action: #selector(newChatAction), key: "n"))
        }
        m.addItem(.separator())
    }

    /// Mode switching from the menu. Previously Settings-only, and it told
    /// you to restart by hand.
    private func addWindowModeItems(to m: NSMenu) {
        let modeItem = NSMenuItem(title: String(localized: "Window Mode"), action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()
        for mode in WindowMode.allCases {
            let item = NSMenuItem(title: mode.displayName,
                                  action: #selector(changeWindowMode(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = prefs.windowMode == mode ? .on : .off
            modeMenu.addItem(item)
        }
        modeItem.submenu = modeMenu
        m.addItem(modeItem)
    }

    private func makeItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: Menu actions

    @objc private func selectWebTarget(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let service = store.services.first(where: { $0.id == id }) else { return }
        store.select(service)
        refreshPopupContent()
        showCurrentSurface()
    }

    @objc private func selectAPITarget(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let endpoint = store.endpoints.first(where: { $0.id == id }) else { return }
        store.select(endpoint)
        refreshPopupContent()
        showCurrentSurface()
    }

    @objc private func newChatAction() {
        guard case .api(let id) = store.selectedTarget,
              let endpoint = store.endpoints.first(where: { $0.id == id }) else { return }
        _ = store.startNewConversation(for: endpoint)
        refreshPopupContent()
        showCurrentSurface()
    }

    /// Bring the right surface forward for the current mode after a menu
    /// action, so picking something from the menu actually shows it.
    private func showCurrentSurface() {
        switch prefs.windowMode {
        case .menubar:
            if !popover.isShown { togglePopover() }
        case .window, .hidden:
            showMainWindow()
        }
    }

    @objc private func changeWindowMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = WindowMode(rawValue: raw),
              mode != prefs.windowMode else { return }

        prefs.windowMode = mode

        // bootForCurrentMode only runs at launch and sets activation policy,
        // builds the main menu, and constructs the status item, so switching
        // live would need a teardown path that doesn't exist. Relaunching is
        // honest and takes a second. Warn first: .hidden has no icon at all.
        let alert = NSAlert()
        alert.messageText = String(localized: "Restart PromptBar to switch mode?")
        if mode == .hidden {
            alert.informativeText = String(
                localized: "Hidden mode removes both the Dock icon and the menubar icon. You'll reach PromptBar with ⌥⌘O only."
            )
        } else {
            alert.informativeText = String(localized: "PromptBar needs to restart to apply the new window mode.")
        }
        alert.addButton(withTitle: String(localized: "Restart Now"))
        alert.addButton(withTitle: String(localized: "Later"))
        if alert.runModal() == .alertFirstButtonReturn {
            relaunch()
        }
    }

    private func relaunch() {
        AppRelauncher.relaunch()
    }

    #if EXTERNAL_DISTRIBUTION
    @objc private func checkForUpdatesAction() {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        Task { @MainActor in
            let result = await UpdateChecker.check(currentVersion: current)
            let alert = NSAlert()
            switch result {
            case .upToDate(let version):
                alert.messageText = String(localized: "You're up to date")
                alert.informativeText = String(localized: "PromptBar \(version) is the latest version.")
                alert.addButton(withTitle: String(localized: "OK"))
                alert.runModal()
            case .updateAvailable(let latest, let url, _):
                alert.messageText = String(localized: "PromptBar \(latest) is available")
                alert.informativeText = String(localized: "You're running \(current).")
                alert.addButton(withTitle: String(localized: "Download"))
                alert.addButton(withTitle: String(localized: "Later"))
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.open(url)
                }
            case .failure:
                alert.messageText = String(localized: "Couldn't check for updates")
                alert.informativeText = String(localized: "Check your connection and try again.")
                alert.addButton(withTitle: String(localized: "OK"))
                alert.runModal()
            }
        }
    }
    #endif

    func menuDidClose(_ menu: NSMenu) {
        removeMenu()
    }

    private func showMenu() {
        // Rebuild every time: Switch To, New Chat and the mode/size check
        // marks all depend on live state, and the menu is otherwise only
        // built once at launch.
        constructMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    private func removeMenu() {
        statusItem.menu = nil
    }

    private func updateWindowSizeMenuState() {
        // Look up by identifier, not title: the title is localized, so
        // item(withTitle: "Window Size") finds nothing outside English and
        // the checkmarks silently stop tracking the real size.
        guard let sizeMenu = menu?.items
            .first(where: { $0.identifier == Self.windowSizeMenuID })?.submenu else { return }
        let current = popover?.contentSize ?? mainWindow?.frame.size ?? persistedWindowSize()
        for item in sizeMenu.items {
            guard let name = item.representedObject as? String,
                  let entry = Self.windowSizes.first(where: { $0.name == name }) else { continue }
            item.state = (entry.size == current) ? .on : .off
        }
    }

    // MARK: Menu actions

    @objc private func primaryToggleAction() {
        primaryToggle()
    }

    @objc private func openSettings() {
        presentSettings(pane: .web)
    }

    // Selectors can't carry an enum, so each deep-link gets a thin @objc
    // entry point. These are what make Prompts and MCP reachable from the
    // menubar at all; before, they existed only inside the Settings sidebar.
    @objc private func openPromptLibrary() { presentSettings(pane: .prompts) }
    @objc private func openMCPServers() { presentSettings(pane: .mcp) }
    @objc private func openWebChatSettings() { presentSettings(pane: .web) }
    @objc private func openEndpointSettings() { presentSettings(pane: .endpoints) }
    @objc private func openGeneralSettings() { presentSettings(pane: .general) }

    private func presentSettings(pane: SettingsView.Section) {
        // An existing window keeps whatever pane it's on: recreating it would
        // throw away unsaved form state in the pane the user is looking at.
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(initialSection: pane)
            .environmentObject(store)
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "PromptBar Settings"
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 720, height: 560))
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func openAbout() {
        if let window = aboutWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(rootView: AboutView())
        let window = NSWindow(contentViewController: controller)
        window.title = "About PromptBar"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 420, height: 440))
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow = window
    }

    @objc private func changeWindowSize(_ sender: NSMenuItem) {
        // representedObject carries the unlocalized name. Matching on the
        // title would break the moment the menu isn't in English.
        guard let name = sender.representedObject as? String,
              let entry = Self.windowSizes.first(where: { $0.name == name }) else { return }
        popover?.contentSize = entry.size
        if let window = mainWindow {
            window.setContentSize(entry.size)
        }
        UserDefaults.standard.set(entry.name, forKey: windowSizeKey)
        updateWindowSizeMenuState()
        refreshPopupContent()
    }

    @objc private func toggleAlwaysOnTop(_ sender: NSMenuItem) {
        let newValue = !alwaysOnTop
        alwaysOnTop = newValue
        sender.state = newValue ? .on : .off
        applyAlwaysOnTopBehavior()
    }

    @objc private func reloadCurrentWebView() {
        WebViewHelper.reloadState.shouldReload = true
    }

    @objc private func cleanCookiesAction() {
        WebViewHelper.clean()
    }

    // MARK: Hotkey

    private func wireGlobalHotKey() {
        guard prefs.hotKeyEnabled else {
            globalToggleHotKey.keyUpHandler = nil
            return
        }
        globalToggleHotKey.keyUpHandler = { [weak self] in
            Task { @MainActor in self?.primaryToggle() }
        }
    }

    // MARK: Combine wiring

    private func observeStoreChanges() {
        let serviceChange = store.$services.map { _ in () }.eraseToAnyPublisher()
        let endpointChange = store.$endpoints.map { _ in () }.eraseToAnyPublisher()
        let targetChange = store.$selectedTarget.map { _ in () }.eraseToAnyPublisher()

        Publishers.MergeMany(serviceChange, endpointChange, targetChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshPopupContent()
            }
            .store(in: &cancellables)
    }

    // MARK: Network reachability (used by popup)

    func isInternetAvailable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        guard let reachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else { return false }
        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else { return false }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }

    // MARK: Local edit hot keys (kept so Cmd-C/V/X/Z/A reach WebView while popover is up)

    private func setupLocalEditHotKeys() {
        teardownLocalHotKeys()

        let cmd: NSEvent.ModifierFlags = [.command]
        let pairs: [(Key, Selector)] = [
            (.c, #selector(NSText.copy(_:))),
            (.v, #selector(NSText.paste(_:))),
            (.x, #selector(NSText.cut(_:))),
            (.a, #selector(NSStandardKeyBindingResponding.selectAll(_:)))
        ]

        for (key, selector) in pairs {
            let hk = HotKey(key: key, modifiers: cmd)
            hk.keyDownHandler = {
                NSApp.sendAction(selector, to: nil, from: nil)
            }
            localEditHotKeys.append(hk)
        }

        let undoKey = HotKey(key: .z, modifiers: cmd)
        undoKey.keyDownHandler = {
            NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
        }
        localEditHotKeys.append(undoKey)
    }

    private func teardownLocalHotKeys() {
        localEditHotKeys.removeAll()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverWillClose(_ notification: Notification) {
        teardownLocalHotKeys()
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow { settingsWindow = nil }
        if window === aboutWindow { aboutWindow = nil }
        if window === mainWindow { mainWindow = nil }
        if window === onboardingWindow { onboardingWindow = nil }
        #if EXTERNAL_DISTRIBUTION
        if window === licenseWindow { licenseWindow = nil }
        #endif
    }
}
