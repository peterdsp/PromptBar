//
//  LicenseEntryView.swift
//  PromptBar
//
//  First-launch activation for EXTERNAL_DISTRIBUTION builds.
//
//  Activation is file-based only: drop the license.promptbar file we email
//  you, or paste its contents. The license is a signed block verified
//  entirely on-device (LicenseValidator), so no network call is made and
//  knowing a buyer's email address is never enough to unlock the app.
//

#if EXTERNAL_DISTRIBUTION

import SwiftUI
import UniformTypeIdentifiers

struct LicenseEntryView: View {
    let onLicensed: (License) -> Void

    @State private var input: String = ""
    @State private var errorMessage: String?
    @State private var isDropTargeted = false
    @State private var successEmail: String?
    @State private var showRecovery = false

    var body: some View {
        ZStack {
            GlassBackdrop()

            VStack(spacing: 16) {
                Spacer().frame(height: 14)

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.regularMaterial)
                        .frame(width: 90, height: 90)
                    Image(systemName: "key.viewfinder")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 4) {
                    if LicenseStore.shared.trialExpired {
                        Label("Your 7 day trial has ended", systemImage: "hourglass.bottomhalf.filled")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.bottom, 2)
                    }
                    Text("Activate PromptBar")
                        .font(.title2.weight(.semibold))
                    Text("Drop the license.promptbar file from your purchase email, or paste its contents below.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                licenseDropCard
                    .padding(.horizontal, 30)
                    .frame(maxWidth: 460)

                if let err = errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                if let success = successEmail {
                    Label("Licensed to \(success)", systemImage: "checkmark.seal.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.green)
                }

                HStack(spacing: 10) {
                    Button("Buy on Ko-fi") {
                        if let url = URL(string: "https://ko-fi.com/peterdsp") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("Activate") {
                        validateFile()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                DisclosureGroup(isExpanded: $showRecovery) {
                    recoveryCard
                        .padding(.top, 6)
                } label: {
                    Text("I can't find my license file")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 30)
                .frame(maxWidth: 460)

                Spacer()
            }
        }
        .frame(width: 580, height: dynamicHeight)
    }

    private var dynamicHeight: CGFloat {
        var h: CGFloat = 520
        if showRecovery { h += 170 }
        return h
    }

    // MARK: - License file drop / paste

    private var licenseDropCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor : Color.gray.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, dash: [5])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                    )
                if input.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                        Text("Drop your license.promptbar file here, or paste its contents")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                TextEditor(text: $input)
                    .font(.system(size: 10, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .opacity(input.isEmpty ? 0.0 : 1.0)
            }
            .frame(height: 150)
            .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil),
                   let contents = try? String(contentsOf: url, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.input = contents
                        self.errorMessage = nil
                    }
                }
            }
            return true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                if let text = item as? String {
                    DispatchQueue.main.async {
                        self.input = text
                        self.errorMessage = nil
                    }
                } else if let data = item as? Data,
                          let text = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.input = text
                        self.errorMessage = nil
                    }
                }
            }
            return true
        }
        return false
    }

    private func validateFile() {
        errorMessage = nil
        successEmail = nil
        switch LicenseStore.shared.install(input) {
        case .success(let license):
            successEmail = license.email
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onLicensed(license)
            }
        case .failure(let err):
            errorMessage = err.localizedDescription
        }
    }

    // MARK: - Recovery (collapsed by default)

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Things to try")
                .font(.subheadline.weight(.semibold))
            Text("• Check your purchase email for the license.promptbar attachment, or copy the LICENSE block from the email body and paste it above.\n• Wait 1 to 5 minutes after purchase; licenses are emailed as orders come in.\n• Check your spam folder in case you missed the email.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    openLicenseSupportMail()
                } label: {
                    Label("Email the developer", systemImage: "envelope")
                }
                .controlSize(.small)
                Button {
                    if let url = URL(string: "https://ko-fi.com/peterdsp") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Re-open Ko-fi", systemImage: "arrow.up.right.square")
                }
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
        )
    }

    private func openLicenseSupportMail() {
        let recipient = "peterdsp29@gmail.com"
        let subject = "PromptBar license help"
        let body = """
        Hi Petros,

        I bought PromptBar on Ko-fi and can't find or activate my license.

        Email used on Ko-fi:
        Ko-fi order ID (in your Ko-fi receipt email):

        Thanks
        """
        var components = URLComponents(string: "mailto:\(recipient)")
        components?.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = components?.url {
            NSWorkspace.shared.open(url)
        }
    }
}

#endif
