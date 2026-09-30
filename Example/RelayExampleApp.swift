// Minimal SwiftUI example for RelaySDK.
// Create an iOS 17 App project in Xcode, add the RelaySDK package, and replace the
// generated App file with this one.

import SwiftUI
import RelaySDK

@main
struct RelayExampleApp: App {
    init() {
        Relay.configure(
            projectKey: "pk_live_replace_me",
            baseURL: URL(string: "https://relay-wishkit.reza-rzny.workers.dev")!,
            timeout: 20,
            theme: RelayTheme(accentColor: .indigo)
        )
    }

    var body: some Scene {
        WindowGroup {
            ExampleHomeView()
        }
    }
}

struct ExampleHomeView: View {
    @State private var showFeedback = false
    @State private var showMessages = false
    @State private var language: RelayLanguage = .best()
    @State private var directResult = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            List {
                Section("Ready-made UI") {
                    RelayFeedbackButton()
                    RelayFeedbackButton(initialType: .bug) {
                        Label("Report a bug", systemImage: "ladybug")
                    }
                    Button("Open form in a sheet") { showFeedback = true }
                    Button("My Messages") { showMessages = true }
                }

                Section("Language") {
                    Picker("Language", selection: $language) {
                        Text("English").tag(RelayLanguage.english)
                        Text("فارسی").tag(RelayLanguage.persian)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Direct API") {
                    Button {
                        Task { await submitDirectly() }
                    } label: {
                        if isSubmitting { ProgressView() } else { Text("Submit a bug programmatically") }
                    }
                    .disabled(isSubmitting)
                    if !directResult.isEmpty {
                        Text(directResult)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Relay Example")
            .sheet(isPresented: $showFeedback) {
                RelayFeedbackView()
                    .relayLanguage(language)
            }
            .sheet(isPresented: $showMessages) {
                RelayMyMessagesView()
                    .relayLanguage(language)
            }
        }
    }

    private func submitDirectly() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let report = try await Relay.submit(
                type: .bug,
                title: "Login problem",
                message: "The login button does not work."
            )
            let thread = try await Relay.fetchThread(id: report.id)
            directResult = "Sent \(report.id) – status: \(thread.status.display.rawValue), replies: \(thread.replies.count)"
        } catch {
            directResult = error.localizedDescription
        }
    }
}
