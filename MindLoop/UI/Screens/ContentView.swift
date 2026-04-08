//
//  ContentView.swift
//  MindLoop
//
//  Root navigation container with NavigationStack routing.
//  Owns the Orchestrator and NavigationPath for programmatic navigation.
//

import SwiftUI

// MARK: - Navigation Destinations

/// All routable screens in the app.
enum Screen: Hashable {
    case journalCapture
    case coach
    case timeline
    case settings
    case gratitude
}

// MARK: - ContentView

struct ContentView: View {
    @State private var orchestrator = Orchestrator()
    @State private var navigationPath = NavigationPath()
    /// Transcript waiting to be processed after navigation to CoachScreen completes.
    @State private var pendingTranscript: String = ""
    /// Prosody features captured during voice journaling, passed through with
    /// `pendingTranscript` so the CoachScreen's `.task` can invoke the hybrid
    /// emotion pipeline. (REC-288)
    @State private var pendingProsody: [String: Double] = [:]
    @State private var showGratitudeSheet = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeScreen(
                onStartCheckin: {
                    navigationPath.append(Screen.journalCapture)
                },
                onQuickGratitude: {
                    showGratitudeSheet = true
                },
                onSettings: {
                    navigationPath.append(Screen.settings)
                },
                onViewHistory: {
                    navigationPath.append(Screen.timeline)
                }
            )
            .navigationDestination(for: Screen.self) { screen in
                switch screen {
                case .journalCapture:
                    JournalCaptureScreen { transcript, prosody in
                        // REC-283: Store transcript and set analyzing state synchronously
                        // so CoachScreen shows the thinking indicator immediately.
                        // Navigation happens first; .task on CoachScreen triggers processText.
                        // REC-288: also carry prosody features through to the pipeline.
                        pendingTranscript = transcript
                        pendingProsody = prosody
                        orchestrator.preparePipeline()
                        navigationPath.append(Screen.coach)
                    }

                case .coach:
                    CoachScreen(orchestrator: orchestrator) {
                        // Pop to root on dismiss
                        navigationPath = NavigationPath()
                    }
                    .task {
                        // REC-283: Process text after CoachScreen has appeared,
                        // avoiding the race where processText fires before
                        // the destination view is on screen.
                        let transcript = pendingTranscript
                        let prosody = pendingProsody
                        guard !transcript.isEmpty else { return }
                        pendingTranscript = ""
                        pendingProsody = [:]
                        await orchestrator.processText(transcript, prosodyFeatures: prosody)
                    }

                case .timeline:
                    TimelineScreen(database: .shared) {
                        navigationPath.removeLast()
                    }

                case .settings:
                    SettingsScreen()

                case .gratitude:
                    GratitudeEntryView(
                        onSave: { entry in
                            saveGratitudeEntry(entry)
                        },
                        onDismiss: {
                            navigationPath = NavigationPath()
                        }
                    )
                }
            }
        }
        .environment(orchestrator)
        .sheet(isPresented: $showGratitudeSheet) {
            GratitudeEntryView(
                onSave: { entry in
                    saveGratitudeEntry(entry)
                },
                onDismiss: {
                    showGratitudeSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Helpers

    private func saveGratitudeEntry(_ entry: JournalEntry) {
        let record = JournalEntryRecord(from: entry)
        try? AppDatabase.shared.saveEntry(record)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
