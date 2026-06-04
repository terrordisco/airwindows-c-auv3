//
//  HeaderStripView.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Top strip inside EffectDetailView. The only navigation surface
//  besides the browser — tap the title pill to open BrowserView, jog
//  buttons step through siblings in the current category.
//

import SwiftUI

/// Persistent header for the effect detail surface.
///
/// Layout (with equal flexible spacers so jog buttons sit mid-gap between
/// their neighbor pot and the title block):
/// ```
/// [IN]  <sp>  [←prev]  <sp>  TITLE  <sp>  [next→]  <sp>  [OUT]
/// ```
///
/// Tap the effect name to open the browser — there is no separate sidebar
/// button.
public struct HeaderStripView: View {
    @Binding private var inputLevel: Double
    @Binding private var outputLevel: Double

    private let category: String
    private let effectName: String
    private let previousName: String?
    private let nextName: String?
    private let inputDisplay: String
    private let outputDisplay: String
    private let onPrevious: () -> Void
    private let onNext: () -> Void
    private let onTitleTap: () -> Void
    private let isFavorite: Bool
    private let onToggleFavorite: (() -> Void)?

    public init(
        category: String,
        effectName: String,
        previousName: String?,
        nextName: String?,
        inputLevel: Binding<Double>,
        outputLevel: Binding<Double>,
        inputDisplay: String,
        outputDisplay: String,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onTitleTap: @escaping () -> Void,
        isFavorite: Bool = false,
        onToggleFavorite: (() -> Void)? = nil
    ) {
        self.category = category
        self.effectName = effectName
        self.previousName = previousName
        self.nextName = nextName
        self._inputLevel = inputLevel
        self._outputLevel = outputLevel
        self.inputDisplay = inputDisplay
        self.outputDisplay = outputDisplay
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onTitleTap = onTitleTap
        self.isFavorite = isFavorite
        self.onToggleFavorite = onToggleFavorite
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left cluster: IN pot. Range extends to 2.0 (≈ +6 dB) so users
            // can boost a quiet effect, with default at 1.0 (unity / 0 dB)
            // sitting at the midpoint of the arc. The pot's velocity-aware
            // detent at 1.0 makes unity easy to land on without preventing
            // fine adjustments around it.
            RotaryPot(
                value: $inputLevel,
                label: "In",
                valueText: inputDisplay,
                size: 48,
                defaultValue: 1.0,
                range: 0...2
            )

            Spacer(minLength: 12)

            // Prev jog — mid-gap between IN pot and title
            JogButton(
                text: previousName.map { "← \($0)" } ?? "",
                enabled: previousName != nil,
                action: onPrevious
            )

            Spacer(minLength: 12)

            // Center: stroked rounded box containing category (kicker) +
            // effect name + chevron. Folding the category into the title box
            // reclaims a vertical strip that the previous stacked layout used.
            // The 7pt corner radius is intentionally smaller than the chip
            // capsules — it reads as a structural container, not a button.
            // Wrapped in a Button for proper hit area, haptic feedback, and
            // VoiceOver semantics ("button: opens browser").
            Button(action: onTitleTap) {
                HStack(spacing: 12) {
                    Text(category.uppercased())
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(1.2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(effectName)
                        .font(.system(size: 34, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category), \(effectName), tap to browse effects")
            .fixedSize(horizontal: true, vertical: false)

            // Favorite star — sits immediately right of the name box. Filled
            // yellow when favorited (the platform convention users read at a
            // glance), hollow secondary otherwise. Only present when the caller
            // wires a toggle.
            if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .accessibilityLabel(isFavorite ? "Remove \(effectName) from favorites" : "Add \(effectName) to favorites")
            }

            Spacer(minLength: 12)

            // Next jog — mid-gap between title and OUT pot
            JogButton(
                text: nextName.map { "\($0) →" } ?? "",
                enabled: nextName != nil,
                action: onNext
            )

            Spacer(minLength: 12)

            // Right: OUT pot. Same 0...2 range / unity-default / detent
            // arrangement as the IN pot — see comment above.
            RotaryPot(
                value: $outputLevel,
                label: "Out",
                valueText: outputDisplay,
                size: 48,
                defaultValue: 1.0,
                range: 0...2
            )
        }
        .padding(.horizontal, 20)
        // Modest top padding — the tagline sits above this strip in
        // EffectDetailView and already clears the host's top-left window
        // controls. We still leave a bit of space so the IN pot doesn't
        // butt up against the tagline when one is present, and isn't
        // crowded by host chrome when the tagline is absent.
        .padding(.top, 14)
        .padding(.bottom, 14)
    }
}

private struct JogButton: View {
    let text: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 17))
                .foregroundStyle(enabled ? Color.secondary : Color.secondary.opacity(0.3))
                .lineLimit(1)
                .frame(minWidth: 80, idealWidth: 110, maxWidth: 140, alignment: .center)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityHidden(!enabled)
    }
}

// MARK: - Preview

#Preview("Header strip") {
    HeaderStripPreview()
        .padding(40)
        .background(Color(white: 0.95))
}

private struct HeaderStripPreview: View {
    @State private var inLevel: Double = 0.75
    @State private var outLevel: Double = 0.75

    var body: some View {
        VStack(spacing: 16) {
            HeaderStripView(
                category: "Filter",
                effectName: "Highpass",
                previousName: "Bassdrive",
                nextName: "Lowpass",
                inputLevel: $inLevel,
                outputLevel: $outLevel,
                inputDisplay: "−3.0 dB",
                outputDisplay: "0.0 dB",
                onPrevious: {},
                onNext: {},
                onTitleTap: {}
            )
            .background(Color.white)

            HeaderStripView(
                category: "Reverb",
                effectName: "Galactic3",
                previousName: nil,
                nextName: "Infinity",
                inputLevel: $inLevel,
                outputLevel: $outLevel,
                inputDisplay: "−3.0 dB",
                outputDisplay: "0.0 dB",
                onPrevious: {},
                onNext: {},
                onTitleTap: {}
            )
            .background(Color.white)
        }
        .frame(width: 900)
    }
}
