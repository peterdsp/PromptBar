//
//  LicenseEntryView.swift
//  PromptBar
//
//  First-launch activation for EXTERNAL_DISTRIBUTION builds.
//
//  Primary flow: type the email and order id from your Ko-fi receipt,
//  click Activate, the app fetches your signed license from the license
//  server. Both are required: an email address alone is not a secret, so
//  the order id is what proves the purchase is yours.
//
//  Fallback flow (collapsed by default): drop or paste a .promptbar file.
//

#if EXTERNAL_DISTRIBUTION

import SwiftUI
import UniformTypeIdentifiers

struct LicenseEntryView: View {
    let onLicensed: (License) -> Void

    @State private var email: String = ""
    @State private var orderID: String = ""
    @State private var input: String = ""
    @State private var errorMessage: String?
    @State private var isDropTargeted = false
    @State private var successEmail: String?
    @State private var showFileDrop = false
    @State private var showRecovery = false
    @State private var isActivating = false

    /// License server URL. Configured at build time via Info.plist key
    /// `PromptBarLicenseEndpoint`; falls back to peterdsp.dev domain.
    private var activateURL: URL? {
        let configured = Bundle.main.object(forInfoDictionaryKey: "PromptBarLicenseEndpoint")
            as? String
        let raw = configured?.trimmingCharacters(in: .whitespaces).isEmpty == false
            ? configured!
            : "https://licenses.peterdsp.dev/activate"
        return URL(string: raw)
    }

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
                    Text("Type the email and order id from your Ko-fi receipt. We'll fetch your license automatically.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope")
                            .foregroundStyle(.secondary)
                        TextField("you@example.com", text: $email)
                            .textFieldStyle(.plain)
                            .disableAutocorrection(true)
                            .onSubmit { activateByEmail() }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.regularMaterial)
                    )

                    HStack(spacing: 8) {
                        Image(systemName: "number")
                            .foregroundStyle(.secondary)
                        TextField("Order id from your Ko-fi receipt", text: $orderID)
                            .textFieldStyle(.plain)
                            .disableAutocorrection(true)
                            .onSubmit { activateByEmail() }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.regularMaterial)
                    )
                }
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
                    Button {
                        activateByEmail()
                    } label: {
                        if isActivating {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.horizontal, 12)
                        } else {
                            Text("Activate")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        isActivating
                        || email.trimmingCharacters(in: .whitespaces).isEmpty
                        || orderID.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }

                DisclosureGroup(isExpanded: $showFileDrop) {
                    fileDropFallback
                        .padding(.top, 6)
                } label: {
                    Text("I have a license file instead")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 30)
                .frame(maxWidth: 460)

                DisclosureGroup(isExpanded: $showRecovery) {
                    recoveryCard
                        .padding(.top, 6)
                } label: {
                    Text("It says my email isn't recognized")
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
        // 470 base, plus room for the order-id field under the email field.
        var h: CGFloat = 518
        if showFileDrop { h += 230 }
        if showRecovery { h += 170 }
        return h
    }

    // MARK: - Email activation

    private func activateByEmail() {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOrder = orderID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@") else {
            errorMessage = "Type the email you used on Ko-fi."
            return
        }
        guard !trimmedOrder.isEmpty else {
            errorMessage = "Type the order id from your Ko-fi receipt."
            return
        }
        guard let url = activateURL else {
            errorMessage = "Activation server is misconfigured."
            return
        }

        errorMessage = nil
        successEmail = nil
        isActivating = true

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        let body: [String: String] = [
            "email": trimmed.lowercased(),
            "order_id": trimmedOrder,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isActivating = false
                if let error = error {
                    self.errorMessage = "Couldn't reach the license server: \(error.localizedDescription)"
                    return
                }
                guard let http = response as? HTTPURLResponse, let data = data else {
                    self.errorMessage = "No response from license server."
                    return
                }
                if http.statusCode == 404 {
                    self.errorMessage = "No license matches that email and order id. Both are on your Ko-fi receipt. Still stuck? Email info@peterdsp.dev."
                    return
                }
                if http.statusCode == 429 {
                    self.errorMessage = "Too many attempts. Wait a few minutes, or use the license file we emailed you."
                    return
                }
                if http.statusCode != 200 {
                    let detail = String(data: data, encoding: .utf8) ?? ""
                    self.errorMessage = "Server error \(http.statusCode). \(detail.prefix(120))"
                    return
                }
                guard let text = String(data: data, encoding: .utf8) else {
                    self.errorMessage = "License response wasn't valid text."
                    return
                }
                switch LicenseStore.shared.install(text) {
                case .success(let license):
                    self.successEmail = license.email
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.onLicensed(license)
                    }
                case .failure(let err):
                    self.errorMessage = "Server signed a license but it didn't verify locally: \(err.localizedDescription)"
                }
            }
        }.resume()
    }

    // MARK: - File-drop fallback (collapsed by default)

    private var fileDropFallback: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Power-user / offline path")
                .font(.subheadline.weight(.semibold))
            Text("If you received a .promptbar file by email, drop it below.")
                .font(.caption)
                .foregroundStyle(.secondary)

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
                        Text("Drop your .promptbar file here, or paste its contents")
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
            .frame(height: 130)
            .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers)
            }

            HStack {
                Spacer()
                Button("Validate file") {
                    validateFile()
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
        )
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
            Text("• Use the exact email and order id Ko-fi has on your receipt.\n• Wait 1 to 5 minutes after purchase; activations are issued as orders come in.\n• Check your spam folder for a confirmation in case you missed it.")
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

        I bought PromptBar on Ko-fi and the app can't find my license.

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
