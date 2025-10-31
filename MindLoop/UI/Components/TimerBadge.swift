//
//  TimerBadge.swift
//  MindLoop
//
//  Timer display badge for recording duration
//

import SwiftUI

/// Displays recording time in MM:SS format
struct TimerBadge: View {
    let seconds: Int

    private var formattedTime: String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "clock")
                .font(.system(size: 14))
                .foregroundStyle(Color("Text/TextSecondary"))

            Text(formattedTime)
                .typography(.small)
                .foregroundStyle(Color("Text/TextSecondary"))
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
        .background(Color("Muted"))
        .cornerRadius(CornerRadius.pill)
    }
}

// MARK: - Preview

#Preview("Idle") {
    TimerBadge(seconds: 0)
}

#Preview("Recording") {
    TimerBadge(seconds: 125) // 2:05
}
