import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Appearance Section
                Section {
                    Picker("Theme", selection: $viewModel.appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Appearance mode")
                    .accessibilityHint("Choose between system, light, or dark theme")
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose how the app looks")
                }

                // MARK: - About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("App version \(appVersion)")

                    if let githubURL = URL(string: "https://github.com/oozoofrog/Textify") {
                        Link(destination: githubURL) {
                            HStack {
                                Label("GitHub", systemImage: "link")
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Open GitHub repository")
                    }
                } header: {
                    Text("About")
                }

                // MARK: - Data Section
                Section {
                    Button(role: .destructive) {
                        viewModel.requestClearHistory()
                    } label: {
                        Label("Clear History", systemImage: "trash")
                    }
                    .accessibilityLabel("Clear history")
                    .accessibilityHint("Removes all saved history items")
                } header: {
                    Text("Data")
                } footer: {
                    Text("This will remove all saved history items")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Clear History",
                isPresented: $viewModel.showClearHistoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear History", role: .destructive) {
                    viewModel.confirmClearHistory()
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelClearHistory()
                }
            } message: {
                Text("This will permanently delete all history items. This action cannot be undone.")
            }
        }
    }

    // MARK: - Private Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}

// MARK: - Previews

#Preview("Settings View") {
    SettingsView(
        viewModel: SettingsViewModel(
            appearanceService: AppearanceService()
        )
    )
}
