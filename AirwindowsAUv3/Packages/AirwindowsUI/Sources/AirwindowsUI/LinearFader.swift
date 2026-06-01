//
//  LinearFader.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Custom slider widget used by ParameterRow in "sliders" mode. Hand-
//  rolled because SwiftUI.Slider snaps the handle to the touch point,
//  which feels wrong for hardware-style fader interaction.
//

import SwiftUI

/// Horizontal fader with relative-drag semantics.
///
/// Replaces SwiftUI's `Slider` in places where a touch on the track must
/// **not** teleport the handle to the touch point. Instead the value moves by
/// the drag delta from where the finger first landed, matching the feel of
/// hardware mixing-console faders and the gesture model used by `RotaryPot`.
///
/// ```
/// ──◯─────────────────────   ← drag from anywhere; handle moves by Δx, not to x
/// ```
///
/// The whole row is touch-receptive (full-bleed `contentShape`), so a user can
/// grab any part of the track or surrounding strip — useful for thin tracks
/// where landing precisely on the handle is fiddly. Double-tap resets to
/// `defaultValue` when one is provided, mirroring the rotary-pot convention.
public struct LinearFader: View {
    @Binding private var value: Double
    private let range: ClosedRange<Double>
    private let defaultValue: Double?
    /// 0 = continuous fader. N≥2 = stepped/popup parameter with N discrete
    /// cases — the track shows N small dots equally spaced along it (one per
    /// case), the fader still moves freely during a drag, and on release the
    /// value snaps to the nearest case center.
    private let stepCount: Int

    @State private var dragStartValue: Double?

    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...1,
        defaultValue: Double? = nil,
        stepCount: Int = 0
    ) {
        self._value = value
        self.range = range
        self.defaultValue = defaultValue
        self.stepCount = stepCount
    }

    private let trackHeight: CGFloat = 4
    private let handleSize: CGFloat = 22
    private let stepDotSize: CGFloat = 4

    public var body: some View {
        GeometryReader { geo in
            // Reserve half a handle on each side so the handle doesn't clip
            // against the row edges. The "track" the value travels along is
            // therefore narrower than the geometry width.
            let trackWidth = max(geo.size.width - handleSize, 1)
            let normalized = clampedNormalized
            let handleX = handleSize / 2 + trackWidth * CGFloat(normalized)

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(height: trackHeight)

                // Step dots — one per case, centered on the bin midpoint.
                // For an N-step parameter the cast `(VstInt32)(A * (N-1).999)`
                // splits 0..1 into N bins; their centers sit at (k+0.5)/N
                // along the track.
                if stepCount >= 2 {
                    ForEach(0..<stepCount, id: \.self) { k in
                        let frac = (Double(k) + 0.5) / Double(stepCount)
                        Circle()
                            .fill(Color.secondary.opacity(0.55))
                            .frame(width: stepDotSize, height: stepDotSize)
                            .offset(
                                x: handleSize / 2 + trackWidth * CGFloat(frac) - stepDotSize / 2
                            )
                    }
                }

                // Filled portion from leading edge to handle position
                Capsule()
                    .fill(Color.primary)
                    .frame(width: handleX, height: trackHeight)

                // Handle. Filled circle styled to read like the standard
                // iOS slider thumb — a contrasting fill with a hairline
                // border and a soft shadow.
                Circle()
                    .fill(.background)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5)
                    )
                    .frame(width: handleSize, height: handleSize)
                    .shadow(color: Color.black.opacity(0.18), radius: 1.5, y: 1)
                    .offset(x: handleX - handleSize / 2)
            }
            .frame(height: handleSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        // Capture the value at touch-down on the very first
                        // event of the drag. All subsequent updates apply
                        // the cumulative translation as a delta — this is
                        // what stops the handle from teleporting to wherever
                        // the finger first landed.
                        if dragStartValue == nil {
                            dragStartValue = value
                        }
                        guard let start = dragStartValue else { return }
                        let span = range.upperBound - range.lowerBound
                        let delta = Double(gesture.translation.width / trackWidth) * span
                        value = min(range.upperBound, max(range.lowerBound, start + delta))
                    }
                    .onEnded { _ in
                        dragStartValue = nil
                        if stepCount >= 2 {
                            value = snappedToNearestStep(value)
                        }
                    }
            )
            .modifier(DoubleTapResetModifier(
                defaultValue: defaultValue,
                value: $value
            ))
        }
        .frame(height: handleSize)
    }

    private var clampedNormalized: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let v = max(range.lowerBound, min(range.upperBound, value))
        return (v - range.lowerBound) / span
    }

    /// Snap a raw value to the nearest step center. Bin k spans
    /// `[k/N, (k+1)/N)` with center at `(k+0.5)/N` (in normalized space);
    /// this is the value the underlying `(VstInt32)(A * (N-1).999)` cast
    /// will reliably round to bin k.
    private func snappedToNearestStep(_ raw: Double) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0, stepCount >= 2 else { return raw }
        let normalized = (raw - range.lowerBound) / span
        let k = min(stepCount - 1, max(0, Int((normalized * Double(stepCount)).rounded(.down))))
        let center = (Double(k) + 0.5) / Double(stepCount)
        return range.lowerBound + center * span
    }
}

/// Conditional double-tap reset — only attaches the gesture when a default
/// value is provided, so callers can opt out without paying for an unused
/// gesture recognizer.
private struct DoubleTapResetModifier: ViewModifier {
    let defaultValue: Double?
    @Binding var value: Double

    func body(content: Content) -> some View {
        if let defaultValue {
            // Must be simultaneous: the fader's drag uses minimumDistance 0 and
            // claims the touch on contact, so a plain onTapGesture would never
            // fire. A double-tap has no movement, so it won't trip the drag.
            content.simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    value = defaultValue
                }
            )
        } else {
            content
        }
    }
}

// MARK: - Previews

#Preview("Linear fader — interactive") {
    LinearFaderPreview()
        .padding(40)
        .background(Color(white: 0.96))
}

private struct LinearFaderPreview: View {
    @State private var a: Double = 0.3
    @State private var b: Double = 0.65
    @State private var c: Double = 1.5

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Default range 0...1, no reset")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LinearFader(value: $a)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("With double-tap reset → 0.5")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LinearFader(value: $b, defaultValue: 0.5)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Extended range 0...2 (e.g. +6 dB headroom), reset → 1.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LinearFader(value: $c, in: 0...2, defaultValue: 1.0)
            }
        }
        .frame(width: 420)
    }
}
