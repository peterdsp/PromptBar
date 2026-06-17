//
//  LicenseEntryView.swift
//  PromptBar
//
//  Shown on first launch of an EXTERNAL_DISTRIBUTION build until the user
//  pastes or drops a valid signed license file. Blocks access to the rest
//  of the app. App Store builds never see this view.
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
                Spacer().frame(height: 18)

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.regularMaterial)
                        .frame(width: 96, height: 96)
                    Image(systemName: "key.viewfinder")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 4) {
                    Text("Enter your PromptBar license")
                        .font(.title2.weight(.semibold))
                    Text("Check the email you received after your Ko-fi purchase. The file ends in .promptbar.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isDropTargeted ? Color.accentColor : Color.gray.opacity(0.4),
                            style: StrokeStyle(lineWidth: 1.5, dash: [5])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.regularMaterial)
                        )
                    if input.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 22))
                                .foregroundStyle(.secondary)
                            Text("Drop your license file here")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text("or paste its contents below")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    TextEditor(text: $input)
                        .font(.system(size: 11, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .opacity(input.isEmpty ? 0.0 : 1.0)
                }
                .frame(height: 180)
                .padding(.horizontal, 30)
                .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
                    handleDrop(providers)
                }

                if let err = errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let email = successEmail {
                    Label("Licensed to \(email)", systemImage: "checkmark.seal.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.green)
                }

                HStack(spacing: 10) {
                    Button("Buy on Ko-fi") {
                        if let url = URL(string: "https://ko-fi.com/peterdsp") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("Validate") {
                        validate()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                DisclosureGroup(isExpanded: $showRecovery) {
                    recoveryCard
                        .padding(.top, 6)
                } label: {
                    Text("I don't have a license file")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 30)
                .frame(maxWidth: 460)

                Spacer()
            }
        }
        .frame(width: 580, height: showRecovery ? 660 : 540)
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where the license comes from")
                .font(.subheadline.weight(.semibold))
            Text("Your license arrives by email within a few minutes of your Ko-fi purchase. Ko-fi delivers the installer, the email delivers the license. They come from two separate channels.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Things to try")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 6)
            Text("• Check your spam or promotions folder.\n• Search your inbox for 'PromptBar license'.\n• Confirm the email on your Ko-fi receipt matches your usual inbox.")
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

        I bought PromptBar on Ko-fi and can't find my license email.

        Ko-fi order ID (find it in your Ko-fi receipt email):
        Email used on Ko-fi:

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

    private func validate() {
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
}

#endif
