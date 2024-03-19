//
//  AppDelegate.swift
//  MacMistral
//
//  Created by Petros Dhespollari on 16/3/24.
//

import Cocoa
import HotKey
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack {
            Text("MacMistral")
                .font(.title)
                .padding(.bottom)
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .padding(.bottom)
            } else {
                Text("Error: App icon not found")
                    .foregroundColor(.red)
            }
            Text("Developed by Petros Dhespollari")
                .font(.subheadline)
            Text("Version 1.0")
                .font(.subheadline)
                .padding(.top)
            Button("Visit Developer's Website") {
                if let url = URL(string: "https://peterdsp.dev") {
                    NSWorkspace.shared.open(url)
                }
            }
            .padding(.top)
        }
        .padding()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    var selectedAIChatTitle: String = "Mistral AI Chat"
    private let aiChatOptions: [String: String] = [
        "Mistral": "https://chat.mistral.ai/chat/",
        "Claude": "https://claude.ai/chats",
        "ChatGPT": "https://chat.openai.com/#",
        "Gemini": "https://gemini.google.com/app"
    ]

    var chatOptions: [String: String] {
        return aiChatOptions
    }

    public var popover: NSPopover!
    private var menu: NSMenu!

    let hotKey = HotKey(key: .c, modifiers: [.shift, .command]) // Global hotkey

    var hotCKey: HotKey?
    var hotVKey: HotKey?
    var hotZKey: HotKey?
    var hotXKey: HotKey?
    var hotAKey: HotKey?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Set the activation policy to accessory to hide the Dock icon

        NSApp.setActivationPolicy(.accessory)
        if let button = statusItem.button {
            let icon = NSImage(named: "MenuBarIcon")!.resized(to: CGSize(width: 14, height: 14))
            icon.isTemplate = true
            button.image = icon
            button.action = #selector(handleMenuIconAction(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Check if there is a saved AI chat title
        if let savedAIChatTitle = UserDefaults.standard.string(forKey: "selectedAIChatTitle") {
            selectedAIChatTitle = savedAIChatTitle
        }

        constructPopover()
        constructMenu()

        hotKey.keyUpHandler = { // Global hotkey handler
            self.togglePopover()
        }

        // Uncomment the section below if you want the popover to open when opening the app
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            self.togglePopover()
//        }
    }

    @objc func handleMenuIconAction(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == NSEvent.EventType.rightMouseUp {
            showMenu()
        } else {
            removeMenu()
            togglePopover()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        removeMenu()
    }

    @objc func didTapOne() {
        let aboutView = AboutView()
        let aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let aboutWindowController = AboutWindowController(window: aboutWindow)
        aboutWindow.contentView = NSHostingView(rootView: aboutView)
        aboutWindow.center()
        aboutWindow.makeKeyAndOrderFront(nil)
        aboutWindowController.showWindow(nil)
    }

    @objc func didTapTwo() {
        WebViewHelper.clean()
    }

    @objc func changeAIChat(sender: NSMenuItem) {
        if let urlString = sender.representedObject as? String {
            // First, update the address state in the MainUI struct
            selectedAIChatTitle = sender.title.trimmingCharacters(in: .whitespacesAndNewlines)

            // Recreate the MacMistralPopup instance with the updated MainUI instance
            let initialAddress = aiChatOptions[selectedAIChatTitle] ?? "https://chat.mistral.ai/chat/"
            let newHostingController = NSHostingController(rootView: MainUI(initialAddress: initialAddress))
            let newPopupContentViewController = MacMistralPopup()
            newPopupContentViewController.hostingController = newHostingController
            popover.contentViewController = newPopupContentViewController
            popover.contentSize = newHostingController.view.fittingSize

            // Then, update the menu item's title and state
            if let changeChatAIMenuItem = menu.item(withTitle: "Change AI Chat"),
               let changeChatAISubmenu = changeChatAIMenuItem.submenu
            {
                for item in changeChatAISubmenu.items {
                    if item.title == selectedAIChatTitle {
                        item.state = .on
                    } else {
                        item.state = .off
                    }
                }
            }
            // Save the selected AI chat title in UserDefaults
            UserDefaults.standard.set(selectedAIChatTitle, forKey: "selectedAIChatTitle")
        }
    }

    func updateMenuItemsState() {
        if let changeChatAIMenuItem = menu.item(withTitle: "Change AI Chat"),
           let changeChatAISubmenu = changeChatAIMenuItem.submenu
        {
            for item in changeChatAISubmenu.items {
                if item.title == selectedAIChatTitle {
                    item.state = .on
                } else {
                    item.state = .off
                }
            }
        }
    }

    func constructMenu() {
        menu = NSMenu()
        let aboutMenuItem = NSMenuItem(title: "About", action: #selector(didTapOne), keyEquivalent: "1")
        let cleanCookiesMenuItem = NSMenuItem(title: "Clean Cookies", action: #selector(didTapTwo), keyEquivalent: "2")
        menu.addItem(aboutMenuItem)
        menu.addItem(cleanCookiesMenuItem)
        menu.addItem(NSMenuItem.separator())

        let changeChatAIMenuItem = NSMenuItem(title: "Change AI Chat", action: nil, keyEquivalent: "")
        let changeChatAISubmenu = NSMenu()
        for (title, url) in aiChatOptions {
            let menuItem = NSMenuItem(title: title, action: #selector(changeAIChat(sender:)), keyEquivalent: "")
            menuItem.representedObject = url
            changeChatAISubmenu.addItem(menuItem)
        }
        changeChatAIMenuItem.submenu = changeChatAISubmenu
        menu.addItem(changeChatAIMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.delegate = self
    }

    func constructPopover() {
        popover = NSPopover()
        popover.contentViewController = MacMistralPopup()
        popover.delegate = self
        popover.behavior = NSPopover.Behavior.transient
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
                updateMenuItemsState() // Add this line
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.level = .floating
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
        hotCKey = HotKey(key: .c, modifiers: [.command]) // Global hotkey
        hotVKey = HotKey(key: .v, modifiers: [.command]) // Global hotkey
        hotZKey = HotKey(key: .z, modifiers: [.command]) // Global hotkey
        hotXKey = HotKey(key: .x, modifiers: [.command]) // Global hotkey
        hotAKey = HotKey(key: .a, modifiers: [.command]) // Global hotkey
        
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
            NSApp.sendAction(#selector(NSStandardKeyBindingResponding.selectAll(_:)), to: nil, from: self)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverWillClose(_ notification: Notification) {
        deinitKeys()
    }
}

extension NSImage {
    func resized(to size: CGSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        draw(in: NSRect(origin: .zero, size: size), from: NSZeroRect, operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
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
        sender.orderOut(nil) // Hide the window instead of closing
        return false // Prevent the window from closing
    }
}
