//
//  VoiceMicButton.swift
//  MindLoop
//
//  Voice recording button with 3 states: idle, listening, paused
//

import SwiftUI

/// Voice recording button states
enum MicState {
    case idle
    case listening
    case paused
}

/// Voice recording button with state-based appearance
struct VoiceMicButton: View {
    let state: MicState
    let onToggle: () -> Void
    let onStop: () -> Void

    var body: some View {
        switch state {
        case .idle:
            idleButton
        case .listening:
            listeningButtons
        case .paused:
            pausedButtons
        }
    }

    // MARK: - Idle State

    private var idleButton: some View {
        Button(action: onToggle) {
            Image(systemName: "mic.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color("Primary-Foreground"))
                .frame(width: 80, height: 80)
                .background(Color("Primary"))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Start recording")
    }

    // MARK: - Listening State

    private var listeningButtons: some View {
        HStack(spacing: Spacing.m) {
            // Main stop button (pulsing)
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Color(red: 0.48, green: 0.72, blue: 0.90)) // #7bb8e7
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Stop recording")
            .pulseAnimation()

            // Pause button
            Button(action: onToggle) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color("Foreground"))
                    .frame(width: 48, height: 48)
                    .background(Color("Muted"))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Pause recording")
        }
    }

    // MARK: - Paused State

    private var pausedButtons: some View {
        HStack(spacing: Spacing.m) {
            // Resume button
            Button(action: onToggle) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color("Foreground"))
                    .frame(width: 80, height: 80)
                    .background(Color("Muted"))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Resume recording")

            // Stop button
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.red)
                    .frame(width: 48, height: 48)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("Stop recording")
        }
    }
}

// MARK: - Button Style

/// Button style with scale-down effect on press
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Pulse Animation

extension View {
    func pulseAnimation() -> some View {
        self.modifier(PulseModifier())
    }
}

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Previews

#Preview("Idle") {
    VoiceMicButton(
        state: .idle,
        onToggle: {},
        onStop: {}
    )
    .padding()
}

#Preview("Listening") {
    VoiceMicButton(
        state: .listening,
        onToggle: {},
        onStop: {}
    )
    .padding()
}

#Preview("Paused") {
    VoiceMicButton(
        state: .paused,
        onToggle: {},
        onStop: {}
    )
    .padding()
}
