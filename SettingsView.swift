import SwiftUI

struct SettingsView: View {
    @AppStorage("anthropicAPIKey") private var apiKey = ""
    @AppStorage("aiSummarizationEnabled") private var aiEnabled = false
    @AppStorage("refreshIntervalHours") private var refreshInterval = 3
    @AppStorage("darkModeOverride") private var darkMode = true
    @State private var showKeyField = false

    var body: some View {
        Form {
            Section("AI Summarization") {
                Toggle("Enable AI summaries (Claude API)", isOn: $aiEnabled)
                    .onChange(of: aiEnabled) { _, enabled in
                        if enabled && apiKey.isEmpty { showKeyField = true }
                    }

                if aiEnabled || showKeyField {
                    SecureField("Anthropic API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Your key is stored locally and never shared.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Refresh") {
                Picker("Refresh every", selection: $refreshInterval) {
                    Text("1 hour").tag(1)
                    Text("2 hours").tag(2)
                    Text("3 hours").tag(3)
                    Text("6 hours").tag(6)
                }
            }

            Section("Appearance") {
                Toggle("Dark mode", isOn: $darkMode)
            }

            Section("Personalization") {
                Button("Reset interest scores") {
                    UserDefaults.standard.removeObject(forKey: "interestScores")
                }
                .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 320)
    }
}
