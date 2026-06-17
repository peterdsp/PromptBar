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

    /// Generic MCP URL hints to show in the use-case summary. No brand names.
    /// The user types what they want to call each service.
    var suggestedMCPURLs: [String] {
        switch self {
        case .coding: return [
            "https://mcp.example.com/git",
            "https://mcp.example.com/issues",
            "http://localhost:7331/mcp"
        ]
        case .design: return [
            "https://mcp.example.com/design",
            "https://mcp.example.com/storage"
        ]
        case .research: return [
            "https://mcp.example.com/web-search",
            "https://mcp.example.com/notes"
        ]
        case .operations: return [
            "https://mcp.example.com/tickets",
            "https://mcp.example.com/docs",
            "https://mcp.example.com/calendar"
        ]
        case .everyday: return [
            "https://mcp.example.com/web-search"
        ]
        case .custom: return []
        }
    }
}
