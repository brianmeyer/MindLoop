//
//  JournalCaptureScreen.swift
//  MindLoop
//
//  Audio-first journal capture with voice recording and live transcription
//

import SwiftUI

/// Journal entry capture screen with voice recording
struct JournalCaptureScreen: View {
    @Environment(\.dismiss) private var dismiss

    @State private var micState: MicState = .idle
    @State private var transcript: String = ""
    @State private var seconds: Int = 0
    @State private var timer: Timer?
    @State private var audioRecorder = AudioRecorder()

    let onComplete: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Main Content
            VStack(spacing: Spacing.xl) {
                // Prompt
                promptSection
                    .padding(.top, Spacing.xxl)

                Spacer()

                // Voice Button
                VoiceMicButton(
                    state: micState,
                    onToggle: handleToggleMic,
                    onStop: handleStop
                )

                // Waveform (shown when recording/paused)
                if micState != .idle {
                    Waveform(
                        isActive: micState == .listening,
                        audioLevel: audioRecorder.audioLevel
                    )
                    .transition(.opacity.combined(with: .scale))
                }

                // Live Transcript (shown when recording/paused)
                if micState != .idle {
                    transcriptEditor
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.l)
            .animation(.easeInOut(duration: 0.3), value: micState)
        }
        .background(Color("Background"))
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Components

    private var header: some View {
        HStack {
            // Back Button
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20))
                    .foregroundStyle(Color("Foreground"))
                    .frame(width: 40, height: 40)
                    .background(Color("Muted"))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()

            // Timer
            TimerBadge(seconds: seconds)

            Spacer()

            // Spacer to balance back button
            Color.clear
                .frame(width: 40)
        }
        .padding(Spacing.l)
        .background(Color("Background"))
        .overlay(
            Rectangle()
                .fill(Color("Border"))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var promptSection: some View {
        Text("What's on your mind?")
            .typography(.subheading)
            .foregroundStyle(Color("Foreground"))
            .multilineTextAlignment(.center)
    }

    private var transcriptEditor: some View {
        TextEditor(text: $transcript)
            .typography(.body)
            .foregroundStyle(Color("Foreground"))
            .scrollContentBackground(.hidden)
            .padding(Spacing.m)
            .frame(minHeight: 120)
            .background(Color("Muted"))
            .cornerRadius(CornerRadius.l)
            .overlay(
                Group {
                    if transcript.isEmpty {
                        Text("Your thoughts appear here...")
                            .typography(.body)
                            .foregroundStyle(Color("Text/TextTertiary"))
                            .padding(Spacing.m)
                            .padding(.top, 8) // TextEditor internal padding adjustment
                            .allowsHitTesting(false)
                    }
                },
                alignment: .topLeading
            )
    }

    // MARK: - Actions

    private func handleToggleMic() {
        switch micState {
        case .idle:
            // Start recording
            do {
                try audioRecorder.startRecording()
                micState = .listening
                startTimer()
            } catch {
                print("Failed to start recording: \(error)")
            }

        case .listening:
            // Pause recording
            audioRecorder.pauseRecording()
            micState = .paused
            stopTimer()

        case .paused:
            // Resume recording
            audioRecorder.resumeRecording()
            micState = .listening
            startTimer()
        }
    }

    private func handleStop() {
        // Stop recording and get audio file URL
        let audioURL = audioRecorder.stopRecording()

        micState = .idle
        stopTimer()

        // TODO (Phase 2): Send audioURL to Apple Speech Framework for transcription
        // For now, only complete if there's manual text
        if !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || seconds > 0 {
            onComplete(transcript)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            seconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        JournalCaptureScreen { transcript in
            print("Completed with transcript: \(transcript)")
        }
    }
}
