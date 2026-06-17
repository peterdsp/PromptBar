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

    static let windowSizes: [(name: String, size: CGSize)] = [
        ("Small", CGSize(width: 420, height: 520)),
        ("Medium", CGSize(width: 520, height: 640)),
        ("Large", CGSize(width: 720, height: 820))
    ]

    private let windowSizeKey = "promptbar.windowSize.v2"
    private let alwaysOnTopKey = "promptbar.alwaysOnTop.v2"

    // MARK: Menubar state

    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private(set) var popover: NSPopover!

    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?

    private(set) var pendingDownload: (filename: String, handler: (URL?) -> Void, download: AnyObject)? = nil

    // MARK: Hotkeys

    private let globalToggleHotKey = HotKey(key: .o, modifiers: [.option, .command])
    private var localEditHotKeys: [HotKey] = []

    private var alwaysOnTop: Bool {
        get { UserDefaults.standard.bool(forKey: alwaysOnTopKey) }
        set { UserDefaults.standard.set(newValue, forKey: alwaysOnTopKey) }
    }

    private var store: ChatStore { .shared }
    private var cancellables: Set<AnyCancellable> = []

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let icon = NSImage(systemSymbolName: "bubble.left.and.bubble.right.fill",
                               accessibilityDescription: "PromptBar")
            icon?.isTemplate = true
            button.image = icon
            button.action = #selector(handleMenubarClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        constructPopover()
        constructMenu()

        globalToggleHotKey.keyUpHandler = { [weak self] in
            Task { @MainActor in self?.togglePopover() }
        }

        // Reload popup content whenever the user changes/adds/removes services or endpoints.
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

    // MARK: Menubar click

    @objc private func handleMenubarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            removeMenu()
            togglePopover()
        }
    }

    // MARK: Popover

    private func constructPopover() {
        popover = NSPopover()
        popover.delegate = self
        popover.behavior = .transient
        popover.animates = true

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
        let size = popover.contentSize
        popover.contentViewController = makePopoverHostingController(size: size)
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

    // MARK: Right-click menu

    func constructMenu() {
        let m = NSMenu()
        m.delegate = self

        m.addItem(makeItem("Open", action: #selector(openPopoverAction), key: ""))
        m.addItem(.separator())

        m.addItem(makeItem("Settings…", action: #selector(openSettings), key: ","))
        m.addItem(makeItem("About PromptBar", action: #selector(openAbout), key: ""))
        m.addItem(.separator())

        let sizeItem = NSMenuItem(title: "Window Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for entry in Self.windowSizes {
            let item = NSMenuItem(title: entry.name,
                                  action: #selector(changeWindowSize(_:)),
                                  keyEquivalent: "")
            item.target = self
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        m.addItem(sizeItem)

        let aotItem = NSMenuItem(title: "Always on Top",
                                 action: #selector(toggleAlwaysOnTop(_:)),
                                 keyEquivalent: "")
        aotItem.target = self
        aotItem.state = alwaysOnTop ? .on : .off
        m.addItem(aotItem)

        m.addItem(.separator())
        m.addItem(makeItem("Reload", action: #selector(reloadCurrentWebView), key: "r"))
        m.addItem(makeItem("Clean Cookies & Cache", action: #selector(cleanCookiesAction), key: ""))

        m.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit PromptBar",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        m.addItem(quitItem)

        menu = m
        updateWindowSizeMenuState()
    }

    private func makeItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    func menuDidClose(_ menu: NSMenu) {
        removeMenu()
    }

    private func showMenu() {
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    private func removeMenu() {
        statusItem.menu = nil
    }

    private func updateWindowSizeMenuState() {
        guard let sizeMenu = menu?.item(withTitle: "Window Size")?.submenu else { return }
        let current = popover.contentSize
        for item in sizeMenu.items {
            if let entry = Self.windowSizes.first(where: { $0.name == item.title }) {
                item.state = (entry.size == current) ? .on : .off
            }
        }
    }

    // MARK: Menu actions

    @objc private func openPopoverAction() {
        if !popover.isShown { togglePopover() }
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView()
            .environmentObject(store)
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = "PromptBar Settings"
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 640, height: 560))
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
        guard let entry = Self.windowSizes.first(where: { $0.name == sender.title }) else { return }
        popover.contentSize = entry.size
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
    }
}
