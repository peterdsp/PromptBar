# Contributor Guidelines for PromptBar

> **This file is the authoritative rulebook for anyone or anything making changes
> to this project.** Read and follow these guidelines before modifying any code,
> configuration, or documentation in this repository. If a guideline here
> conflicts with a default convention from another source, this file takes
> precedence.

PromptBar is a macOS menubar app that wraps **user-supplied** web URLs in a
WKWebView popover. It is intentionally a **generic container**, not a client for
any specific third-party service. The app ships with **zero preloaded providers**,
**no third-party logos**, and **no third-party brand names** in its UI, assets,
metadata, or marketing materials. This is a deliberate App Store compliance
posture (Guideline 4.1, Design: Copycats).

## 0. App Store compliance rules (read this first)

Any change to the app, assets, README, screenshots, or App Store metadata MUST
preserve the following:

* **No third-party brand names** in user-facing UI, asset catalogs, default
  configurations, marketing copy, App Store description, or screenshots.
* **No third-party logos or marks** in `Assets.xcassets` or bundled resources.
* **No preloaded service list.** The store ships empty. Users add services by
  pasting a URL and giving it their own name and icon.
* **Quick Add suggestions are plain URLs only**, no brand names attached. The
  user names the service themselves.
* **No analytics, no tracking, no remote config.** Firebase has been removed and
  must not be reintroduced.
* The app must not claim to "integrate ChatGPT" or any specific provider.
  Marketing positioning is *"Wrap any web chat in your menubar."*

If a change would violate any of the above, **stop and ask the user first.**

## 1. Project structure

```
PromptBar/
  PromptBar.xcodeproj
  PromptBar/
    App/
      main.swift                # Entry point
      AppDelegate.swift         # Menubar, popover lifecycle, hotkeys
      Info.plist
      PromptBar.entitlements
    Models/
      ChatService.swift         # User-defined service model
      ChatStore.swift           # UserDefaults-backed store
    Views/
      PromptBarPopup.swift      # Popup root (sidebar + WebView)
      ContentView.swift         # WKWebView + delegates
      QuickAddView.swift        # Add-a-service sheet
      SettingsView.swift        # Settings window
      AboutView.swift           # About window
    Helpers/
      GlassStyle.swift          # Liquid Glass material helpers
      UpdateChecker.swift       # GitHub Releases checker
      WebViewHelper.swift       # Cookie/cache cleaner
      VersionComparator.swift   # Semver compare
      Utilities.swift           # NSImage helpers
      ObservableObject.swift    # Reload state
```

## 2. Dev environment

* macOS **26.0+** deployment target (Liquid Glass APIs).
* Open `PromptBar.xcodeproj` directly (no workspace).
* Swift Package Manager handles the single dependency: `HotKey`.

## 3. Architecture

* **AppDelegate.swift** owns the `NSStatusItem`, the `NSPopover`, the right-click
  menu, and the Settings/About windows. It also wires Combine subscriptions so
  the popup rebuilds when `ChatStore` changes.
* **ChatStore** is a `@MainActor` `ObservableObject` singleton, persisted via
  `UserDefaults` under keys prefixed `promptbar.*.v2`.
* **PopupRootView** renders the Liquid Glass popup. Service pills along the top
  switch between user-added services. Empty state when no services exist.
* **ContentView** wraps `WKWebView` with navigation/UI/download delegates. The
  open-panel flow pins the popover behavior to `.applicationDefined` while the
  file picker is up, restoring it afterward, this is the fix for the paperclip
  upload bug (Apple Review 2.1, March/April 2025).
* **UpdateChecker** hits `api.github.com/repos/peterdsp/PromptBar/releases/latest`
  and uses `VersionComparator` to decide whether to surface an update.

## 4. Dependencies

| Package | Purpose |
| --- | --- |
| `HotKey` (soffes) | Global ⌘⇧C hotkey + in-popover Cmd-C/V/X/Z/A bindings |

## 5. Coding conventions

* Swift / SwiftUI for views; AppKit only where required (`NSStatusItem`,
  `NSPopover`, `NSWindow`).
* `@MainActor` on UI state owners.
* No `print` debugging in shipped code.
* Reach for SF Symbols and `.regularMaterial` / `.thinMaterial` / `.thickMaterial`
  to stay consistent with the Liquid Glass treatment.
* User-facing copy must never name a specific third-party AI service.

## 6. Manual validation checklist

1. Build & run from Xcode on macOS 26.
2. Menubar icon appears; left-click opens the popup; right-click opens the menu.
3. With no services, the empty state shows; **Add a Chat** opens the Quick Add
   sheet; adding a valid URL adds a pill and loads the page.
4. Switching pills swaps the WebView destination.
5. Settings window opens, lists services, allows reorder/edit/delete.
6. About window's "Check for Updates" hits GitHub and reports a sensible result.
7. **Paperclip upload** works: trigger a file upload in a web chat and confirm
   the open panel appears and the popover stays open.
8. Window size and Always-on-Top persist across launches.
9. Clean Cookies & Cache clears `WKWebsiteDataStore` and reloads.

## 7. Common tasks

| Task | How |
| --- | --- |
| Add a UI surface | New SwiftUI file under `Views/`, register it in the pbxproj `Sources` build phase. |
| Add a hotkey | Append to `setupLocalEditHotKeys` (popover-scoped) or register a new global `HotKey` in `applicationDidFinishLaunching`. |
| Update version | Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj`. |
| Cut a release | Tag `vX.Y.Z` on GitHub and publish a release; `UpdateChecker` will pick it up. |

## 8. PR rules

* One change per PR.
* Build must compile without warnings.
* Walk through section 6 before submitting.
* Never reintroduce Firebase, analytics, telemetry, or hard-coded provider names.

---

Following these rules keeps the app shippable on the App Store and preserves the
generic-container positioning that earned approval.
