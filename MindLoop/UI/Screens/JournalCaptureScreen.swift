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
    @State private var sttService = SpeechTranscriptionService()
    @State private var errorMessage: String?
    @State private var showAuthAlert: Bool = false
    @State private var isStopping: Bool = false

    /// Called when recording completes with the final transcript and any
    /// prosody features extracted from `SFVoiceAnalytics`. The prosody dict
    /// is empty when STT returned no metadata (e.g., very short recordings).
    let onComplete: (String, [String: Double]) -> Void

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
                        audioLevel: 0.6  // Indicative level; STT owns audio session
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
        .onChange(of: sttService.partialTranscript) { _, newValue in
            // Mirror STT partial results into the editor so users can see
            // their words appear live.
            transcript = newValue
        }
        .alert("Microphone permission required", isPresented: $showAuthAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable Microphone and Speech Recognition in Settings to use voice journaling.")
        }
        .alert(
            "Recording error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
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
            .accessibilityLabel("Go back")
            .accessibilityHint("Return to the home screen")

            Spacer()

            // Timer
            TimerBadge(seconds: seconds)

            Spacer()

            // Spacer to balance back button
            Color.clear
                .frame(width: 40)
                .accessibilityHidden(true)
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
            .accessibilityAddTraits(.isHeader)
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
            .accessibilityLabel("Journal transcript")
            .accessibilityHint("Edit or review your transcribed thoughts")
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
            Task { await startTranscription() }

        case .listening:
            // Pause transcription
            sttService.pauseTranscribing()
            micState = .paused
            stopTimer()

        case .paused:
            // Resume transcription
            do {
                try sttService.resumeTranscribing()
                micState = .listening
                startTimer()
            } catch {
                errorMessage = "Couldn't resume: \(error.localizedDescription)"
            }
        }
    }

    /// Request authorization (if needed) and start live on-device speech transcription.
    private func startTranscription() async {
        errorMessage = nil

        // Ensure authorization
        if sttService.authStatus != .authorized {
            let status = await sttService.requestAuthorization()
            if status != .authorized {
                showAuthAlert = true
                return
            }
        }

        do {
            try sttService.startTranscribing()
            micState = .listening
            startTimer()
        } catch {
            errorMessage = error.localizedDescription
            micState = .idle
        }
    }

    private func handleStop() {
        stopTimer()
        // Keep the button visibly "recording" until the async stop completes,
        // so a second tap can't start a fresh transcription and wipe the
        // partial buffer before we read it (reviewed race condition).
        guard !isStopping else { return }
        isStopping = true

        Task {
            let finalText = await sttService.stopTranscribing()
            let combined = !finalText.isEmpty ? finalText : transcript
            transcript = combined

            // REC-288: extract prosody features from the final recognition
            // result so EmotionAgent can produce a hybrid text+prosody signal.
            let prosody = NativeEmotionService.shared.extractProsodyFeatures(
                from: sttService.lastRecognitionMetadata,
                voiceAnalytics: sttService.lastVoiceAnalytics
            )

            isStopping = false
            micState = .idle
            if !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                onComplete(combined, prosody)
            }
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
        JournalCaptureScreen { transcript, prosody in
            print("Completed with transcript: \(transcript), prosody: \(prosody)")
        }
    }
}
