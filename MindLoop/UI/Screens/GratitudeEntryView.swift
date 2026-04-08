//
//  GratitudeEntryView.swift
//  MindLoop
//
//  Quick gratitude capture view presented as a sheet.
//  Creates a JournalEntry tagged with "gratitude" on save.
//  Ticket: REC-278
//

import SwiftUI

struct GratitudeEntryView: View {
    // MARK: - Properties

    let onSave: (JournalEntry) -> Void
    let onDismiss: () -> Void

    // MARK: - State

    @State private var gratitudeText = ""
    @State private var isSaving = false
    @State private var showConfirmation = false
    @FocusState private var isTextFieldFocused: Bool

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                Spacer()
                    .frame(height: Spacing.base)

                // Heart icon
                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color("Primary"))
                    .accessibilityHidden(true)

                // Prompt text
                Text("Take a moment to reflect")
                    .typography(.subheading)
                    .foregroundColor(Color("Foreground"))
                    .multilineTextAlignment(.center)

                // Text input
                TextField(
                    "What are you grateful for?",
                    text: $gratitudeText,
                    axis: .vertical
                )
                .typography(.body)
                .lineLimit(3...6)
                .padding(Spacing.base)
                .background(Color("Muted"))
                .cornerRadius(CornerRadius.large)
                .focused($isTextFieldFocused)
                .accessibilityLabel("Gratitude entry")
                .accessibilityHint("Enter what you are grateful for")

                // Save button
                Button(action: saveGratitude) {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(Color("PrimaryForeground"))
                        } else {
                            Text("Save gratitude")
                                .typography(.body)
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundColor(Color("PrimaryForeground"))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Dimensions.primaryButtonHeight)
                    .background(
                        gratitudeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color("Muted")
                            : Color("Primary")
                    )
                    .cornerRadius(CornerRadius.extraLarge)
                }
                .disabled(
                    gratitudeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || isSaving
                )
                .accessibilityLabel("Save gratitude entry")

                Spacer()
            }
            .padding(.horizontal, Spacing.l)
            .frame(maxWidth: Dimensions.mobileMaxWidth)
            .frame(maxWidth: .infinity)
            .background(Color("Background"))
            .navigationTitle("Gratitude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                        .foregroundColor(Color("MutedForeground"))
                }
            }
            .overlay {
                if showConfirmation {
                    confirmationOverlay
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showConfirmation)
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color("Primary"))

            Text("Gratitude saved")
                .typography(.emphasized)
                .foregroundColor(Color("Foreground"))
        }
        .padding(Spacing.xxl)
        .background(Color("Card"))
        .cornerRadius(CornerRadius.extraLarge)
        .shadow(color: Color("Foreground").opacity(0.1), radius: 10, y: 4)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel("Gratitude saved successfully")
    }

    // MARK: - Actions

    private func saveGratitude() {
        let trimmed = gratitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true

        let entry = JournalEntry(
            text: trimmed,
            emotion: EmotionSignal.fromTextSentiment(
                label: .positive,
                confidence: 0.7,
                valence: 0.6
            ),
            tags: ["gratitude"]
        )

        onSave(entry)

        showConfirmation = true

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1200))
            onDismiss()
        }
    }
}

// MARK: - Preview

#Preview("Gratitude Entry") {
    GratitudeEntryView(
        onSave: { entry in print("Saved: \(entry.text)") },
        onDismiss: { print("Dismissed") }
    )
}
