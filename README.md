<div align="center">

# 💬 PromptBar 2.0

### Any chat. Any model. One keystroke away.

**The macOS menubar chat container that's yours to shape.**
**Kontejneri i bisedave ne menubar te macOS qe e formon ti vete.**

[![License: CC BY-SA 4.0](https://img.shields.io/badge/License-CC%20BY--SA%204.0-orange.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-26%20Tahoe-blue?logo=apple)](https://www.apple.com/macos/)
[![Liquid Glass](https://img.shields.io/badge/UI-Liquid%20Glass-9cf)](#)
[![No Tracking](https://img.shields.io/badge/Privacy-No%20Tracking-brightgreen)](PRIVACY_POLICY.md)
[![Bring Your Own Key](https://img.shields.io/badge/BYO-API%20Key-purple?logo=openai)](#-bring-your-own-key)
[![Star this repo](https://img.shields.io/github/stars/peterdsp/PromptBar?style=social)](https://github.com/peterdsp/PromptBar/stargazers)

[Features](#-features) · [Why 2.0 is different](#-why-20-is-different) · [Install](#-install) · [BYO Key](#-bring-your-own-key) · [Privacy](#-privacy) · [Support](#-support)

</div>

---

> **You bring the URL. You bring the key. You bring the prompts.**
> **PromptBar gives them a home in your menubar, fast, glassy, private.**

---

## 🇬🇧 English

### What is PromptBar

PromptBar is a **lightweight macOS menubar app** that lives one keystroke away. It does two things, and it does them well:

1. **Wraps any web-based chat** you point it at in a clean, distraction-free popover.
2. **Talks natively to any OpenAI-compatible API endpoint** you configure, your key, your model, your endpoint, your data.

It ships **empty**. No bundled providers. No bundled logos. No bundled brand names. You decide what goes in the menubar, and the app stays out of your way.

### Why 2.0 is different

| Before | After |
|---|---|
| Hard-coded list of providers | **Empty by default, you add what you want** |
| Web-only, hidden iframe | **Native streaming chat with BYO API key** |
| Firebase analytics + remote config | **Zero tracking, zero remote config** |
| macOS 12 baseline | **macOS 26 Liquid Glass, top to bottom** |
| Brand names in the UI | **No third-party brand names, anywhere** |
| Paperclip uploads broken | **Fixed, popover stays put for the file picker** |

---

## ✨ Features

- 🪟 **Liquid Glass UI**, built top-to-bottom on macOS 26's Liquid Glass material system.
- 🌐 **Wrap any web chat**, paste a URL, pick a name, an icon, a color. Done.
- 🔑 **Bring your own API key**, connect any OpenAI-compatible chat-completions endpoint and stream natively.
- 📚 **Prompt Library**, save your best prompts once; reuse them in any chat. Search, tag, ship.
- 💬 **Native streaming chat**, server-sent events, multi-conversation history, cancel mid-stream.
- 🎨 **Make every chat yours**, SF Symbol icons + color tints per service.
- 🔐 **Keychain-backed keys**, API keys live in the macOS Keychain. Not in UserDefaults. Not in iCloud. Not in a log file.
- 🪶 **Menubar-only**, no Dock noise. `⌘⇧C` to summon it.
- 🪟 **Always-on-top mode**, pin the popover over any app.
- 📐 **Three sizes**, Small / Medium / Large, persisted.
- 🧹 **One-click cookie sweep**, clear all WebKit local data when you want a clean slate.
- 🚫 **No analytics, no telemetry, no remote config.** Updates check GitHub Releases directly.

---

## 🔑 Bring your own key

PromptBar speaks the **OpenAI-compatible `POST /chat/completions` schema**, the de-facto standard supported by the vast majority of inference services and local runtimes. If your endpoint understands it, PromptBar can chat with it.

You configure:

- **Display name**, whatever you want it called
- **Base URL**, e.g. `https://api.example.com/v1`
- **Model**, e.g. `gpt-4o-mini`, `llama-3.1-70b`, anything your endpoint serves
- **API key**, stored in the macOS Keychain
- **System prompt**, optional, persisted per endpoint
- **Streaming**, on by default, can be disabled

Your messages go **straight from your Mac to your endpoint URL**. No relay, no middleman, no proxy.

---

## 💻 Requirements

- macOS **26.0+** (Liquid Glass APIs)

---

## 📥 Install

Download the latest signed and notarized `.pkg` from [GitHub Releases](https://github.com/peterdsp/PromptBar/releases), or grab it from the [Ko-fi shop](https://ko-fi.com/peterdsp) and help fund the next version.

```bash
# After install
open -a PromptBar
# Click the menubar icon. Hit ⌘⇧C from anywhere to toggle it.
```

---

## 🔒 Privacy

- **No accounts.** PromptBar creates none.
- **No analytics, no telemetry, no crash reports.** None.
- **No remote config.** Firebase is gone for good.
- **API keys live in the Keychain.** Not in UserDefaults, not in iCloud.
- **Updates** check `api.github.com` directly. Same anonymous HTTP any browser would send.
- **Web chats** run inside `WKWebView`. Cookies live on this Mac only. Clear them at any time.

Full details in [PRIVACY_POLICY.md](PRIVACY_POLICY.md) and [USER_PRIVACY_CHOICES.md](USER_PRIVACY_CHOICES.md).

---

## 🧠 Power moves

- **⌘⇧C**, toggle the popover from anywhere on your system.
- **⌘P** (inside chat), open the Prompt Library quick picker.
- **⌘↩**, send a message in the native chat.
- **Right-click the menubar icon**, Settings, Always-on-Top, Window Size, Clean Cookies & Cache, Quit.

---

## 🛠️ Build from source

```bash
git clone https://github.com/peterdsp/PromptBar.git
cd PromptBar
open PromptBar/PromptBar.xcodeproj
# Xcode 26+, build & run
```

Read [AGENTS.md](AGENTS.md) before contributing, it's the rulebook (especially the App Store compliance section).

---

## ❤️ Support

PromptBar is **single-developer software**. Every coffee and every star keeps it shipping.

- ☕ [Buy PromptBar 2.0 on Ko-fi](https://ko-fi.com/peterdsp)
- ⭐ [Star the repo](https://github.com/peterdsp/PromptBar/stargazers)
- 🐦 Share what you built with PromptBar's Prompt Library

---

## 📜 License

[Creative Commons Attribution-ShareAlike 4.0 International](LICENSE).

---

<div align="center">

### If PromptBar saved you a tab, drop a ⭐
### Nese PromptBar te kurseu nje tab, lere nje ⭐

[![Star History Chart](https://api.star-history.com/svg?repos=peterdsp/PromptBar&type=Date)](https://star-history.com/#peterdsp/PromptBar&Date)

Built with 💎 in Tirana and Athens by [@peterdsp](https://github.com/peterdsp).
Ndertuar me 💎 ne Tirane dhe Athine nga [@peterdsp](https://github.com/peterdsp).

</div>
