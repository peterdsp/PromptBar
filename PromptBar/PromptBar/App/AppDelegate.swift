//
//  AppDelegate.swift
//  PromptBar
//
//  Created by Petros Dhespollari on 16/3/24.
//

import Cocoa
import FirebaseCore
import FirebaseInstallations
import FirebaseRemoteConfig
import SwiftUI
import SystemConfiguration
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // MARK: - Properties
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var menu: NSMenu!
    private var loadingView: NSView?
    private var errorOverlay: NSView?
    private var isCheckingInternet = false
    private var alwaysOnTop: Bool = false
    
    var selectedAIChatTitle: String = "PromptBar"
    private var aiChatOptions: [String: String] = [:]
    private var selectedFileURL: URL?
    
    private let windowSizeKey = "selectedWindowSize"
    private let defaultChatURL = "https://chat.mistral.ai/chat/"
    
    internal var windowSizeOptions: [String: CGSize] = [
        "Small": CGSize(width: 400, height: 300),
        "Medium": CGSize(width: 600, height: 700),
        "Large": CGSize(width: 800, height: 900),
        "Extra Large": CGSize(width: 1000, height: 1000)
    ]
    
    var chatOptions: [String: String] {
        return aiChatOptions
    }

    // MARK: - Application Lifecycle
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        configureFirebase()
        setupStatusItem()
        setupInitialAIChat()
        setupWindowSize()
        constructPopover()
        constructMenu()
        NSApp.setActivationPolicy(.accessory)
    }
    
    // MARK: - Setup Methods
    private func configureFirebase() {
        FirebaseApp.configure()
        fetchRemoteConfig()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let icon = NSImage(named: "MenuBarIcon")?.resized(to: CGSize(width: 14, height: 14))
            icon?.isTemplate = true
            button.image = icon
            button.action = #selector(handleMenuIconAction(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func setupInitialAIChat() {
        selectedAIChatTitle = UserDefaults.standard.string(forKey: "selectedAIChatTitle") ?? "Mistral"
        UserDefaults.standard.set(selectedAIChatTitle, forKey: "selectedAIChatTitle")
    }
    
    private func setupWindowSize() {
        let defaultSizeName = "Medium"
        let savedSizeName = UserDefaults.standard.string(forKey: windowSizeKey) ?? defaultSizeName
        popover?.contentSize = windowSizeOptions[savedSizeName] ?? windowSizeOptions[defaultSizeName]!
        UserDefaults.standard.set(savedSizeName, forKey: windowSizeKey)
    }
    
    // MARK: - Menu Handling
    @objc func handleMenuIconAction(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            removeMenu()
            togglePopover()
        }
    }
    
    func showMenu() {
        updateMenuItemsState()
        statusItem.menu = menu
        statusItem.popUpMenu(menu)
    }
    
    func removeMenu() {
        statusItem.menu = nil
    }
    
    // MARK: - File Selection
    @objc func selectFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.allowedContentTypes = [.pdf, .text, .plainText, .html]
        
        openPanel.begin { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }
            self?.selectedFileURL = url
            self?.loadFileContent(url: url)
        }
    }
    
    private func loadFileContent(url: URL) {
        guard isInternetAvailable() else {
            showNoInternetMessage()
            return
        }
        
        // Use MainUI to load the file as a local URL
        let fileURLString = url.absoluteString
        let hostingController = NSHostingController(rootView: MainUI(initialAddress: fileURLString))
        let popupContentViewController = PromptBarPopup()
        popupContentViewController.hostingController = hostingController
        
        popover.contentViewController = popupContentViewController
        popover.contentSize = hostingController.view.fittingSize
        
        showLoadingView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.hideLoadingView()
        }
    }
    
    // MARK: - Loading View
    func showLoadingView() {
        guard let window = popover.contentViewController?.view.window, loadingView == nil else { return }
        
        if !isInternetAvailable() {
            showNoInternetMessage()
            return
        }
        
        let loadingOverlay = createLoadingOverlay(for: window)
        window.contentView?.addSubview(loadingOverlay)
        self.loadingView = loadingOverlay
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            loadingOverlay.animator().alphaValue = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.hideLoadingView()
        }
    }
    
    private func createLoadingOverlay(for window: NSWindow) -> NSView {
        let overlay = NSView(frame: window.contentView!.bounds)
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        overlay.alphaValue = 0
        overlay.identifier = NSUserInterfaceItemIdentifier("loadingOverlay")
        
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .large
        spinner.isIndeterminate = true
        spinner.startAnimation(nil)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        
        let label = NSTextField(labelWithString: "Loading \(selectedAIChatTitle)...")
        label.font = NSFont.boldSystemFont(ofSize: 18)
        label.textColor = .white
        label.alignment = .center
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        overlay.addSubview(spinner)
        overlay.addSubview(label)
        
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -30),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 15),
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor)
        ])
        
        return overlay
    }
    
    func hideLoadingView() {
        guard let loadingView = self.loadingView else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            loadingView.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            loadingView.removeFromSuperview()
            self?.loadingView = nil
        })
    }
    
    // MARK: - Internet Connectivity
    func showNoInternetMessage() {
        guard let window = popover.contentViewController?.view.window, errorOverlay == nil else { return }
        
        let overlay = NSView(frame: window.contentView!.bounds)
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        overlay.identifier = NSUserInterfaceItemIdentifier("errorOverlay")
        
        let errorLabel = NSTextField(labelWithString: "No internet connection.\nPlease check your network and try again.")
        errorLabel.font = NSFont.boldSystemFont(ofSize: 16)
        errorLabel.textColor = .white
        errorLabel.alignment = .center
        errorLabel.isBezeled = false
        errorLabel.isEditable = false
        errorLabel.drawsBackground = false
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.maximumNumberOfLines = 2
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        overlay.addSubview(errorLabel)
        
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])
        
        window.contentView?.addSubview(overlay)
        self.errorOverlay = overlay
        
        if !isCheckingInternet {
            isCheckingInternet = true
            checkInternetConnectionRepeatedly()
        }
    }
    
    func checkInternetConnectionRepeatedly() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            while !(self?.isInternetAvailable() ?? false) {
                sleep(3)
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.hideNoInternetMessage()
                if self?.loadingView == nil {
                    self?.showLoadingView()
                }
                self?.reloadAIChat()
                self?.isCheckingInternet = false
            }
        }
    }
    
    func hideNoInternetMessage() {
        guard let errorOverlay = self.errorOverlay else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            errorOverlay.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            errorOverlay.removeFromSuperview()
            self?.errorOverlay = nil
        })
    }
    
    func isInternetAvailable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let reachability = withUnsafePointer(to: &zeroAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                SCNetworkReachabilityCreateWithAddress(nil, address)
            }
        }
        
        guard let reachability else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        guard SCNetworkReachabilityGetFlags(reachability, &flags) else {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        return isReachable && !needsConnection
    }
    
    // MARK: - AI Chat Management
    func fetchRemoteConfig() {
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard error == nil else {
                print("⚠️ Failed to fetch remote config: \(error!.localizedDescription)")
                return
            }
            
            let aiChatsJSON = remoteConfig.configValue(forKey: "ai_chats").stringValue
            if !aiChatsJSON.isEmpty {
                do {
                    let aiChatsData = Data(aiChatsJSON.utf8)
                    self?.aiChatOptions = try JSONDecoder().decode([String: String].self, from: aiChatsData)
                    print("✅ Successfully fetched AI chats: \(self?.aiChatOptions ?? [:])")
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.constructMenu()
                        self?.statusItem.menu = self?.menu
                    }
                } catch {
                    print("⚠️ Failed to decode ai_chats JSON: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func reloadAIChat() {
        let initialAddress = aiChatOptions[selectedAIChatTitle] ?? defaultChatURL
        let newHostingController = NSHostingController(rootView: MainUI(initialAddress: initialAddress))
        let newPopupContentViewController = PromptBarPopup()
        newPopupContentViewController.hostingController = newHostingController
        
        popover.contentViewController = newPopupContentViewController
        popover.contentSize = newHostingController.view.fittingSize
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.hideLoadingView()
        }
    }
    
    @objc func changeAIChat(sender: NSMenuItem) {
        guard isInternetAvailable() else {
            showNoInternetMessage()
            return
        }
        
        guard let urlString = sender.representedObject as? String else { return }
        
        selectedAIChatTitle = sender.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let newHostingController = NSHostingController(rootView: MainUI(initialAddress: urlString))
        let newPopupContentViewController = PromptBarPopup()
        newPopupContentViewController.hostingController = newHostingController
        
        popover.contentViewController = newPopupContentViewController
        popover.contentSize = newHostingController.view.fittingSize
        
        UserDefaults.standard.set(selectedAIChatTitle, forKey: "selectedAIChatTitle")
        updateMenuItemsState()
    }
    
    // MARK: - Window Management
    @objc func changeWindowSize(sender: NSMenuItem) {
        guard let newSize = windowSizeOptions[sender.title] else { return }
        
        popover.contentSize = newSize
        UserDefaults.standard.set(sender.title, forKey: windowSizeKey)
        updateWindowSizeMenuItemsState()
    }
    
    func updateWindowLevel() {
        guard let window = popover.contentViewController?.view.window else { return }
        
        window.level = alwaysOnTop ? .statusBar : .floating
        window.collectionBehavior = alwaysOnTop ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
    }
    
    @objc func toggleAlwaysOnTop(sender: NSMenuItem) {
        alwaysOnTop.toggle()
        sender.state = alwaysOnTop ? .on : .off
        updateWindowLevel()
        updatePopoverBehavior()
    }
    
    // MARK: - Menu Construction
    func constructMenu() {
        menu = NSMenu()
        menu.delegate = self
        
        // About
        menu.addItem(NSMenuItem(title: "About", action: #selector(didTapOne), keyEquivalent: "1"))
        
        // Clean Cookies
        menu.addItem(NSMenuItem(title: "Clean Cookies", action: #selector(didTapTwo), keyEquivalent: "2"))
        
        menu.addItem(.separator())
        
        // Change AI Chat Submenu
        let changeChatAIMenuItem = NSMenuItem(title: "Change AI Chat", action: nil, keyEquivalent: "")
        let changeChatAISubmenu = NSMenu()
        
        if aiChatOptions.isEmpty {
            let placeholderItem = NSMenuItem(title: "Loading...", action: nil, keyEquivalent: "")
            placeholderItem.isEnabled = false
            changeChatAISubmenu.addItem(placeholderItem)
        } else {
            for (title, url) in aiChatOptions.sorted(by: { $0.key < $1.key }) {
                let menuItem = NSMenuItem(title: title, action: #selector(changeAIChat(sender:)), keyEquivalent: "")
                menuItem.representedObject = url
                changeChatAISubmenu.addItem(menuItem)
            }
        }
        
        changeChatAIMenuItem.submenu = changeChatAISubmenu
        menu.addItem(changeChatAIMenuItem)
        
        // Change Window Size Submenu
        let changeWindowSizeMenuItem = NSMenuItem(title: "Change Window Size", action: nil, keyEquivalent: "")
        let changeWindowSizeSubmenu = NSMenu()
        
        for size in windowSizeOptions.keys.sorted() {
            let menuItem = NSMenuItem(title: size, action: #selector(changeWindowSize(sender:)), keyEquivalent: "")
            changeWindowSizeSubmenu.addItem(menuItem)
        }
        
        changeWindowSizeMenuItem.submenu = changeWindowSizeSubmenu
        menu.addItem(changeWindowSizeMenuItem)
        
        // Always on Top
        let alwaysOnTopMenuItem = NSMenuItem(title: "Always on Top", action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        alwaysOnTopMenuItem.state = alwaysOnTop ? .on : .off
        menu.addItem(alwaysOnTopMenuItem)
        
        menu.addItem(.separator())
        
        // Quit
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        updateMenuItemsState()
        updateWindowSizeMenuItemsState()
    }
    
    func updateMenuItemsState() {
        if let changeChatAIMenuItem = menu.item(withTitle: "Change AI Chat"),
           let submenu = changeChatAIMenuItem.submenu {
            for item in submenu.items {
                item.state = (item.title == selectedAIChatTitle) ? .on : .off
            }
        }
    }
    
    func updateWindowSizeMenuItemsState() {
        if let windowSizeMenuItem = menu.item(withTitle: "Change Window Size"),
           let submenu = windowSizeMenuItem.submenu {
            for item in submenu.items {
                item.state = (popover.contentSize == windowSizeOptions[item.title]) ? .on : .off
            }
        }
    }
    
    // MARK: - Popover Management
    func constructPopover() {
        popover = NSPopover()
        popover.contentViewController = PromptBarPopup()
        popover.contentSize = windowSizeOptions[UserDefaults.standard.string(forKey: windowSizeKey) ?? "Medium"]!
        updatePopoverBehavior()
    }
    
    func updatePopoverBehavior() {
        popover.behavior = alwaysOnTop ? .applicationDefined : .transient
    }
    
    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            NSApplication.shared.activate(ignoringOtherApps: true)
            updateMenuItemsState()
            updateWindowSizeMenuItemsState()
            
            if popover.contentViewController == nil || popover.contentViewController?.view.window == nil {
                reloadAIChat()
            }
            
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    // MARK: - Application Delegate Methods
    func applicationDidBecomeActive(_ notification: Notification) {
        updateWindowLevel()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        if alwaysOnTop, let window = popover.contentViewController?.view.window {
            window.level = .floating
            window.orderFrontRegardless()
        }
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func menuDidClose(_ menu: NSMenu) {
        removeMenu()
    }
    
    @objc func didTapOne() {
        let aboutView = AboutView()
        let aboutWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                                 styleMask: [.titled, .closable],
                                 backing: .buffered,
                                 defer: false)
        
        aboutWindow.level = .floating
        aboutWindow.center()
        aboutWindow.contentView = NSHostingView(rootView: aboutView)
        
        let aboutWindowController = AboutWindowController(window: aboutWindow)
        aboutWindowController.showWindow(nil)
        aboutWindow.orderFrontRegardless()
    }
    
    @objc func didTapTwo() {
        WebViewHelper.clean()
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
        sender.orderOut(nil)
        return false
    }
}

// MARK: - NSImage Extension
extension NSImage {
    func resized(to newSize: NSSize) -> NSImage? {
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(newSize.width),
            pixelsHigh: Int(newSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy,
             fraction: 1.0)
        
        NSGraphicsContext.restoreGraphicsState()
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.addRepresentation(bitmapRep)
        return resizedImage
    }
}
