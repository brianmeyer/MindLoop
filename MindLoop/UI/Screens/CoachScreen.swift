//
//  CoachScreen.swift
//  MindLoop
//
//  Conversation view displaying streamed coach responses with
//  typewriter animation, CBT state badge, emotion badge,
//  de-escalation messaging, suggested actions, and feedback controls.
//

import SwiftUI

struct CoachScreen: View {
    let orchestrator: Orchestrator
    let onDismiss: () -> Void

    // MARK: - Local State

    /// How many characters of streamingText to reveal (typewriter effect).
    @State private var revealedCount: Int = 0
    /// Timer driving the character-by-character reveal.
    @State private var typewriterTimer: Timer?
    /// Last observed length so we can detect newly appended tokens.
    @State private var lastStreamLength: Int = 0
    /// Whether the user has submitted feedback for this response.
    @State private var feedbackSubmitted: Bool = false

    /// Seconds between each character reveal.
    private let typewriterInterval: TimeInterval = 0.02

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // CBT + Emotion badges
                    badgesRow
                        .padding(.top, Spacing.l)

                    // De-escalation banner
                    if orchestrator.isBlocked,
                       let message = orchestrator.deescalationMessage {
                        deescalationBanner(message)
                    }

                    // Thinking indicator
                    if orchestrator.pipelineState == .thinking
                        || orchestrator.pipelineState == .analyzing {
                        thinkingIndicator
                    }

                    // Streamed / completed response
                    if !orchestrator.streamingText.isEmpty, !orchestrator.isBlocked {
                        responseCard
                    }

                    // Suggested action
                    if let action = orchestrator.currentResponse?.suggestedAction,
                       !action.isEmpty,
                       !orchestrator.isBlocked {
                        suggestedActionCard(action)
                    }

                    // Error message
                    if let error = orchestrator.errorMessage {
                        Text(error)
                            .typography(.small)
                            .foregroundStyle(Color("Destructive"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Error: \(error)")
                    }

                    // Feedback buttons (after response is fully delivered)
                    if orchestrator.pipelineState == .idle,
                       orchestrator.currentResponse != nil,
                       !orchestrator.isBlocked {
                        feedbackSection
                    }

                    // Done button
                    if orchestrator.pipelineState == .idle
                        || orchestrator.pipelineState == .blocked {
                        doneButton
                    }

                    Spacer()
                        .frame(minHeight: Spacing.xxl)
                }
                .padding(.horizontal, Spacing.l)
                .frame(maxWidth: Dimensions.mobileMaxWidth)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
        .navigationBarBackButtonHidden(true)
        .onChange(of: orchestrator.streamingText) { _, newValue in
            handleStreamingTextChange(newValue)
        }
        .onChange(of: orchestrator.currentResponse?.id) { _, _ in
            feedbackSubmitted = false
        }
        .onDisappear {
            stopTypewriter()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20))
                    .foregroundStyle(Color("Foreground"))
                    .frame(width: Dimensions.iconButton, height: Dimensions.iconButton)
                    .background(Color("Muted"))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Go back")

            Spacer()

