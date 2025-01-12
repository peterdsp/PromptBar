//
//  AboutView.swift
//  MacMistral
//
//  Created by Petros Dhespollari on 10/01/2025.
//

import SwiftUI

struct AboutView: View {
    @State private var autoUpdateEnabled: Bool = UserDefaults.standard.bool(
        forKey: "autoUpdateEnabled")

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

            Text(
                "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")"
            )
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
