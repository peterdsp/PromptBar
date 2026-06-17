//
//  MarketingSeed.swift
//  PromptBar
//
//  DEBUG-only. When the env var PROMPTBAR_MARKETING=1 is set, replaces
//  ChatStore.shared's collections with realistic-looking sample data
//  so we can capture marketing screenshots without typing real API
//  keys or onboarding through every step. The seed never runs in
//  release builds and never persists past UserDefaults wipe.
//

#if DEBUG

import Foundation
import AppKit

enum MarketingSeed {
    static func runIfRequested() {
        guard ProcessInfo.processInfo.environment["PROMPTBAR_MARKETING"] == "1" else { return }
        apply()
    }

    private static func apply() {
        let prefs = AppPreferences.shared
        prefs.hasCompletedOnboarding = true
        prefs.windowMode = .window

        // Wipe persisted store data so each launch starts from the seed.
        let defaults = UserDefaults.standard
        for key in [
            "promptbar.services.v2",
            "promptbar.endpoints.v1",
            "promptbar.selectedTarget.v1",
            "promptbar.conversations.v1",
            "promptbar.prompts.v1",
            "promptbar.mcpServers.v1"
        ] {
            defaults.removeObject(forKey: key)
        }

        let store = ChatStore.shared
        // Force-reset by reinstating defaults via the public API.
        for s in store.services { store.remove(s) }
        for e in store.endpoints { store.remove(e) }
        for c in store.conversations { store.deleteConversation(c) }
        for p in store.prompts { store.deletePrompt(p) }
        for m in store.mcpServers { store.removeMCPServer(m) }

        // ---------- Web chats (4) ----------
        let chatgpt = ChatService(
            name: "ChatGPT",
            urlString: "https://chat.openai.com",
            symbolName: "bubble.left.and.bubble.right.fill",
            tintHex: "#10A37F"
        )
        let claude = ChatService(
            name: "Claude",
            urlString: "https://claude.ai",
            symbolName: "sparkles",
            tintHex: "#C97757"
        )
        let gemini = ChatService(
            name: "Gemini",
            urlString: "https://gemini.google.com",
            symbolName: "diamond.fill",
            tintHex: "#4285F4"
        )
        let perplexity = ChatService(
            name: "Perplexity",
            urlString: "https://perplexity.ai",
            symbolName: "magnifyingglass.circle.fill",
            tintHex: "#20808D"
        )
        store.add(chatgpt)
        store.add(claude)
        store.add(gemini)
        store.add(perplexity)

        // ---------- API endpoints (2) ----------
        let openai = APIEndpoint(
            name: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            modelName: "gpt-4o",
            systemPrompt: "You are a concise, senior software engineer. Prefer minimal diffs.",
            symbolName: "cpu",
            tintHex: "#10A37F",
            streamingEnabled: true
        )
        let ollama = APIEndpoint(
            name: "Local Llama",
            baseURL: "http://localhost:11434/v1",
            modelName: "llama-3.1-70b-instruct",
            systemPrompt: "Local model. Respond plainly. No emojis.",
            symbolName: "shippingbox.fill",
            tintHex: "#7A7AFF",
            streamingEnabled: true
        )
        store.add(openai, apiKey: "sk-demo-not-a-real-key-aaaaaaaaaaaaaaaaaaaaaaaa")
        store.add(ollama, apiKey: "")

        // ---------- Conversation (mid-stream-looking) ----------
        var convo = Conversation.empty(for: openai.id, systemPrompt: openai.systemPrompt)
        convo.title = "Refactor the payment flow"
        convo.messages.append(ChatMessage(
            role: .user,
            content: "Refactor checkout.swift so the Apple Pay path and the card path share the same `PaymentIntent` builder. Keep the public API unchanged."
        ))
        convo.messages.append(ChatMessage(
            role: .assistant,
            content: """
            Here's the smallest change that gets both paths through one builder.

            1. Extract a private `makeIntent(amount:method:)` on `CheckoutViewModel`. It returns a `PaymentIntent` already configured with currency, locale, and the customer ID, so both call sites stop duplicating that setup.
            2. The Apple Pay handler keeps reading `PKPayment.token` but hands it to the new builder instead of constructing `PaymentIntent` inline.
            3. The card handler does the same with the `Stripe.Token`.

            ```swift
            private func makeIntent(amount: Decimal, method: PaymentMethod) -> PaymentIntent {
                PaymentIntent(
                    customerID: session.customerID,
                    amount: amount,
                    currency: session.currency,
                    locale: Locale.current,
                    method: method
                )
            }
            ```

            Public API stays identical: `submitApplePay(_:)` and `submitCard(_:)` keep their existing signatures, they just both call `makeIntent` now. Want me to also pull the retry logic up so it's shared?
            """
        ))
        store.updateConversation(convo)
        store.activeConversationID = convo.id
        // Default to API endpoint; PROMPTBAR_MARKETING_TAB=claude swaps to Claude wrap.
        if ProcessInfo.processInfo.environment["PROMPTBAR_MARKETING_TAB"] == "claude" {
            store.selectedTarget = .web(claude.id)
        } else {
            store.selectedTarget = .api(openai.id)
        }

        // ---------- Prompt library (6) ----------
        let prompts: [PromptItem] = [
            PromptItem(
                title: "Explain this code",
                body: "Explain the following code in plain English, then list any latent bugs and edge cases I should worry about. Be specific, no hedging.\n\n<paste code here>",
                tags: ["dev", "review"]
            ),
            PromptItem(
                title: "PR description from diff",
                body: "You are writing a pull request description for a teammate. The diff is below. Output: a 1-sentence summary, a bullet list of changes, and a short test plan. No fluff.\n\n<paste diff here>",
                tags: ["dev", "writing"]
            ),
            PromptItem(
                title: "Translate to plain English",
                body: "Rewrite the following in plain, friendly English that a non-technical reader will understand. Keep all factual claims intact. Avoid jargon.\n\n<paste text here>",
                tags: ["writing"]
            ),
            PromptItem(
                title: "Meeting notes to action items",
                body: "Read the raw meeting notes below and return: 1) decisions made, 2) action items with owner + due date, 3) open questions. Use a short markdown table.\n\n<paste notes here>",
                tags: ["work"]
            ),
            PromptItem(
                title: "Improve this prompt",
                body: "Critique the following prompt I'm about to send to an LLM. Tell me exactly what's vague, what context is missing, and rewrite it. Output the rewritten prompt first, then a 3-bullet critique.\n\n<paste prompt here>",
                tags: ["meta", "writing"]
            ),
            PromptItem(
                title: "SQL query from question",
                body: "Given the schema below and the question after it, return a single PostgreSQL query that answers the question. No prose, no comments inside the SQL, no triple backticks.\n\nSchema:\n<paste schema>\n\nQuestion:\n<paste question>",
                tags: ["dev", "data"]
            )
        ]
        for p in prompts { store.addPrompt(p) }

        // ---------- MCP servers (3 connected, 1 off) ----------
        let mcp1 = MCPServer(
            id: UUID(),
            name: "GitHub Issues",
            baseURL: "https://mcp.peterdsp.dev/github",
            authHeader: "Bearer ghp_demo",
            enabled: true,
            symbolName: "checkmark.seal.fill",
            tintHex: "#1F883D"
        )
        let mcp2 = MCPServer(
            id: UUID(),
            name: "Workspace Files",
            baseURL: "https://mcp.peterdsp.dev/files",
            authHeader: "X-API-Key: demo",
            enabled: true,
            symbolName: "folder.fill",
            tintHex: "#4D8AFF"
        )
        let mcp3 = MCPServer(
            id: UUID(),
            name: "Design Tokens",
            baseURL: "https://mcp.peterdsp.dev/figma",
            authHeader: "Bearer fig_demo",
            enabled: true,
            symbolName: "paintpalette.fill",
            tintHex: "#C97757"
        )
        let mcp4 = MCPServer(
            id: UUID(),
            name: "Linear",
            baseURL: "https://mcp.peterdsp.dev/linear",
            authHeader: "",
            enabled: false,
            symbolName: "rectangle.connected.to.line.below",
            tintHex: "#7A7AFF"
        )
        for m in [mcp1, mcp2, mcp3, mcp4] { store.addMCPServer(m, token: "") }
    }
}

#endif
