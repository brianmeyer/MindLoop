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
}

// MARK: - ContentView

struct ContentView: View {
    @State private var orchestrator = Orchestrator()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeScreen(
                onStartCheckin: {
                    navigationPath.append(Screen.journalCapture)
                },
                onQuickGratitude: {
                    // TODO: Navigate to Gratitude screen
                },
                onSettings: {
                    // TODO: Navigate to Settings screen
                },
                onViewHistory: {
                    // TODO: Navigate to History screen
                }
            )
            .navigationDestination(for: Screen.self) { screen in
                switch screen {
                case .journalCapture:
                    JournalCaptureScreen { transcript in
                        Task {
                            await orchestrator.processText(transcript)
                        }
                        navigationPath.append(Screen.coach)
                    }

                case .coach:
                    CoachScreen(orchestrator: orchestrator) {
                        // Pop to root on dismiss
                        navigationPath = NavigationPath()
                    }
                }
            }
        }
        .environment(orchestrator)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
