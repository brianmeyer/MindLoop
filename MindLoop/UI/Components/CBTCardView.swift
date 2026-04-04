//
//  CBTCardView.swift
//  MindLoop
//
//  Card view for CBT techniques shown alongside coach responses.
//

import SwiftUI

struct CBTCardView: View {
    let card: CBTCard

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Color("Accent"))

                    Text(card.title)
                        .font(Typography.body.font)
                        .foregroundStyle(Color("Foreground"))
                        .fontWeight(.semibold)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color("MutedForeground"))
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(card.technique)
                        .font(Typography.body.font)
                        .foregroundStyle(Color("Foreground"))

                    Text("Example: \(card.example)")
                        .font(Typography.caption.font)
                        .foregroundStyle(Color("MutedForeground"))
                        .italic()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.m)
        .background(Color("Card"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("CBT technique: \(card.title)")
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand and read technique")
    }
}
