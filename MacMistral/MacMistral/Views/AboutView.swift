//
//  AboutView.swift
//  MacMistral
//
//  Created by Petros Dhespollari on 10/01/2025.
//

import FirebaseRemoteConfig
import SwiftUI

struct AboutView: View {
    @State private var autoUpdateEnabled: Bool = UserDefaults.standard.bool(
        forKey: "autoUpdateEnabled")
    @State private var updateAvailable = false
    @State private var isChecking = false
    @State private var showError = false
    @State private var downloadURL: URL?

    private let remoteConfig = RemoteConfig.remoteConfig()

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

            if isChecking {
                ProgressView()
                    .scaleEffect(0.5)
                    .padding(.bottom)
            }

            if updateAvailable {
                Button("Update Available") {
                    if let url = downloadURL {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: checkForUpdate) {
                    Text("Check for Updates")
                }
                .disabled(isChecking)
            }

            if showError {
                Text("Failed to check for updates")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
        .onAppear {
            setupRemoteConfig()
        }
    }

    private func setupRemoteConfig() {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 3600  // 1 hour
        remoteConfig.configSettings = settings
    }

    private func checkForUpdate() {
        isChecking = true
        showError = false

        let localVersion =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "0"

        guard let window = NSApplication.shared.mainWindow else {
            print("No main window found")
            return
        }

        // Initial checking alert
        let checkingAlert = NSAlert()
        checkingAlert.messageText = "Checking for Updates..."
        checkingAlert.informativeText =
            "Please wait while we check for updates."
        checkingAlert.addButton(withTitle: "Cancel")

        let progressIndicator = NSProgressIndicator(
            frame: NSRect(x: 0, y: 0, width: 200, height: 20))
        progressIndicator.style = .spinning
        progressIndicator.startAnimation(nil)
        checkingAlert.accessoryView = progressIndicator

        checkingAlert.beginSheetModal(for: window) { _ in
            self.isChecking = false
        }

        // Fetch Remote Config
        remoteConfig.fetch(withExpirationDuration: 0) { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.showError = true
                    self.isChecking = false

                    // Close the checking alert
                    NSApp.endSheet(checkingAlert.window)
                    checkingAlert.window.orderOut(nil)

                    let errorAlert = NSAlert()
                    errorAlert.messageText = "Update Check Failed"
                    errorAlert.informativeText =
                        "Error checking for updates: \(error.localizedDescription)"
                    errorAlert.addButton(withTitle: "OK")
                    errorAlert.beginSheetModal(for: window)
                    return
                }

                self.remoteConfig.activate { changed, activateError in
                    DispatchQueue.main.async {
                        if let activateError = activateError {
                            self.showError = true
                            self.isChecking = false

                            // Close the checking alert
                            NSApp.endSheet(checkingAlert.window)
                            checkingAlert.window.orderOut(nil)

                            let errorAlert = NSAlert()
                            errorAlert.messageText = "Update Check Failed"
                            errorAlert.informativeText =
                                "Error activating update config: \(activateError.localizedDescription)"
                            errorAlert.addButton(withTitle: "OK")
                            errorAlert.beginSheetModal(for: window)
                            return
                        }

                        let remoteVersion =
                            self.remoteConfig["version"].stringValue
                            ?? "Unknown"
                        let downloadLink =
                            self.remoteConfig["download_url"].stringValue ?? ""

                        print("Fetched Remote Version: \(remoteVersion)")
                        print("Download URL: \(downloadLink)")

                        self.isChecking = false

                        // Close the checking alert BEFORE showing the new alert
                        NSApp.endSheet(checkingAlert.window)
                        checkingAlert.window.orderOut(nil)

                        if remoteVersion != "Unknown"
                            && self.isVersionNewer(
                                current: localVersion, latest: remoteVersion)
                        {
                            self.downloadURL = URL(string: downloadLink)
                            self.updateAvailable = true

                            let updateAlert = NSAlert()
                            updateAlert.messageText = "Update Available!"
                            updateAlert.informativeText =
                                "Version \(remoteVersion) is available. Do you want to download it?"
                            updateAlert.addButton(withTitle: "Download")
                            updateAlert.addButton(withTitle: "Cancel")

                            updateAlert.beginSheetModal(for: window) {
                                response in
                                if response == .alertFirstButtonReturn,
                                    let url = self.downloadURL
                                {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        } else {
                            self.updateAvailable = false

                            let upToDateAlert = NSAlert()
                            upToDateAlert.messageText = "You're Up-to-Date!"
                            upToDateAlert.informativeText =
                                "You already have the latest version (\(localVersion))."
                            upToDateAlert.addButton(withTitle: "OK")
                            upToDateAlert.beginSheetModal(for: window)
                        }
                    }
                }
            }
        }
    }

    private func isVersionNewer(current: String, latest: String) -> Bool {
        let currentComponents = current.split(separator: ".").compactMap {
            Int($0)
        }
        let latestComponents = latest.split(separator: ".").compactMap {
            Int($0)
        }

        for (currentPart, latestPart) in zip(
            currentComponents, latestComponents)
        {
            if latestPart > currentPart {
                return true
            } else if latestPart < currentPart {
                return false
            }
        }

        return latestComponents.count > currentComponents.count
    }
}
