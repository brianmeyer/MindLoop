//
//  SettingsScreen.swift
//  MindLoop
//
//  Settings screen with profile, voice, model info, privacy, data, and about sections.
//  Ticket: REC-247
//

import os
import SwiftUI

// MARK: - SettingsScreen

struct SettingsScreen: View {
    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @AppStorage("userName") private var userName: String = ""
    @AppStorage("voiceJournalingEnabled") private var voiceJournalingEnabled: Bool = true
    @State private var showClearDataAlert = false
    @State private var didClearData = false

    // MARK: - Dependencies

    private let modelRuntime = ModelRuntime.shared
    private let database = AppDatabase.shared

    // MARK: - Body

    var body: some View {
        Form {
            profileSection
            voiceSection
            modelInfoSection
            privacySection
            dataSection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .background(Color("Background"))
        .alert("Clear All Data", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All Data", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all journal entries, emotions, and personalization data. This action cannot be undone.")
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section {
            HStack(spacing: Spacing.m) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color("Primary"))
                    .accessibilityHidden(true)

                TextField("Your name", text: $userName)
                    .typography(.body)
                    .foregroundColor(Color("Foreground"))
                    .textContentType(.name)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Your name")
                    .accessibilityHint("Enter your name for personalized greetings")
            }
        } header: {
            Text("Profile")
                .typography(.small)
        }
    }

    // MARK: - Voice Section

    private var voiceSection: some View {
        Section {
            Toggle(isOn: $voiceJournalingEnabled) {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color("Primary"))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Voice Journaling")
                            .typography(.body)
                            .foregroundColor(Color("Foreground"))

                        Text("Record journal entries using your voice")
                            .typography(.caption)
                            .foregroundColor(Color("MutedForeground"))
                    }
                }
            }
            .tint(Color("Primary"))
            .accessibilityLabel("Voice journaling")
            .accessibilityValue(voiceJournalingEnabled ? "Enabled" : "Disabled")
            .accessibilityHint("Toggle voice recording for journal entries")
        } header: {
            Text("Voice")
                .typography(.small)
        }
    }

    // MARK: - Model Info Section

    private var modelInfoSection: some View {
        Section {
            modelInfoRow(
                label: "Model",
                value: "Gemma 4 E2B-it",
                icon: "cpu"
            )

            modelInfoRow(
                label: "Quantization",
                value: "4-bit (MLX)",
                icon: "memorychip"
            )

            modelInfoRow(
                label: "Memory Usage",
                value: modelRuntime.memoryUsageMB > 0
                    ? "\(modelRuntime.memoryUsageMB) MB"
                    : "Not loaded",
                icon: "gauge.with.dots.needle.bottom.50percent"
            )

            modelInfoRow(
                label: "Status",
                value: modelRuntime.isLoaded ? "Loaded" : "Not loaded",
                icon: "circle.fill",
                valueColor: modelRuntime.isLoaded
                    ? Color("Success")
                    : Color("MutedForeground")
            )
        } header: {
            Text("Model Info")
                .typography(.small)
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        Section {
            HStack(spacing: Spacing.m) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color("Primary"))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("On-Device Processing")
                        .typography(.body)
                        .foregroundColor(Color("Foreground"))

                    Text("All data stays on your device. No cloud, no tracking, no telemetry.")
                        .typography(.caption)
                        .foregroundColor(Color("MutedForeground"))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Privacy. All data stays on your device. No cloud, no tracking, no telemetry.")
        } header: {
            Text("Privacy")
                .typography(.small)
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showClearDataAlert = true
            } label: {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "trash")
                        .font(.system(size: 20))
                        .accessibilityHidden(true)

                    Text("Clear All Data")
                        .typography(.body)
                }
            }
            .accessibilityLabel("Clear all data")
            .accessibilityHint("Permanently deletes all journal entries and personalization data")
        } header: {
            Text("Data")
                .typography(.small)
        } footer: {
            if didClearData {
                Text("All data has been cleared.")
                    .typography(.caption)
                    .foregroundColor(Color("Primary"))
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            modelInfoRow(
                label: "Version",
                value: appVersion,
                icon: "info.circle"
            )

            modelInfoRow(
                label: "Build",
                value: appBuild,
                icon: "hammer"
            )
        } header: {
            Text("About")
                .typography(.small)
        }
    }

    // MARK: - Helpers

    private func modelInfoRow(
        label: String,
        value: String,
        icon: String,
        valueColor: Color? = nil
    ) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color("MutedForeground"))
                .frame(width: Spacing.xl)
                .accessibilityHidden(true)

            Text(label)
                .typography(.body)
                .foregroundColor(Color("Foreground"))

            Spacer()

            Text(value)
                .typography(.small)
                .foregroundColor(valueColor ?? Color("MutedForeground"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.lycan.MindLoop",
        category: "SettingsScreen"
    )

    private func clearAllData() {
        do {
            try database.clearAllData()
            userName = ""
            didClearData = true
        } catch {
            Self.logger.error("Failed to clear data: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsScreen()
    }
}