            Text("Coach")
                .typography(.subheading)
                .foregroundStyle(Color("Foreground"))
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // Balance the leading button
            Color.clear
                .frame(width: Dimensions.iconButton)
                .accessibilityHidden(true)
        }
        .padding(Spacing.l)
        .overlay(alignment: .bottom) {
            Divider()
                .background(Color("Border"))
        }
    }

    // MARK: - Badges

    private var badgesRow: some View {
        HStack(spacing: Spacing.s) {
            cbtBadge

            if let emotion = orchestrator.currentEmotion {
                emotionBadge(emotion)
            }

            Spacer()
        }
    }

    private var cbtBadge: some View {
        Text(orchestrator.cbtState.displayName)
            .typography(.caption)
            .fontWeight(.medium)
            .foregroundStyle(Color("PrimaryForeground"))
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(Color("Primary"))
            .cornerRadius(CornerRadius.pill)
            .accessibilityLabel("CBT stage: \(orchestrator.cbtState.displayName)")
    }

    private func emotionBadge(_ emotion: EmotionSignal) -> some View {
        Text(emotion.label.displayName)
            .typography(.caption)
            .fontWeight(.medium)
            .foregroundStyle(Color(emotion.label.colorName))
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(Color(emotion.label.colorName).opacity(0.15))
            .cornerRadius(CornerRadius.pill)
            .accessibilityLabel(
                "Detected emotion: \(emotion.label.displayName), "
                + "\(emotion.confidencePercentage) percent confidence"
            )
    }

    // MARK: - Thinking Indicator

    private var thinkingIndicator: some View {
        HStack(spacing: Spacing.s) {
            ProgressView()
                .tint(Color("Primary"))

            Text("Thinking...")
                .typography(.body)
                .foregroundStyle(Color("MutedForeground"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.base)
        .background(Color("Muted"))
        .cornerRadius(CornerRadius.l)
        .accessibilityLabel("Coach is thinking")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Response Card (typewriter)

    private var responseCard: some View {
        Text(typewriterText)
            .typography(.body)
            .foregroundStyle(Color("Foreground"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.base)
            .background(Color("Muted"))
            .cornerRadius(CornerRadius.l)
            .accessibilityLabel("Coach response: \(orchestrator.streamingText)")
            .accessibilityAddTraits(.updatesFrequently)
    }

    /// Substring of streamingText up to `revealedCount` characters.
    private var typewriterText: String {
        let source = orchestrator.streamingText
        guard revealedCount < source.count else { return source }
        let endIndex = source.index(
            source.startIndex,
            offsetBy: revealedCount
        )
        return String(source[source.startIndex..<endIndex])
    }

    // MARK: - Suggested Action Card

    private func suggestedActionCard(_ action: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundStyle(Color("Primary"))

                Text("Suggested Action")
                    .typography(.small)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Primary"))
            }

            Text(action)
                .typography(.body)
                .foregroundStyle(Color("Foreground"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.base)
        .background(Color("Primary").opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.l)
                .stroke(Color("Primary").opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(CornerRadius.l)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Suggested action: \(action)")
    }

    // MARK: - De-escalation Banner

    private func deescalationBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color("Destructive"))

                Text("We care about you")
                    .typography(.small)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Destructive"))
            }

            Text(message)
                .typography(.body)
                .foregroundStyle(Color("Foreground"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.base)
        .background(Color("Destructive").opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.l)
                .stroke(Color("Destructive").opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(CornerRadius.l)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Safety message: \(message)")
    }

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        VStack(spacing: Spacing.s) {
            if feedbackSubmitted {
                Text("Thanks for your feedback")
                    .typography(.small)
                    .foregroundStyle(Color("MutedForeground"))
                    .accessibilityLabel("Feedback submitted, thank you")
            } else {
                Text("Was this helpful?")
                    .typography(.small)
                    .foregroundStyle(Color("MutedForeground"))
                    .accessibilityAddTraits(.isHeader)

                HStack(spacing: Spacing.base) {
                    feedbackButton(
                        icon: "hand.thumbsup",
                        label: "Helpful",
                        accessibilityHint: "Rate this response as helpful",
                        feedback: .thumbsUp
                    )

                    feedbackButton(
                        icon: "hand.thumbsdown",
                        label: "Not helpful",
                        accessibilityHint: "Rate this response as not helpful",
                        feedback: .thumbsDown
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s)
    }

    private func feedbackButton(
        icon: String,
        label: String,
        accessibilityHint: String,
        feedback: Feedback
    ) -> some View {
        Button {
            feedbackSubmitted = true
            Task {
                await orchestrator.recordFeedback(feedback)
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .typography(.small)
                    .fontWeight(.medium)
            }
            .foregroundStyle(Color("Foreground"))
            .padding(.horizontal, Spacing.base)
            .padding(.vertical, Spacing.s)
            .background(Color("Muted"))
            .cornerRadius(CornerRadius.extraLarge)
        }
        .accessibilityLabel(label)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button(action: onDismiss) {
            Text("Done")
                .typography(.body)
                .fontWeight(.medium)
                .foregroundColor(Color("PrimaryForeground"))
                .frame(maxWidth: .infinity)
                .frame(minHeight: Dimensions.primaryButtonHeight)
                .background(Color("Primary"))
                .cornerRadius(CornerRadius.extraLarge)
        }
        .accessibilityLabel("Done")
        .accessibilityHint("Return to the home screen")
    }

    // MARK: - Typewriter Logic

    private func handleStreamingTextChange(_ newText: String) {
        let newLength = newText.count

        // Text was cleared — new response cycle
        if newLength == 0 {
            revealedCount = 0
            lastStreamLength = 0
            stopTypewriter()
            return
        }

        // New tokens arrived — restart reveal timer if needed
        if newLength > lastStreamLength {
            lastStreamLength = newLength
            startTypewriterIfNeeded()
        }
    }

    private func startTypewriterIfNeeded() {
        guard typewriterTimer == nil else { return }

        typewriterTimer = Timer.scheduledTimer(
            withTimeInterval: typewriterInterval,
            repeats: true
        ) { _ in
            Task { @MainActor in
                let target = orchestrator.streamingText.count
                if revealedCount < target {
                    revealedCount += 1
                } else {
                    stopTypewriter()
                }
            }
        }
    }

    private func stopTypewriter() {
        typewriterTimer?.invalidate()
        typewriterTimer = nil
    }
}

// MARK: - Preview

#Preview("Coach - Responding") {
    NavigationStack {
        CoachScreen(orchestrator: Orchestrator()) {
            print("Dismissed")
        }
    }
}
