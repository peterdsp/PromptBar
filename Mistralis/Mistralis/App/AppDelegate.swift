//
//  AppDelegate.swift
//  Mistralis
//
//  Created by Petros Dhespollari on 16/3/24.
//

import Cocoa
import FirebaseCore
import FirebaseInstallations
import FirebaseRemoteConfig
import HotKey
import SwiftUI
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var alwaysOnTop: Bool = false
    var removeTexts: [String] = []  // Store fetched items here
    private var loadingView: NSView?

    var selectedAIChatTitle: String = "Mistralis"
    private let aiChatOptions: [String: String] = [
        "Mistral": "https://chat.mistral.ai/chat/",
        "ChatGPT": "https://chat.openai.com/#",
        "Gemini": "https://gemini.google.com/app",
        "DeepSeek": "https://chat.deepseek.com/",
        "Grok": "https://grok.com/",
    ]

    internal var windowSizeOptions: [String: CGSize] = [
        "Small": CGSize(width: 400, height: 300),
        "Medium": CGSize(width: 500, height: 600),
        "Large": CGSize(width: 700, height: 800),
    ]

    var chatOptions: [String: String] {
        return aiChatOptions
    }

    public var popover: NSPopover!
    private var menu: NSMenu!
    private let windowSizeKey = "selectedWindowSize"

    let hotKey = HotKey(key: .c, modifiers: [.shift, .command])  // Global hotkey

    var hotCKey: HotKey?
    var hotVKey: HotKey?
    var hotZKey: HotKey?
    var hotXKey: HotKey?
    var hotAKey: HotKey?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        FirebaseApp.configure()
        fetchSubscriptionConfig()
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength)
        NSApp.setActivationPolicy(.accessory)

        if let button = statusItem.button {
            let icon = NSImage(named: "MenuBarIcon")!.resized(
                to: CGSize(width: 14, height: 14))
            icon.isTemplate = true
            button.image = icon
            button.action = #selector(handleMenuIconAction(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Check if there is a saved AI chat title, set default to "Mistral" if not
        if let savedAIChatTitle = UserDefaults.standard.string(
            forKey: "selectedAIChatTitle")
        {
            selectedAIChatTitle = savedAIChatTitle
        } else {
            selectedAIChatTitle = "Mistral"
            UserDefaults.standard.set(
                selectedAIChatTitle, forKey: "selectedAIChatTitle")
        }

        constructPopover()
        constructMenu()

        // ---> NEW: Apply previously saved window size or default to Medium
        if let savedSizeName = UserDefaults.standard.string(
            forKey: windowSizeKey),
            let savedSize = windowSizeOptions[savedSizeName]
        {
            popover.contentSize = savedSize
        } else {
            let defaultSizeName = "Medium"
            popover.contentSize = windowSizeOptions[defaultSizeName]!
            UserDefaults.standard.set(defaultSizeName, forKey: windowSizeKey)
        }

        hotKey.keyUpHandler = {  // Global hotkey handler
            self.togglePopover()
        }

        NSApp.setActivationPolicy(.accessory)
    }

    @objc func handleMenuIconAction(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            removeMenu()
            togglePopover()
        }
    }

    func showLoadingView() {
        guard let window = popover.contentViewController?.view.window else {
            return
        }

        // Create loading overlay
        let loadingOverlay = NSView(frame: window.contentView!.bounds)
        loadingOverlay.wantsLayer = true
        loadingOverlay.layer?.backgroundColor =
            NSColor.black.withAlphaComponent(0.7).cgColor
        loadingOverlay.alphaValue = 0  // Start invisible for fade-in
        loadingOverlay.identifier = NSUserInterfaceItemIdentifier(
            "loadingOverlay")

        // Create spinning progress indicator
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .large
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)
        spinner.translatesAutoresizingMaskIntoConstraints = false

        // Create loading label
        let label = NSTextField(
            labelWithString: "Loading \(selectedAIChatTitle)...")
        label.font = NSFont.boldSystemFont(ofSize: 18)
        label.textColor = NSColor.white
        label.alignment = .center
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.wantsLayer = true  // ✅ Ensures the layer is created

        // Add views to overlay
        loadingOverlay.addSubview(spinner)
        loadingOverlay.addSubview(label)

        NSLayoutConstraint.activate([
            // Center spinner
            spinner.centerXAnchor.constraint(
                equalTo: loadingOverlay.centerXAnchor),
            spinner.centerYAnchor.constraint(
                equalTo: loadingOverlay.centerYAnchor, constant: -30),

            // Center label below spinner
            label.topAnchor.constraint(
                equalTo: spinner.bottomAnchor, constant: 15),
            label.centerXAnchor.constraint(
                equalTo: loadingOverlay.centerXAnchor),
        ])

        // Add overlay to window
        window.contentView?.addSubview(loadingOverlay)
        self.loadingView = loadingOverlay

        // 🔥 Fancy fade-in effect
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.3
                loadingOverlay.animator().alphaValue = 1
            }, completionHandler: nil)

        // 🔥 Bouncing effect for text (Now works!)
        let bounceAnimation = CABasicAnimation(keyPath: "position.y")
        bounceAnimation.duration = 0.6
        bounceAnimation.byValue = 10  // Moves 10 points up/down
        bounceAnimation.autoreverses = true
        bounceAnimation.repeatCount = .infinity
        bounceAnimation.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut)

        label.layer?.add(bounceAnimation, forKey: "bounce")
    }

    func hideLoadingView() {
        guard let loadingView = self.loadingView else { return }

        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.5  // Smooth fade-out over 0.5 seconds
                loadingView.animator().alphaValue = 0
            },
            completionHandler: {
                loadingView.removeFromSuperview()
                self.loadingView = nil
            })
    }

    func menuDidClose(_ menu: NSMenu) {
        removeMenu()
    }

    func fetchSubscriptionConfig() {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0  // Adjust for production
        remoteConfig.configSettings = settings

        remoteConfig.fetchAndActivate { status, error in
            if let error = error {
                print(
                    "⚠️ Error fetching remote config: \(error.localizedDescription)"
                )
                return
            }

            if status == .successFetchedFromRemote
                || status == .successUsingPreFetchedData
            {
                let remoteConfigValue = remoteConfig.configValue(
                    forKey: "subscriptions")

                // ✅ Check if the string is empty (since it's not optional!)
                let removeTextsJSON = remoteConfigValue.stringValue
                if removeTextsJSON.isEmpty {
                    print(
                        "⚠️ No valid JSON found in 'subscriptions' remote config or it's empty."
                    )
                    return
                }

                let removeTextsData = Data(removeTextsJSON.utf8)

                do {
                    self.removeTexts = try JSONDecoder().decode(
                        [String].self, from: removeTextsData)
                    print(
                        "✅ Successfully fetched subscriptions: \(self.removeTexts)"
                    )
                } catch {
                    print(
                        "⚠️ Failed to decode subscriptions JSON: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    func updateWindowLevel() {
        if let window = popover.contentViewController?.view.window {
            window.level = alwaysOnTop ? .statusBar : .normal
            if alwaysOnTop {
                window.collectionBehavior = [
                    .canJoinAllSpaces, .fullScreenAuxiliary,
                ]
            } else {
                window.level = .floating
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        updateWindowLevel()
    }

    func applicationDidResignActive(_ notification: Notification) {
        if alwaysOnTop, let window = popover.contentViewController?.view.window
        {
            window.level = .floating
            window.orderFrontRegardless()
        }
    }

    @objc func toggleAlwaysOnTop(sender: NSMenuItem) {
        alwaysOnTop.toggle()
        sender.state = alwaysOnTop ? .on : .off
        updateWindowLevel()
        updatePopoverBehavior()
    }

    @objc func didTapOne() {
        let aboutView = AboutView()
        let aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // Set window level to floating to keep it above other windows
        aboutWindow.level = .floating
        aboutWindow.center()
        aboutWindow.contentView = NSHostingView(rootView: aboutView)

        let aboutWindowController = AboutWindowController(window: aboutWindow)
        aboutWindowController.showWindow(nil)

        // Bring to front and maintain position
        aboutWindow.orderFrontRegardless()
    }

    @objc func didTapTwo() {
        WebViewHelper.clean()
    }

    @objc func changeAIChat(sender: NSMenuItem) {
        if let urlString = sender.representedObject as? String {
            selectedAIChatTitle = sender.title.trimmingCharacters(
                in: .whitespacesAndNewlines)
            let initialAddress =
                aiChatOptions[selectedAIChatTitle]
                ?? "https://chat.mistral.ai/chat/"
            let newHostingController = NSHostingController(
                rootView: MainUI(initialAddress: initialAddress))
            let newPopupContentViewController = MistralisPopup()
            newPopupContentViewController.hostingController =
                newHostingController
            popover.contentViewController = newPopupContentViewController
            popover.contentSize = newHostingController.view.fittingSize

            updateMenuItemsState()
            UserDefaults.standard.set(
                selectedAIChatTitle, forKey: "selectedAIChatTitle")
        }
    }

    @objc func changeWindowSize(sender: NSMenuItem) {
        if let newSize = windowSizeOptions[sender.title] {
            popover.contentSize = newSize

            // ---> NEW: Save the size name in UserDefaults
            UserDefaults.standard.set(sender.title, forKey: windowSizeKey)

            // Update the checkmark states
            updateWindowSizeMenuItemsState()
        }
    }

    func updateMenuItemsState() {
        if let changeChatAIMenuItem = menu.item(withTitle: "Change AI Chat"),
            let changeChatAISubmenu = changeChatAIMenuItem.submenu
        {
            for item in changeChatAISubmenu.items {
                item.state = (item.title == selectedAIChatTitle) ? .on : .off
            }
        }
    }

    func updateWindowSizeMenuItemsState() {
        if let windowSizeMenuItem = menu.item(withTitle: "Change Window Size"),
            let windowSizeSubmenu = windowSizeMenuItem.submenu
        {
            for item in windowSizeSubmenu.items {
                item.state =
                    (popover.contentSize == windowSizeOptions[item.title])
                    ? .on
                    : .off
            }
        }
    }

    func constructMenu() {
        menu = NSMenu()

        // About
        let aboutMenuItem = NSMenuItem(
            title: "About",
            action: #selector(didTapOne),
            keyEquivalent: "1"
        )
        menu.addItem(aboutMenuItem)

        // Clean Cookies
        let cleanCookiesMenuItem = NSMenuItem(
            title: "Clean Cookies",
            action: #selector(didTapTwo),
            keyEquivalent: "2"
        )
        menu.addItem(cleanCookiesMenuItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Change AI Chat Submenu
        let changeChatAIMenuItem = NSMenuItem(
            title: "Change AI Chat",
            action: nil,
            keyEquivalent: ""
        )
        let changeChatAISubmenu = NSMenu()

        let aiChatOrder = ["Mistral", "ChatGPT", "Gemini", "DeepSeek", "Grok"]
        for title in aiChatOrder {
            if let url = aiChatOptions[title] {
                let menuItem = NSMenuItem(
                    title: title,
                    action: #selector(changeAIChat(sender:)),
                    keyEquivalent: ""
                )
                menuItem.representedObject = url
                changeChatAISubmenu.addItem(menuItem)
            }
        }
        changeChatAIMenuItem.submenu = changeChatAISubmenu
        menu.addItem(changeChatAIMenuItem)

        // Change Window Size Submenu
        let changeWindowSizeMenuItem = NSMenuItem(
            title: "Change Window Size",
            action: nil,
            keyEquivalent: ""
        )
        let changeWindowSizeSubmenu = NSMenu()

        let sortedWindowSizeKeys = ["Small", "Medium", "Large"]
        for size in sortedWindowSizeKeys {
            if windowSizeOptions[size] != nil {
                let menuItem = NSMenuItem(
                    title: size,
                    action: #selector(changeWindowSize(sender:)),
                    keyEquivalent: ""
                )
                changeWindowSizeSubmenu.addItem(menuItem)
            }
        }
        changeWindowSizeMenuItem.submenu = changeWindowSizeSubmenu
        menu.addItem(changeWindowSizeMenuItem)

        let alwaysOnTopMenuItem = NSMenuItem(
            title: "Always on Top",
            action: #selector(toggleAlwaysOnTop),
            keyEquivalent: ""
        )
        alwaysOnTopMenuItem.state = alwaysOnTop ? .on : .off
        menu.addItem(alwaysOnTopMenuItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(
            NSMenuItem(
                title: "Quit",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        menu.delegate = self
    }

    func constructPopover() {
        popover = NSPopover()
        popover.contentViewController = MistralisPopup()
        popover.delegate = self
        popover.contentSize =
            windowSizeOptions["Medium"] ?? CGSize(width: 500, height: 600)

        // Adjust behavior based on `alwaysOnTop`
        updatePopoverBehavior()
    }

    func updatePopoverBehavior() {
        popover.behavior = alwaysOnTop ? .applicationDefined : .transient
    }

    func showMenu() {
        statusItem.menu = menu
        statusItem.popUpMenu(menu)
    }

    func removeMenu() {
        statusItem.menu = nil
    }

    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            deinitKeys()
        } else {
            if let button = statusItem.button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                updateMenuItemsState()
                updateWindowSizeMenuItemsState()
                popover.show(
                    relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
                constructKeys()
            }
        }
    }

    private func deinitKeys() {
        hotCKey = nil
        hotVKey = nil
        hotXKey = nil
        hotZKey = nil
        hotAKey = nil
    }

    private func constructKeys() {
        hotCKey = HotKey(key: .c, modifiers: [.command])  // Global hotkey
        hotVKey = HotKey(key: .v, modifiers: [.command])  // Global hotkey
        hotZKey = HotKey(key: .z, modifiers: [.command])  // Global hotkey
        hotXKey = HotKey(key: .x, modifiers: [.command])  // Global hotkey
        hotAKey = HotKey(key: .a, modifiers: [.command])  // Global hotkey

        hotCKey?.keyDownHandler = {
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
        }

        hotVKey?.keyDownHandler = {
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
        }

        hotXKey?.keyDownHandler = {
            NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
        }

        hotZKey?.keyDownHandler = {
            NSApp.sendAction(Selector("undo:"), to: nil, from: self)
        }

        hotAKey?.keyDownHandler = {
            NSApp.sendAction(
                #selector(NSStandardKeyBindingResponding.selectAll(_:)),
                to: nil, from: self)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool
    {
        return true
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverWillClose(_ notification: Notification) {
        deinitKeys()
    }
}

class AboutWindowController: NSWindowController {
    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
    }
}

extension AboutWindowController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)  // Hide the window instead of closing
        return false  // Prevent the window from closing
    }
}
