//
//  TimelineScreen.swift
//  MindLoop
//
//  Scrollable timeline of past journal entries grouped by date.
//  Entries are sorted newest-first with tap-to-expand for full text
//  and coach response details.
//

import SwiftUI
import GRDB

// MARK: - TimelineScreen

struct TimelineScreen: View {
    let database: AppDatabase
    let onDismiss: () -> Void

    // MARK: - State

    @State private var entries: [JournalEntry] = []
    @State private var expandedEntryID: String?
    @State private var isLoading = true

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            if isLoading {
                loadingState
            } else if entries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background"))
        .navigationBarBackButtonHidden(true)
        .task {
            await loadEntries()
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

            Text("Journal History")
                .typography(.subheading)
                .foregroundStyle(Color("Foreground"))

            Spacer()

            // Balance the leading button
            Color.clear
                .frame(width: Dimensions.iconButton)
        }
        .padding(Spacing.l)
        .overlay(alignment: .bottom) {
            Divider()
                .background(Color("Border"))
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(Color("Primary"))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Loading journal entries")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.base) {
            Spacer()

            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(Color("MutedForeground"))
                .accessibilityHidden(true)

            Text("No journal entries yet.\nStart your first reflection!")
                .typography(.body)
                .foregroundStyle(Color("MutedForeground"))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Spacing.l)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No journal entries yet. Start your first reflection!")
    }

    // MARK: - Entry List

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedEntries, id: \.key) { dateLabel, sectionEntries in
                    Section {
                        ForEach(sectionEntries) { entry in
                            entryRow(entry)
                                .padding(.horizontal, Spacing.l)
                                .padding(.bottom, Spacing.s)
                        }
                    } header: {
                        sectionHeader(dateLabel)
                    }
                }
            }
            .padding(.top, Spacing.s)
            .padding(.bottom, Spacing.xxl)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ label: String) -> some View {
        HStack {
            Text(label)
                .typography(.small)
                .fontWeight(.semibold)
                .foregroundStyle(Color("MutedForeground"))

            Spacer()
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(Color("Background"))
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Entry Row

    private func entryRow(_ entry: JournalEntry) -> some View {
        let isExpanded = expandedEntryID == entry.id

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                expandedEntryID = isExpanded ? nil : entry.id
            }
        } label: {
            VStack(alignment: .leading, spacing: Spacing.s) {
                // Top row: time + emotion badge
                HStack(alignment: .center, spacing: Spacing.s) {
                    Text(entry.formattedTime)
                        .typography(.small)
                        .foregroundStyle(Color("MutedForeground"))

                    EmotionBadge(emotion: entry.emotion)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundStyle(Color("MutedForeground"))
                        .accessibilityHidden(true)
                }

                // Text preview or full text
                Text(isExpanded ? entry.text : truncatedPreview(entry.text))
                    .typography(.body)
                    .foregroundStyle(Color("Foreground"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(isExpanded ? nil : 3)

                // Tags (always visible if present)
                if !entry.tags.isEmpty {
                    tagsRow(entry.tags)
                }
            }
            .padding(Spacing.base)
            .background(Color("Muted"))
            .cornerRadius(CornerRadius.l)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entryAccessibilityLabel(entry))
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand full entry")
    }

    // MARK: - Tags Row

    private func tagsRow(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .typography(.caption)
                        .foregroundStyle(Color("MutedForeground"))
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xs)
                        .background(Color("Background"))
                        .cornerRadius(CornerRadius.small)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tags: \(tags.joined(separator: ", "))")
    }

    // MARK: - Helpers

    /// Truncate text to approximately 50 words
    private func truncatedPreview(_ text: String) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        if words.count <= 50 {
            return text
        }
        return words.prefix(50).joined(separator: " ") + "..."
    }

    /// Group entries by date label (Today, Yesterday, or formatted date)
    private var groupedEntries: [(key: String, value: [JournalEntry])] {
        let calendar = Calendar.current

        var groups: [String: [JournalEntry]] = [:]
        var order: [String] = []

        for entry in entries {
            let label: String
            if calendar.isDateInToday(entry.timestamp) {
                label = "Today"
            } else if calendar.isDateInYesterday(entry.timestamp) {
                label = "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                label = formatter.string(from: entry.timestamp)
            }

            if groups[label] == nil {
                order.append(label)
            }
            groups[label, default: []].append(entry)
        }

        return order.map { (key: $0, value: groups[$0]!) }
    }

    private func entryAccessibilityLabel(_ entry: JournalEntry) -> String {
        let preview = truncatedPreview(entry.text)
        return "\(entry.formattedDate) at \(entry.formattedTime), "
            + "feeling \(entry.emotion.label.displayName), "
            + "\(preview)"
    }

    // MARK: - Data Loading

    private func loadEntries() async {
        do {
            let records = try database.fetchAllEntries()
            entries = records.map { $0.toDomain() }
        } catch {
            entries = []
        }
        isLoading = false
    }
}

// MARK: - Preview

#Preview("Timeline - With Entries") {
    NavigationStack {
        TimelineScreen(
            database: .shared,
            onDismiss: { print("Dismiss") }
        )
    }
}

#Preview("Timeline - Empty") {
    NavigationStack {
        TimelineScreen(
            database: {
                // Use in-memory DB for empty state preview
                (try? AppDatabase.makeEmpty()) ?? .shared
            }(),
            onDismiss: { print("Dismiss") }
        )
    }
}
