//
//  OnboardingView.swift
//  MindLoop
//
//  5-screen onboarding flow for new users.
//  Presented as an overlay on ContentView, gated by hasCompletedOnboarding.
//

import SwiftUI
import Speech
import AVFoundation

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var userName = ""
    @State private var selectedGoals: Set<String> = []
    @State private var permissionState: PermissionState = .notRequested
    @State private var showPermissionDeniedNote = false

    private let totalPages = 5

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)

            // Paged content
            TabView(selection: $currentPage) {
                welcomeScreen.tag(0)
                privacyScreen.tag(1)
                nameScreen.tag(2)
                howItWorksScreen.tag(3)
                permissionsScreen.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentPage)
            .scrollDisabled(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index <= currentPage ? Color("Primary") : Color("Muted"))
                    .frame(height: 4)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Step \(currentPage + 1) of \(totalPages)")
    }

    // MARK: - Screen 1: Welcome

    private var welcomeScreen: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                Text("Your private AI journal coach")
                    .typography(.heading)
                    .foregroundColor(Color("Foreground"))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: Spacing.l) {
                    featureRow(
                        icon: "mic.fill",
                        text: "Voice journaling that listens and understands"
                    )
                    featureRow(
                        icon: "brain.head.profile",
                        text: "CBT-guided reflection to shift your thinking"
                    )
                    featureRow(
                        icon: "lock.shield.fill",
                        text: "100% on-device -- your words never leave your phone"
                    )
                }
            }
            .frame(maxWidth: Dimensions.mobileMaxWidth)
            .padding(.horizontal, Spacing.l)

            Spacer()

            primaryButton(title: "Get Started") {
                withAnimation { currentPage = 1 }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: - Screen 2: Privacy

    private var privacyScreen: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(.largeTitle))
                    .imageScale(.large)
                    .foregroundColor(Color("Primary"))
                    .accessibilityHidden(true)

                VStack(spacing: Spacing.base) {
                    Text("Your privacy is absolute")
                        .typography(.heading)
                        .foregroundColor(Color("Foreground"))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text("Everything stays on your device. No servers. No accounts. No data ever leaves your phone.")
                        .typography(.body)
                        .foregroundColor(Color("MutedForeground"))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: Dimensions.mobileMaxWidth)
            .padding(.horizontal, Spacing.l)

            Spacer()

            primaryButton(title: "Continue") {
                withAnimation { currentPage = 2 }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: - Screen 3: Name

    private var nameScreen: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                Text("What should we call you?")
                    .typography(.heading)
                    .foregroundColor(Color("Foreground"))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                TextField("Your name", text: $userName)
                    .typography(.body)
                    .foregroundColor(Color("Foreground"))
                    .padding(Spacing.base)
                    .background(Color("Muted"))
                    .cornerRadius(CornerRadius.medium)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Your name")

                // Goal chips
                VStack(spacing: Spacing.m) {
                    Text("What brings you here?")
                        .typography(.small)
                        .foregroundColor(Color("MutedForeground"))

                    FlowLayout(spacing: Spacing.s) {
                        goalChip("Manage stress")
                        goalChip("Build self-awareness")
                        goalChip("Process emotions")
                    }
                }
            }
            .frame(maxWidth: Dimensions.mobileMaxWidth)
            .padding(.horizontal, Spacing.l)

            Spacer()

            primaryButton(title: "Continue", isDisabled: userName.trimmingCharacters(in: .whitespaces).isEmpty) {
                saveUserName()
                withAnimation { currentPage = 3 }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: - Screen 4: How It Works

    private var howItWorksScreen: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                Text("How it works")
                    .typography(.heading)
                    .foregroundColor(Color("Foreground"))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                VStack(alignment: .leading, spacing: Spacing.l) {
                    stepRow(
                        icon: "mic.fill",
                        title: "Speak",
                        description: "Talk about what is on your mind"
                    )
                    stepRow(
                        icon: "waveform",
                        title: "AI listens",
                        description: "Your words are understood on-device"
                    )
                    stepRow(
                        icon: "lightbulb.fill",
                        title: "Guided reflection",
                        description: "CBT techniques help you reframe thoughts"
                    )
                    stepRow(
                        icon: "figure.walk",
                        title: "Tiny action",
                        description: "One small step to move forward"
                    )
                }
            }
            .frame(maxWidth: Dimensions.mobileMaxWidth)
            .padding(.horizontal, Spacing.l)

            Spacer()

            primaryButton(title: "Continue") {
                withAnimation { currentPage = 4 }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: - Screen 5: Permissions

    private var permissionsScreen: some View {
        VStack(spacing: Spacing.xxl) {
            Spacer()

            VStack(spacing: Spacing.xl) {
                Image(systemName: "mic.badge.plus")
                    .font(.system(.largeTitle))
                    .imageScale(.large)
                    .foregroundColor(Color("Primary"))
                    .accessibilityHidden(true)

                VStack(spacing: Spacing.base) {
                    Text("Enable voice journaling")
                        .typography(.heading)
                        .foregroundColor(Color("Foreground"))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text("MindLoop needs microphone and speech recognition access to transcribe your voice entries. Everything is processed on your device.")
                        .typography(.body)
                        .foregroundColor(Color("MutedForeground"))
                        .multilineTextAlignment(.center)
                }

                if showPermissionDeniedNote {
                    HStack(spacing: Spacing.s) {
                        Image(systemName: "info.circle")
                            .foregroundColor(Color("MutedForeground"))
                        Text("You can enable these later in Settings > MindLoop.")
                            .typography(.small)
                            .foregroundColor(Color("MutedForeground"))
                    }
                    .padding(Spacing.m)
                    .background(Color("Muted"))
                    .cornerRadius(CornerRadius.medium)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: Dimensions.mobileMaxWidth)
            .padding(.horizontal, Spacing.l)

            Spacer()

            VStack(spacing: Spacing.m) {
                primaryButton(title: "Enable Voice Journaling") {
                    requestPermissions()
                }

                if showPermissionDeniedNote {
                    Button {
                        completeOnboarding()
                    } label: {
                        Text("Continue without voice")
                            .typography(.body)
                            .foregroundColor(Color("MutedForeground"))
                    }
                    .accessibilityLabel("Continue without voice journaling")
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: - Reusable Components

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(.title2))
                .foregroundColor(Color("Primary"))
                .frame(width: 32)
                .accessibilityHidden(true)

            Text(text)
                .typography(.body)
                .foregroundColor(Color("Foreground"))
        }
        .accessibilityElement(children: .combine)
    }

    private func stepRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(.title2))
                .foregroundColor(Color("Primary"))
                .frame(width: 40, height: 40)
                .background(Color("Muted"))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .typography(.emphasized)
                    .foregroundColor(Color("Foreground"))

                Text(description)
                    .typography(.small)
                    .foregroundColor(Color("MutedForeground"))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func goalChip(_ title: String) -> some View {
        let isSelected = selectedGoals.contains(title)
        return Button {
            if isSelected {
                selectedGoals.remove(title)
            } else {
                selectedGoals.insert(title)
            }
        } label: {
            Text(title)
                .typography(.small)
                .foregroundColor(isSelected ? Color("PrimaryForeground") : Color("Foreground"))
                .padding(.horizontal, Spacing.base)
                .padding(.vertical, Spacing.s)
                .background(isSelected ? Color("Primary") : Color("Muted"))
                .cornerRadius(CornerRadius.pill)
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func primaryButton(title: String, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .typography(.body)
                .fontWeight(.medium)
                .foregroundColor(Color("PrimaryForeground"))
                .frame(maxWidth: .infinity)
                .frame(minHeight: Dimensions.primaryButtonHeight)
                .background(isDisabled ? Color("Muted") : Color("Primary"))
                .cornerRadius(CornerRadius.extraLarge)
        }
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }

    // MARK: - Actions

    private func saveUserName() {
        let trimmedName = userName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // Save to AppStorage for HomeScreen greeting
        UserDefaults.standard.set(trimmedName, forKey: "userName")

        // Also save to GRDB for PersonalizationProfile
        do {
            let db = AppDatabase.shared
            var profile = try db.fetchProfile()
            profile.userName = trimmedName
            try db.saveProfile(profile)
        } catch {
            // Non-fatal: AppStorage still has it
        }
    }

    private func requestPermissions() {
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { micGranted in
            // Request speech recognition permission
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    let speechGranted = status == .authorized
                    if micGranted && speechGranted {
                        completeOnboarding()
                    } else {
                        showPermissionDeniedNote = true
                    }
                }
            }
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.4)) {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Permission State

private enum PermissionState {
    case notRequested
    case granted
    case denied
}

// MARK: - FlowLayout

/// Simple horizontal wrapping layout for goal chips
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            let position = result.positions[index]
            subview.place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subview.sizeThatFits(.unspecified))
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX - spacing)
        }

        return (CGSize(width: maxX, height: currentY + rowHeight), positions)
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView()
}
