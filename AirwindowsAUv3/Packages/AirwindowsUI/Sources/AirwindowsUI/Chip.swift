//
//  Chip.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The chip: a small, NON-INTERACTIVE marker — STEREO PROCESS, a year, a
//  filter's name. It never presses. Anything that runs a function is an
//  `ActionButton` (see ActionButton.swift); the two primitives are separate
//  on purpose, with independent metrics, so one can be tuned without moving
//  the other (Sveinbjörn, 2026-09-30).
//
//  Rules:
//    1. Corners are ALWAYS a fixed-radius rounded rectangle (never a capsule),
//       at one radius across every size.
//    2. Labels are ALL CAPS, applied here so no call site has to remember.
//    3. Faint outline, secondary ink — a chip is information, not a control.
//
//  All tokens are multiplied by `\.uiScale` so chips scale with the rest of
//  the UI.
//

import SwiftUI

public enum ChipSize {
    case small      // tightest marker — STEREO PROCESS between the IN/OUT pots
    case regular    // default
    case large      // headline-adjacent markers
}

public struct Chip: View {
    private let systemName: String?
    private let text: String?
    private let size: ChipSize
    private let accessibility: String?

    @Environment(\.uiScale) private var uiScale

    public init(
        systemName: String? = nil,
        text: String? = nil,
        size: ChipSize = .regular,
        accessibility: String? = nil
    ) {
        self.systemName = systemName
        self.text = text
        self.size = size
        self.accessibility = accessibility
    }

    public var body: some View {
        HStack(spacing: 6 * uiScale) {
            if let systemName {
                Image(systemName: systemName)
                    .font(.system(size: metrics.iconSize * uiScale, weight: metrics.weight))
            }
            if let text {
                Text(text.uppercased())
                    .font(.system(size: metrics.fontSize * uiScale, weight: metrics.weight))
                    .kerning(metrics.kerning)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, metrics.padH * uiScale)
        .padding(.vertical, metrics.padV * uiScale)
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius * uiScale, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        )
        .accessibilityLabel(accessibility ?? text ?? "")
    }

    // MARK: Tokens

    /// One radius for every chip, every size.
    private static let cornerRadius: CGFloat = 8

    private var metrics: ChipMetrics {
        switch size {
        // 2026-09-30: all three sizes cut ~30% (Sveinbjörn) — the ALL CAPS
        // setting reads larger than mixed case at the same point size.
        case .small:   return ChipMetrics(fontSize: 9, iconSize: 9, weight: .semibold, padH: 6, padV: 3, kerning: 0.5)
        case .regular: return ChipMetrics(fontSize: 9, iconSize: 11, weight: .medium, padH: 7, padV: 4, kerning: 0.5)
        case .large:   return ChipMetrics(fontSize: 11, iconSize: 12, weight: .semibold, padH: 14, padV: 7, kerning: 0.6)
        }
    }
}

struct ChipMetrics {
    let fontSize: CGFloat
    let iconSize: CGFloat
    let weight: Font.Weight
    let padH: CGFloat
    let padV: CGFloat
    let kerning: CGFloat
}

// MARK: - Preview

#Preview("Chips") {
    VStack(alignment: .leading, spacing: 12) {
        Chip(text: "Stereo process", size: .small)
        Chip(text: "2022")
        Chip(systemName: "waveform", text: "Reverb", size: .large)
    }
    .padding(24)
}
