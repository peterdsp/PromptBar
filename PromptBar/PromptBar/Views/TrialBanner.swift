//
//  TrialBanner.swift
//  PromptBar
//
//  Thin amber strip at the top of the main window during the free trial.
//  Only compiled into EXTERNAL_DISTRIBUTION builds. App Store binaries
//  never include this view.
//

#if EXTERNAL_DISTRIBUTION

import SwiftUI

struct TrialBanner: View {
    @ObservedObject private var store: LicenseStore = .shared

    var body: some View {
        if !store.isLicensed && store.isInTrial {
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .font(.system(size: 11, weight: .semibold))
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Button("Activate") {
                    (NSApp.delegate as? AppDelegate)?
                        .perform(NSSelectorFromString("openLicenseEntry"))
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.18))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.orange.opacity(0.45))
                    .frame(height: 0.5)
            }
            .foregroundStyle(Color.orange)
        }
    }

    private var message: String {
        let days = store.trialDaysRemaining
        switch days {
        case 0: return "Trial ends today. Activate to keep using PromptBar."
        case 1: return "1 day left in your trial."
        default: return "\(days) days left in your trial."
        }
    }
}

#endif
