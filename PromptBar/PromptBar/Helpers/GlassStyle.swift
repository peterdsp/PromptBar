//
//  GlassStyle.swift
//  PromptBar
//

import SwiftUI

/// Liquid Glass material backdrop. Requires macOS 26.
struct GlassBackdrop: View {
    var cornerRadius: CGFloat = 0

    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .ignoresSafeArea()
    }
}

/// A small pill chip used in toolbars / pickers.
struct GlassPillStyle: ButtonStyle {
    var isActive: Bool = false
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? tint.opacity(0.25) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isActive ? tint.opacity(0.45) : Color.gray.opacity(0.18),
                        lineWidth: 1
                    )
            )
            .foregroundStyle(isActive ? tint : .primary)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension Color {
    init(hex: String) {
        var hex = hex
        if hex.hasPrefix("#") { hex.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
