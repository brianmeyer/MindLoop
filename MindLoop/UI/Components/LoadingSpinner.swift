//
//  LoadingSpinner.swift
//  MindLoop
//
//  Animated thinking/loading indicator for model inference.
//

import SwiftUI

struct LoadingSpinner: View {
    let message: String

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: Spacing.m) {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color("Primary"), lineWidth: 3)
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                .onAppear { isAnimating = true }

            Text(message)
                .font(Typography.caption.font)
                .foregroundStyle(Color("MutedForeground"))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}
