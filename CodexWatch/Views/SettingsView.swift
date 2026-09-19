import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")

                        Text("Settings")
                            .font(.headline)
                    }
                    .padding(.horizontal, 4)
                    .frame(height: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Back")

                Spacer()
            }

            Form {
                Section("General") {
                    Toggle("Launch at login", isOn: Binding(
                        get: { store.launchAtLogin },
                        set: { store.setLaunchAtLogin($0) }
                    ))
                    if let error = store.launchAtLoginError {
                        Text(error).font(.caption2).foregroundStyle(.red)
                    }
                    Toggle("Quota notifications at 20% and 5%", isOn: Binding(
                        get: { store.quotaNotifications },
                        set: { value in Task { await store.setNotifications(value) } }
                    ))
                    if let error = store.notificationError {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.red)
                            Button("Open Notification Settings") {
                                openNotificationSettings()
                            }
                            .font(.caption)
                        }
                    }
                }

                Section("Refresh") {
                    Picker("Interval", selection: $store.refreshInterval) {
                        Text("30 seconds").tag(30.0)
                        Text("1 minute").tag(60.0)
                        Text("2 minutes").tag(120.0)
                        Text("5 minutes").tag(300.0)
                        Text("10 minutes").tag(600.0)
                        Text("Never").tag(0.0)
                    }
                    Toggle("Refresh when menu opens", isOn: $store.refreshOnOpen)
                }

                Section("Menu Bar") {
                    Picker("Display", selection: $store.menuDisplayMode) {
                        ForEach(MenuDisplayMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(height: 315)

            Divider()
            HStack {
                Text("CodexWatch 0.6.0")
                Spacer()
                Text("Local Codex CLI usage")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .onChange(of: store.refreshInterval) { _, _ in store.configureTimer() }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
