//
//  EmotionBadge.swift
//  MindLoop
//
//  Displays emotion signal as a colored badge with label + confidence.
//

import SwiftUI

struct EmotionBadge: View {
    let emotion: EmotionSignal

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(Color(emotion.label.colorName))
                .frame(width: 8, height: 8)

            Text(emotion.label.displayName)
                .font(Typography.caption.font)
                .foregroundStyle(Color("Foreground"))

            Text("\(Int(emotion.confidence * 100))%")
                .font(Typography.caption.font)
                .foregroundStyle(Color("MutedForeground"))
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.xs)
        .background(Color("Muted").opacity(0.3))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Emotion: \(emotion.label.displayName), \(Int(emotion.confidence * 100)) percent confidence")
    }
}
