//
//  MindLoopApp.swift
//  MindLoop
//
//  Created by Brian Meyer on 10/26/25.
//

import SwiftUI

@main
struct MindLoopApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                MainNavigationView()
            }
        }
    }
}

/// Main navigation container with routing logic
struct MainNavigationView: View {
    @State private var navigationPath = NavigationPath()

    var body: some View {
        HomeScreen(
            onStartCheckin: {
                navigationPath.append(Screen.journalCapture)
            },
            onQuickGratitude: {
                print("Quick gratitude tapped")
                // TODO: Navigate to Gratitude screen
            },
            onSettings: {
                print("Settings tapped")
                // TODO: Navigate to Settings screen
            },
            onViewHistory: {
                print("View history tapped")
                // TODO: Navigate to History screen
            }
        )
        .navigationDestination(for: Screen.self) { screen in
            switch screen {
            case .journalCapture:
                JournalCaptureScreen { transcript in
                    print("Journal entry completed: \(transcript)")
                    // TODO: Save entry to database
                    navigationPath.removeLast()
                }
            }
        }
    }
}

/// Navigation destinations
enum Screen: Hashable {
    case journalCapture
}
