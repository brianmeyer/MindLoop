//
//  FeedbackButtons.swift
//  MindLoop
//
//  Thumbs up/down feedback for LearningLoopAgent input.
//

import SwiftUI

struct FeedbackButtons: View {
    let onFeedback: (Feedback) -> Void

    @State private var selected: Feedback?

    var body: some View {
        HStack(spacing: Spacing.l) {
            Button {
                selected = .thumbsUp
                onFeedback(.thumbsUp)
            } label: {
                Image(systemName: selected == .thumbsUp ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 24))
                    .foregroundStyle(selected == .thumbsUp ? Color("Primary") : Color("MutedForeground"))
            }
            .accessibilityLabel("Thumbs up — helpful response")
            .accessibilityHint("Rate this coach response as helpful")

            Button {
                selected = .thumbsDown
                onFeedback(.thumbsDown)
            } label: {
                Image(systemName: selected == .thumbsDown ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 24))
                    .foregroundStyle(selected == .thumbsDown ? Color("Destructive") : Color("MutedForeground"))
            }
            .accessibilityLabel("Thumbs down — not helpful")
            .accessibilityHint("Rate this coach response as not helpful")
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}
