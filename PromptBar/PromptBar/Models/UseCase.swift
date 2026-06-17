//
//  UseCase.swift
//  PromptBar
//
//  First-launch use case bundles. The onboarding asks the user what they
//  intend to use PromptBar for, then seeds the Prompt Library and shows
//  generic URL hints for that intent. Every label and hint here is
//  brand-free, the user names the services themselves.
//

import Foundation

enum UseCase: String, CaseIterable, Codable, Identifiable {
    case coding
    case design
    case research
    case operations
    case everyday
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coding: return "Coding & development"
        case .design: return "Design & creative"
        case .research: return "Research & writing"
        case .operations: return "Projects & operations"
        case .everyday: return "Everyday assistant"
        case .custom: return "Skip, I'll set it up"
        }
    }

    var subtitle: String {
        switch self {
        case .coding: return "Code review, refactors, architecture, tests."
        case .design: return "Critiques, variations, copy, image briefs."
        case .research: return "Outlines, summaries, counter-arguments, drafts."
        case .operations: return "Specs, status reports, planning, tickets."
        case .everyday: return "Quick answers, drafting, lookups, ideas."
        case .custom: return "Start empty and configure manually."
        }
    }

    var symbol: String {
        switch self {
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .design: return "paintbrush.pointed.fill"
        case .research: return "doc.text.magnifyingglass"
        case .operations: return "checklist"
        case .everyday: return "sparkles"
        case .custom: return "slider.horizontal.3"
        }
    }

    var tintHex: String {
        switch self {
        case .coding: return "#5BC0EB"
        case .design: return "#FF7A8A"
        case .research: return "#7A7AFF"
        case .operations: return "#F5A623"
        case .everyday: return "#3DBE8B"
        case .custom: return "#9AA0A6"
        }
    }

    /// Seed prompts loaded into the Prompt Library when the user picks this case.
    /// Brand-free. Generic patterns that work across any chat-completions model.
    var seedPrompts: [PromptItem] {
        switch self {
        case .coding:
            return [
                PromptItem(title: "Explain this code",
                           body: "Read the code I paste next. Explain what it does at three levels: one-sentence summary, function-by-function, and any non-obvious invariants. Flag anything that looks broken.",
                           tags: ["code", "explain"]),
                PromptItem(title: "Refactor for clarity",
                           body: "Refactor the code below for readability without changing behavior. Keep the public API stable. Show only the diff. Explain each change in one line.",
                           tags: ["code", "refactor"]),
                PromptItem(title: "Write a focused test",
                           body: "Write a single failing unit test that pins the bug described below. Use the project's test style. No extra setup, no commentary inside the test body.",
                           tags: ["code", "test"]),
                PromptItem(title: "Code review (strict)",
                           body: "Review this diff like a senior on a critical path. Find real bugs first, then design smells, then style. Skip nits. Format: severity, location, fix.",
                           tags: ["code", "review"])
            ]
        case .design:
            return [
                PromptItem(title: "UX critique",
                           body: "Critique the screen described below. Cover hierarchy, scannability, accessibility, and the action the user is meant to take. End with the single highest-impact change.",
                           tags: ["design", "critique"]),
                PromptItem(title: "Three variations",
                           body: "Give me three distinct design directions for the brief below. Each one a single paragraph plus a one-line trade-off. No bullet lists.",
                           tags: ["design", "ideation"]),
                PromptItem(title: "Microcopy pass",
                           body: "Rewrite the labels and copy below for clarity and warmth without losing precision. Match my product voice: confident, brief, no jargon.",
                           tags: ["design", "copy"])
            ]
        case .research:
            return [
                PromptItem(title: "Summarize",
                           body: "Summarize the text below into five bullets, then a one-line takeaway. Keep numbers, names, and dates exact.",
                           tags: ["writing", "summary"]),
                PromptItem(title: "Counter-argument",
                           body: "Steel-man the position below, then write the strongest counter-argument. Two paragraphs each. End with which side I'm underweighting and why.",
                           tags: ["writing", "critical"]),
                PromptItem(title: "Outline an essay",
                           body: "Outline an essay arguing the thesis below. Five sections, one sentence each, plus the hook and the closer. Aim for a thoughtful general reader.",
                           tags: ["writing", "outline"])
            ]
        case .operations:
            return [
                PromptItem(title: "Break into tickets",
                           body: "Break the feature described below into independent tickets a small team can ship in a sprint. Each ticket: title, one-line scope, acceptance criteria. Order by dependency.",
                           tags: ["ops", "planning"]),
                PromptItem(title: "Weekly status",
                           body: "Draft a weekly status update from the notes below. Sections: Shipped, In flight, Blocked, Next. Tight bullets. No filler.",
                           tags: ["ops", "status"]),
                PromptItem(title: "Define MVP",
                           body: "Given the feature pitch below, define the smallest version that proves the hypothesis. List what's in, what's out, and the single metric we'd watch.",
                           tags: ["ops", "scope"])
            ]
        case .everyday:
            return [
                PromptItem(title: "Quick brainstorm",
                           body: "Give me ten ideas on the topic below. Mix obvious with weird. One line each. No explanations.",
                           tags: ["everyday", "ideas"]),
                PromptItem(title: "Rewrite for tone",
                           body: "Rewrite the text below to be confident and warm, the way a thoughtful friend would say it. Keep the meaning exact.",
                           tags: ["everyday", "writing"]),
                PromptItem(title: "Explain like I'm five",
                           body: "Explain the concept below to me as if I'm bright but new to the topic. Use a concrete analogy. Three short paragraphs.",
                           tags: ["everyday", "explain"])
            ]
        case .custom:
            return []
        }
    }

    /// Curated MCP server suggestions per use case. Real HTTP endpoints,
    /// brand-free capability labels so the binary stays App Store safe under
    /// guideline 4.1. The URL is what reveals the underlying service.
    var recommendedMCPs: [MCPSuggestion] {
        switch self {
        case .coding: return [
            MCPSuggestion(
                label: "Source control",
                urlString: "https://api.githubcopilot.com/mcp/",
                blurb: "Read repositories, search code, manage issues and pull requests.",
                symbol: "chevron.left.forwardslash.chevron.right",
                tintHex: "#5BC0EB",
                needsAuth: true
            ),
            MCPSuggestion(
                label: "Issue tracker",
                urlString: "https://mcp.linear.app/sse",
                blurb: "Pull, create, and update tickets across your workspace.",
                symbol: "checklist",
                tintHex: "#7A7AFF",
                needsAuth: true
            ),
            MCPSuggestion(
                label: "Error monitoring",
                urlString: "https://mcp.sentry.dev/sse",
                blurb: "Query crashes, performance traces, and release health.",
                symbol: "exclamationmark.triangle.fill",
                tintHex: "#FF7A8A",
                needsAuth: true
            )
        ]
        case .design: return [
            MCPSuggestion(
                label: "Design files",
                urlString: "https://mcp.figma.com/sse",
                blurb: "Read frames, components, and dev-mode metadata from your files.",
                symbol: "paintbrush.pointed.fill",
                tintHex: "#FF7A8A",
                needsAuth: true
            ),
            MCPSuggestion(
                label: "Asset storage",
                urlString: "https://mcp.cloudflare.com/sse",
                blurb: "Browse and reference your hosted images, videos, and files.",
                symbol: "shippingbox.fill",
                tintHex: "#F5A623",
                needsAuth: true
            )
        ]
        case .research: return [
            MCPSuggestion(
                label: "Web search",
                urlString: "https://mcp.tavily.com/mcp",
                blurb: "Search the live web and pull clean snippets into your chat.",
                symbol: "magnifyingglass",
                tintHex: "#3DBE8B",
                needsAuth: true
            ),
            MCPSuggestion(
                label: "Documentation",
                urlString: "https://docs.mcp.cloudflare.com/sse",
                blurb: "Search and quote technical docs without leaving the chat.",
                symbol: "books.vertical.fill",
                tintHex: "#7A7AFF",
                needsAuth: false
            ),
            MCPSuggestion(
                label: "Notes & knowledge base",
                urlString: "https://mcp.notion.com/mcp",
                blurb: "Read and write pages, databases, and notes in your workspace.",
                symbol: "doc.text.fill",
                tintHex: "#9AA0A6",
                needsAuth: true
            )
        ]
        case .operations: return [
            MCPSuggestion(
                label: "Issue tracker & docs",
                urlString: "https://mcp.atlassian.com/v1/sse",
                blurb: "Pull tickets, create issues, search company docs.",
                symbol: "checklist",
                tintHex: "#5BC0EB",
                needsAuth: true
            ),
            MCPSuggestion(
                label: "Project management",
                urlString: "https://mcp.linear.app/sse",
                blurb: "Read and update product tickets and projects.",
                symbol: "list.bullet.rectangle.portrait",
                tintHex: "#7A7AFF",
                needsAuth: true
            ),
            MCPSuggestion(
                label: "Tasks",
                urlString: "https://mcp.asana.com/sse",
                blurb: "Create tasks, list projects, update status.",
                symbol: "checkmark.circle.fill",
                tintHex: "#F5A623",
                needsAuth: true
            )
        ]
        case .everyday: return [
            MCPSuggestion(
                label: "Web search",
                urlString: "https://mcp.tavily.com/mcp",
                blurb: "Search the live web from any chat.",
                symbol: "magnifyingglass",
                tintHex: "#3DBE8B",
                needsAuth: true
            )
        ]
        case .custom: return []
        }
    }
}

/// One row in the onboarding 'Recommended MCP servers' list.
/// Labels are intentionally brand-free, only the URL identifies the provider.
struct MCPSuggestion: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let urlString: String
    let blurb: String
    let symbol: String
    let tintHex: String
    let needsAuth: Bool

    /// Maps to an MCPServer model for installation into the store.
    func makeServer() -> MCPServer {
        MCPServer(
            name: label,
            baseURL: urlString,
            authHeader: "",
            enabled: !needsAuth, // auto-disable until user adds auth header
            symbolName: symbol,
            tintHex: tintHex
        )
    }
}
