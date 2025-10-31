//
//  HomeScreen.swift
//  MindLoop
//
//  Main home screen with journaling CTAs
//  Converted from: temp-figma-code/src/components/screens/HomeScreen.tsx
//

import SwiftUI

struct HomeScreen: View {
    // MARK: - Properties

    let onStartCheckin: () -> Void
    let onQuickGratitude: () -> Void
    let onSettings: () -> Void
    let onViewHistory: (() -> Void)?

    // MARK: - State

    @State private var greeting: String = "Good evening, Alex"
    @State private var streak: Int = 7
    @State private var moodValue: Double = 0.5

    // Button press states for scale animations
    @State private var isHistoryPressed = false
    @State private var isSettingsPressed = false
    @State private var isGratitudePressed = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Main Content
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    Spacer()
                        .frame(minHeight: 40)

                    VStack(spacing: Spacing.xl) {
                        // Primary CTA
                        primaryCTA

                        // Secondary CTA
                        secondaryCTA

                        // Quick Mood Slider
                        moodSlider

                        // Gratitude Quick Add
                        gratitudeButton
                    }
                    .frame(maxWidth: Dimensions.mobileMaxWidth)
                    .padding(.horizontal, Spacing.l)

                    Spacer()
                        .frame(minHeight: 40)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.base) {
            // Greeting & Streak
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(greeting)
                    .typography(.body)
                    .foregroundColor(Color("Foreground"))

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.984, green: 0.749, blue: 0.141)) // #fbbf24

                    Text("\(streak) day streak")
                        .typography(.small)
                        .foregroundColor(Color("MutedForeground"))
                }
            }

            Spacer()

            // Action Buttons
            HStack(spacing: Spacing.s) {
                if let onViewHistory = onViewHistory {
                    CircularIconButton(
                        icon: "book",
                        accessibilityLabel: "View journal history",
                        isPressed: $isHistoryPressed,
                        action: onViewHistory
                    )
                }

                CircularIconButton(
                    icon: "gearshape",
                    accessibilityLabel: "Settings",
                    isPressed: $isSettingsPressed,
                    action: onSettings
                )
            }
        }
        .padding(Spacing.l)
        .overlay(alignment: .bottom) {
            Divider()
                .background(Color("Border"))
        }
    }

    // MARK: - Primary CTA

    private var primaryCTA: some View {
        VStack(spacing: Spacing.base) {
            Text("Ready for a short check-in?")
                .typography(.body)
                .foregroundColor(Color("MutedForeground"))

            Button(action: onStartCheckin) {
                Text("Start journal")
                    .typography(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color("PrimaryForeground"))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Dimensions.primaryButtonHeight)
                    .background(Color("Primary"))
                    .cornerRadius(CornerRadius.extraLarge)
            }
        }
    }

    // MARK: - Secondary CTA

    private var secondaryCTA: some View {
        Button(action: onStartCheckin) {
            Text("Quick feeling dump")
                .typography(.body)
                .fontWeight(.medium)
                .foregroundColor(Color("Foreground"))
                .frame(maxWidth: .infinity)
                .frame(minHeight: Dimensions.primaryButtonHeight)
                .background(Color("Background"))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.extraLarge)
                        .stroke(Color("Border"), lineWidth: 1)
                )
                .cornerRadius(CornerRadius.extraLarge)
        }
    }

    // MARK: - Mood Slider

    private var moodSlider: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("How are you feeling?")
                .typography(.small)
                .foregroundColor(Color("MutedForeground"))

            // Simple slider placeholder (will create proper MoodSlider component later)
            Slider(value: $moodValue, in: 0...1)
                .tint(Color("Primary"))
        }
        .padding(Spacing.base)
        .background(Color("Muted"))
        .cornerRadius(CornerRadius.extraLarge)
    }

    // MARK: - Gratitude Button

    private var gratitudeButton: some View {
        Button(action: onQuickGratitude) {
            HStack(spacing: Spacing.s) {
                Image(systemName: "heart")
                    .font(.system(size: 20))

                Text("Add gratitude")
                    .typography(.body)
            }
            .foregroundColor(Color("MutedForeground"))
            .frame(maxWidth: .infinity)
            .frame(minHeight: Dimensions.primaryButtonHeight)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.extraLarge)
                    .strokeBorder(
                        Color("Border"),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
            )
        }
        .scaleEffect(isGratitudePressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isGratitudePressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isGratitudePressed = true }
                .onEnded { _ in isGratitudePressed = false }
        )
    }
}

// MARK: - Circular Icon Button Component

struct CircularIconButton: View {
    let icon: String
    let accessibilityLabel: String
    @Binding var isPressed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color("Foreground"))
                .frame(width: Dimensions.iconButton, height: Dimensions.iconButton)
                .background(Color("Muted"))
                .clipShape(Circle())
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Preview

#Preview("Home Screen") {
    HomeScreen(
        onStartCheckin: { print("Start check-in") },
        onQuickGratitude: { print("Add gratitude") },
        onSettings: { print("Open settings") },
        onViewHistory: { print("View history") }
    )
}

#Preview("Home Screen - Dark Mode") {
    HomeScreen(
        onStartCheckin: { print("Start check-in") },
        onQuickGratitude: { print("Add gratitude") },
        onSettings: { print("Open settings") },
        onViewHistory: { print("View history") }
    )
    .preferredColorScheme(.dark)
}
