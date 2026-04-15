# AGENTS Guidelines for PromptBar

> **This file is the authoritative rulebook for any AI agent or automated tool that
> attempts to make changes to this project.** All agents must read and follow these
> guidelines before modifying any code, configuration, or documentation in this
> repository. If a guideline here conflicts with an agent's default behavior, this
> file takes precedence.

PromptBar is a lightweight macOS menubar AI chat client written in Swift/SwiftUI.
It wraps multiple AI provider web interfaces (Mistral, ChatGPT, Gemini, DeepSeek,
Grok, Perplexity, Copilot, AI Studio, NotebookLM, Meta AI, Sophea.AI) in a single
popover using WKWebView. The list of available AI chats is fetched dynamically via
Firebase RemoteConfig.

## 1. Project Structure

```
PromptBar/
  PromptBar/
    PromptBar.xcodeproj       # Open this directly (no workspace needed)
    PromptBar/
      App/
        main.swift            # Entry point
        AppDelegate.swift     # Core app logic (menubar, popover, menus, hotkeys)
        Info.plist
        PromptBar.entitlements
      Views/
        ContentView.swift     # WKWebView wrapper and navigation delegates
        PromptBarPopup.swift  # Popup container UI
        AboutView.swift       # About window and update checking
      Helpers/
        WebViewHelper.swift   # Cookie cleaning
        Utilities.swift       # NSImage extensions
        ObservableObject.swift # ReloadState
        DownloadDelegate.swift # WKDownloadDelegate
      Assets.xcassets/
      GoogleService-Info.plist
```

## 2. Dev Environment Setup

* **macOS 12.0+** is the minimum deployment target.
* Dependencies are managed with **Swift Package Manager** (SPM). Xcode resolves
  packages automatically on first open — no manual install step needed.
* Open **`PromptBar.xcodeproj`** directly (no workspace required).
* Build and run from Xcode targeting macOS.

## 3. Architecture Notes

* **AppDelegate.swift** is the central hub (~760 lines). It manages the statusbar
  item, popover lifecycle, menu construction, AI chat selection, window sizing,
  connectivity checks, and global hotkey registration.
* **ContentView.swift** wraps `WKWebView` with navigation, download, and UI
  delegates. It injects JavaScript to remove subscription/paywall UI elements
  fetched from RemoteConfig.
* **Firebase RemoteConfig** drives dynamic configuration: the `ai_chats` key maps
  chat names to URLs, and `subscriptions` lists UI text to strip from pages.
* User preferences (selected AI chat, window size) are persisted via `UserDefaults`.
* The app runs sandboxed with network client access and user-selected file
  read/write (for downloads).

## 4. Key Dependencies (Swift Package Manager)

| Package                 | Products Used                              | Purpose                                    |
| ----------------------- | ------------------------------------------ | ------------------------------------------ |
| `firebase-ios-sdk`      | `FirebaseAnalytics`, `FirebaseRemoteConfig`| Analytics + dynamic AI chat list / flags   |
| `HotKey`                | `HotKey`                                   | Global keyboard shortcut (Cmd+Shift+C)     |

## 5. Coding Conventions

* All source is **Swift** using **SwiftUI** for views and **AppKit** for menubar
  integration.
* Follow existing patterns: `@State`/`@Binding`/`@Published` for reactive state,
  delegation for WebKit callbacks.
* Keep new UI in SwiftUI; use AppKit only where required (statusbar, popover).
* Co-locate related helpers in the `Helpers/` folder.

## 6. Testing and Validation

* There is no automated test suite. Validate changes manually:
  1. Build and run from Xcode.
  2. Verify the menubar icon appears and the popover opens on click.
  3. Switch between AI chats and confirm the WebView loads the correct URL.
  4. Test window resizing (Small / Medium / Large) and "Always on Top" toggle.
  5. Test the global hotkey (Cmd+Shift+C).
  6. Test "Clean Cookies" clears session data.
  7. Check internet-offline behavior (error overlay should appear).

## 7. Common Tasks

| Task                        | How                                                              |
| --------------------------- | ---------------------------------------------------------------- |
| Add a new AI chat           | Add it to `ai_chats` in Firebase RemoteConfig (no code change)   |
| Change default window size  | Edit size constants in `AppDelegate.swift`                       |
| Modify WebView behavior     | Edit `ContentView.swift` (navigation delegate methods)           |
| Update dependencies         | In Xcode: File > Packages > Update to Latest Package Versions    |
| Build for release           | Archive from Xcode, notarize with `xcrun notarytool`             |

## 8. PR and Contribution Guidelines

* Keep PRs focused on a single change.
* Ensure the app builds without warnings before submitting.
* Test all items in section 6 for any UI-facing change.
* The app is distributed under CC BY-SA 4.0. Contributions must be compatible
  with this license.

---

Following these guidelines ensures that AI coding agents can work on PromptBar
effectively without needing to scan the entire codebase for context.
