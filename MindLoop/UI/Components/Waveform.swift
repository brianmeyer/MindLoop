//
//  Waveform.swift
//  MindLoop
//
//  Animated waveform visualization for audio recording
//  Reacts to real-time audio input levels
//

import SwiftUI

/// Animated waveform display that responds to audio input
struct Waveform: View {
    let isActive: Bool
    let audioLevel: Float // 0.0 to 1.0 from AudioRecorder

    private let barCount = 40

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    isActive: isActive,
                    audioLevel: audioLevel,
                    index: index
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .padding(Spacing.m)
        .background(Color("Muted"))
        .cornerRadius(CornerRadius.m)
    }
}

/// Individual bar that reacts to audio amplitude
struct WaveformBar: View {
    let isActive: Bool
    let audioLevel: Float
    let index: Int

    @State private var randomOffset: CGFloat = 0

    private var targetHeight: CGFloat {
        guard isActive else { return 0.2 }

        // Base height from audio level
        let baseHeight = CGFloat(audioLevel)

        // Add randomized variation for natural look
        // Each bar gets a slightly different height based on audio + random offset
        let variation = randomOffset * 0.3
        let height = (baseHeight * 0.7) + variation + 0.2 // Min 0.2, max ~1.2

        return min(1.0, max(0.2, height))
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color(red: 0.48, green: 0.72, blue: 0.90)) // #7bb8e7
            .frame(minWidth: 2)
            .frame(maxHeight: .infinity)
            .scaleEffect(y: targetHeight, anchor: .center)
            .opacity(isActive ? 0.7 : 0.3)
            .animation(.easeOut(duration: 0.1), value: targetHeight)
            .onAppear {
                randomOffset = CGFloat.random(in: 0...0.3)
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    randomOffset = CGFloat.random(in: 0...0.3)
                }
            }
            .onChange(of: audioLevel) { _, _ in
                // Slightly adjust random offset on each audio update for more natural movement
                if isActive {
                    withAnimation(.easeOut(duration: 0.2)) {
                        randomOffset = CGFloat.random(in: 0...0.3)
                    }
                }
            }
    }
}

// MARK: - Previews

#Preview("Inactive") {
    Waveform(isActive: false, audioLevel: 0.0)
        .padding()
}

#Preview("Active - Low Level") {
    Waveform(isActive: true, audioLevel: 0.3)
        .padding()
}

#Preview("Active - High Level") {
    Waveform(isActive: true, audioLevel: 0.8)
        .padding()
}
