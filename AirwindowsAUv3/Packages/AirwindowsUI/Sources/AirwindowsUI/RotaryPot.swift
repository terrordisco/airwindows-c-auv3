//
//  RotaryPot.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Custom rotary knob used by ParameterRow (in "pots" mode) and by
//  HeaderStripView for the In/Out level controls. Lives in this package
//  so per-effect pots and level pots share one source of truth.
//

import SwiftUI

/// A minimal rotary potentiometer with a 270° arc range (7:30 → 4:30).
/// - Track: full-range light gray arc
/// - Value: dark arc from start to current position, continuing inward as a
///   radial indicator line. Drawn as a single continuous path so the arc
///   smoothly joins the indicator with no visible seam.
///
/// Two initializers:
/// - **Read-only**: pass a `Double` value (used by previews and display-only spots).
/// - **Interactive**: pass a `Binding<Double>` plus optional `defaultValue` —
///   vertical drag changes value, double-tap resets to default.
public struct RotaryPot: View {
    @Binding private var value: Double
    private let isInteractive: Bool
    private let defaultValue: Double
    private let label: String
    private let valueText: String?
    private let size: CGFloat
    private let range: ClosedRange<Double>
    /// 0 = continuous pot. N≥2 = stepped/popup parameter — N small dots are
    /// laid out evenly along the arc (one per case), the pot still drags
    /// freely, and on release the value snaps to the nearest case center.
    /// When stepped, the unity-magnet detent is suppressed so the natural
    /// snap doesn't fight a second magnet at 1.0.
    private let stepCount: Int

    @Environment(\.colorScheme) private var scheme

    @State private var dragStartValue: Double?

    /// Read-only initializer (no interaction).
    public init(
        value: Double,
        label: String,
        valueText: String? = nil,
        size: CGFloat = 44,
        range: ClosedRange<Double> = 0...1,
        stepCount: Int = 0
    ) {
        // Bridge the immutable Double into a Binding so the body can be uniform.
        self._value = Binding(get: { value }, set: { _ in })
        self.isInteractive = false
        self.defaultValue = value
        self.label = label
        self.valueText = valueText
        self.size = size
        self.range = range
        self.stepCount = stepCount
    }

    /// Interactive initializer. Vertical drag updates `value`.
    /// Double-tap resets to `defaultValue`.
    ///
    /// `range` defines the value bounds. Default is `0...1` (the convention
    /// for AU-normalized parameters); the In/Out level pots use `0...2` to
    /// expose +6 dB of post-effect headroom while keeping unity at the
    /// midpoint of the arc.
    public init(
        value: Binding<Double>,
        label: String,
        valueText: String? = nil,
        size: CGFloat = 44,
        defaultValue: Double = 0.5,
        range: ClosedRange<Double> = 0...1,
        stepCount: Int = 0
    ) {
        self._value = value
        self.isInteractive = true
        self.defaultValue = defaultValue
        self.label = label
        self.valueText = valueText
        self.size = size
        self.range = range
        self.stepCount = stepCount
    }

    // Arc sweep: from 135° (7:30) clockwise by 270°, ending at 405° (4:30).
    // SwiftUI uses a y-down coordinate system, so positive angle deltas
    // rotate visually clockwise.
    private static let startDegrees: Double = 135
    private static let sweepDegrees: Double = 270

    /// How many points of vertical drag traverse the full 0...1 range.
    private static let fullRangeDragPoints: CGFloat = 200

    private var strokeWeight: CGFloat {
        // Matches SwiftUI slider track weight for similarly-sized components
        // (slider track is ~3-4pt; for a 48pt pot we get ~4pt).
        max(2.8, size * 0.085)
    }

    /// Radius of the arc's center-line, inset so the stroke fits inside the frame.
    private var arcRadius: CGFloat {
        size / 2 - strokeWeight / 2 - 1
    }

    /// Inner endpoint of the radial indicator, as a fraction of the arc radius.
    private var indicatorInnerFraction: CGFloat { 0.40 }

    /// Step-dot diameter, scaled with pot size so the dots stay readable on
    /// both the 56pt parameter pots and the 64pt In/Out pots without ever
    /// looming larger than the value indicator's stroke.
    private var stepDotSize: CGFloat {
        max(2.5, min(strokeWeight * 0.8, size * 0.06))
    }

    /// Value normalized to 0...1 for shape rendering. The arc visualization
    /// always sweeps from start to end across the configured range, so a 0..2
    /// range with value=1.0 lands the indicator at the midpoint of the sweep.
    private var normalizedValue: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let v = max(range.lowerBound, min(range.upperBound, value))
        return (v - range.lowerBound) / span
    }

    public var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 13, weight: .medium))
                .kerning(1.0)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ZStack {
                PotTrackShape(
                    startDegrees: Self.startDegrees,
                    sweepDegrees: Self.sweepDegrees,
                    radius: arcRadius
                )
                .stroke(
                    Color.secondary.opacity(0.35),
                    style: StrokeStyle(
                        lineWidth: strokeWeight,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                PotValueShape(
                    value: normalizedValue,
                    startDegrees: Self.startDegrees,
                    sweepDegrees: Self.sweepDegrees,
                    outerRadius: arcRadius,
                    innerRadius: arcRadius * indicatorInnerFraction
                )
                .stroke(
                    Color.primary,
                    style: StrokeStyle(
                        lineWidth: strokeWeight,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )

                // Step dots — one per case, sitting on the arc circumference
                // at the angular center of each bin: angle = startDegrees +
                // sweepDegrees * (k + 0.5) / N. Drawn LAST so they remain
                // visible on both the filled (Color.primary) value arc and
                // the unfilled (gray) track, otherwise the value arc paints
                // over them on the lit side. Filled with the surface color
                // so each dot punches out a hole in whatever stroke is
                // behind it — reads cleanly against dark and light alike.
                if stepCount >= 2 {
                    PotStepDotsShape(
                        stepCount: stepCount,
                        startDegrees: Self.startDegrees,
                        sweepDegrees: Self.sweepDegrees,
                        radius: arcRadius,
                        dotSize: stepDotSize
                    )
                    .fill(AirwindowsPalette.surface(scheme))
                }
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .modifier(PotInteractionModifier(
                isInteractive: isInteractive,
                value: $value,
                dragStartValue: $dragStartValue,
                defaultValue: defaultValue,
                range: range,
                stepCount: stepCount
            ))

            if let valueText {
                Text(valueText)
                    .font(.system(size: 15).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Interaction

/// Conditional gesture modifier — only attaches gestures when interactive,
/// so the same view can serve as both a control and a display-only mark.
///
/// Adds a velocity-aware detent at unity (1.0) when the configured range
/// straddles unity. The detent grows with drag speed: precise low-speed
/// tweaks pass through unity untouched, while a fast scrub catches and
/// latches at 1.0. Once latched, the user has to drag clearly away (more
/// than `escapeFraction` of the span) to leave the well — that's what
/// makes the magnet feel deliberate instead of flaky.
private struct PotInteractionModifier: ViewModifier {
    let isInteractive: Bool
    @Binding var value: Double
    @Binding var dragStartValue: Double?
    let defaultValue: Double
    let range: ClosedRange<Double>
    /// 0 = continuous; N≥2 = stepped popup. When stepped, the unity-magnet
    /// detent is suppressed (it would fight the per-step snap) and the value
    /// snaps to the nearest case center on drag-end.
    let stepCount: Int

    /// How many points of vertical drag traverse the full configured range.
    /// (200pt for a 0...1 range; the same per-point sensitivity holds for
    /// wider ranges because the multiplier is the range span.)
    private static let fullRangeDragPoints: CGFloat = 200

    /// Drag speed (pt/sec) at which the unity magnet reaches its full width.
    /// Speeds above this are clamped — going faster doesn't widen the well.
    private static let speedSaturation: Double = 1500

    /// Maximum half-width of the magnet, as a fraction of the value span.
    /// At full speed, values within ±(span × this) of unity get caught.
    private static let maxMagnetFraction: Double = 0.03

    /// Once latched, the user must drag this far past unity (as a fraction of
    /// the value span) to escape. Wider than the entry magnet so the latch
    /// reads as a definite click-stop rather than chatter at the boundary.
    private static let escapeFraction: Double = 0.05

    /// EMA smoothing factor for drag speed — recent samples matter more,
    /// but a single jittery event doesn't flip the magnet on or off.
    private static let speedEMAAlpha: CGFloat = 0.4

    @State private var lastSample: (time: Date, height: CGFloat)?
    @State private var smoothedSpeed: CGFloat = 0
    @State private var unityLatched: Bool = false

    func body(content: Content) -> some View {
        if isInteractive {
            content
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            updateSmoothedSpeed(currentTranslationHeight: gesture.translation.height)

                            if dragStartValue == nil {
                                dragStartValue = value
                            }
                            guard let start = dragStartValue else { return }

                            // Drag UP (negative y) raises value.
                            let span = range.upperBound - range.lowerBound
                            let delta = -gesture.translation.height / Self.fullRangeDragPoints
                            let raw = start + Double(delta) * span
                            let clamped = min(max(raw, range.lowerBound), range.upperBound)

                            // Stepped pots disable the unity magnet — the
                            // per-step snap on release is the only locking
                            // behavior, so the user can drag past 1.0 freely
                            // mid-gesture without two competing detents.
                            if stepCount >= 2 {
                                value = clamped
                            } else {
                                value = applyUnityDetent(toRawValue: clamped, span: span)
                            }
                        }
                        .onEnded { _ in
                            dragStartValue = nil
                            lastSample = nil
                            smoothedSpeed = 0
                            unityLatched = false
                            if stepCount >= 2 {
                                value = snappedToNearestStep(value)
                            }
                        }
                )
                // Must be simultaneous: the drag above uses minimumDistance 0,
                // so it claims the touch on contact and a plain onTapGesture
                // would never fire. A double-tap has no movement, so it can't
                // be confused with a real drag.
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        value = defaultValue
                    }
                )
        } else {
            content
        }
    }

    private func updateSmoothedSpeed(currentTranslationHeight: CGFloat) {
        let now = Date()
        if let last = lastSample {
            let dt = max(now.timeIntervalSince(last.time), 0.001)
            let dy = abs(currentTranslationHeight - last.height)
            let instant = dy / CGFloat(dt)
            smoothedSpeed = smoothedSpeed * (1 - Self.speedEMAAlpha)
                + instant * Self.speedEMAAlpha
        }
        lastSample = (now, currentTranslationHeight)
    }

    /// Returns the value that should be applied after the unity detent has
    /// had its say. Latches into 1.0 when entering the magnet at speed;
    /// releases when the underlying drag has moved clear of the escape zone.
    private func applyUnityDetent(toRawValue clamped: Double, span: Double) -> Double {
        // Magnet only matters when unity is reachable in this range.
        guard range.contains(1.0), span > 0 else { return clamped }

        let speedFactor = min(Double(smoothedSpeed) / Self.speedSaturation, 1.0)
        let magnetHalfWidth = Self.maxMagnetFraction * span * speedFactor
        let escapeHalfWidth = Self.escapeFraction * span

        if unityLatched {
            // Stay latched until the underlying value clearly leaves unity.
            if abs(clamped - 1.0) > escapeHalfWidth {
                unityLatched = false
                return clamped
            }
            return 1.0
        }

        // Latch only if the user is moving fast enough to "want" the snap;
        // pure low-speed precision drags pass straight through unity.
        if speedFactor > 0.1, abs(clamped - 1.0) < magnetHalfWidth {
            unityLatched = true
            return 1.0
        }

        return clamped
    }

    /// Snap a raw value to the nearest case center for an N-step popup
    /// parameter. Bin k spans `[k/N, (k+1)/N)` (in normalized space) with
    /// center at `(k+0.5)/N`, which is the value the underlying
    /// `(VstInt32)(A * (N-1).999)` cast will reliably truncate to k.
    private func snappedToNearestStep(_ raw: Double) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0, stepCount >= 2 else { return raw }
        let normalized = (raw - range.lowerBound) / span
        let k = min(stepCount - 1, max(0, Int((normalized * Double(stepCount)).rounded(.down))))
        let center = (Double(k) + 0.5) / Double(stepCount)
        return range.lowerBound + center * span
    }
}

// MARK: - Shapes

/// Full-range arc (gray track).
private struct PotTrackShape: Shape {
    let startDegrees: Double
    let sweepDegrees: Double
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Positive delta → visually clockwise in SwiftUI's y-down system.
        path.addRelativeArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startDegrees),
            delta: .degrees(sweepDegrees)
        )
        return path
    }
}

/// Dots placed on the arc circumference at the angular center of each bin
/// for a stepped/popup parameter. Each dot is a circle of `dotSize` diameter
/// centered exactly on the arc radius, so it reads as a marker on the track
/// itself rather than a feature floating outside or inside it.
private struct PotStepDotsShape: Shape {
    let stepCount: Int
    let startDegrees: Double
    let sweepDegrees: Double
    let radius: CGFloat
    let dotSize: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard stepCount >= 2 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = dotSize / 2
        for k in 0..<stepCount {
            let frac = (Double(k) + 0.5) / Double(stepCount)
            let deg = startDegrees + sweepDegrees * frac
            let rad = deg * .pi / 180
            let x = center.x + radius * CGFloat(cos(rad))
            let y = center.y + radius * CGFloat(sin(rad))
            path.addEllipse(in: CGRect(x: x - r, y: y - r, width: dotSize, height: dotSize))
        }
        return path
    }
}

/// Value arc + radial indicator, drawn as a single continuous path.
/// With `lineJoin: .round`, the 90° turn from arc to indicator is rendered
/// as a smooth rounded corner instead of a visible T-junction.
private struct PotValueShape: Shape {
    let value: Double
    let startDegrees: Double
    let sweepDegrees: Double
    let outerRadius: CGFloat
    let innerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let clamped = min(max(value, 0), 1)
        let valueSweep = sweepDegrees * clamped

        // Degenerate case: value is (essentially) zero. Draw just the radial
        // indicator stub at the start angle so it's still visible.
        if valueSweep < 0.1 {
            let rad = startDegrees * .pi / 180
            let outer = CGPoint(
                x: center.x + outerRadius * CGFloat(cos(rad)),
                y: center.y + outerRadius * CGFloat(sin(rad))
            )
            let inner = CGPoint(
                x: center.x + innerRadius * CGFloat(cos(rad)),
                y: center.y + innerRadius * CGFloat(sin(rad))
            )
            path.move(to: outer)
            path.addLine(to: inner)
            return path
        }

        // 1) Arc from startDegrees, sweeping by valueSweep degrees clockwise.
        path.addRelativeArc(
            center: center,
            radius: outerRadius,
            startAngle: .degrees(startDegrees),
            delta: .degrees(valueSweep)
        )

        // 2) Continue with a line inward to the inner indicator endpoint,
        //    at the same angle as where the arc ended.
        let endRad = (startDegrees + valueSweep) * .pi / 180
        let innerPoint = CGPoint(
            x: center.x + innerRadius * CGFloat(cos(endRad)),
            y: center.y + innerRadius * CGFloat(sin(endRad))
        )
        path.addLine(to: innerPoint)
        return path
    }
}

// MARK: - Previews

#Preview("Sizes") {
    HStack(spacing: 40) {
        RotaryPot(value: 0.65, label: "Large", valueText: "−3.2 dB", size: 64)
        RotaryPot(value: 0.65, label: "Medium", valueText: "−3.2 dB", size: 44)
        RotaryPot(value: 0.65, label: "Small", valueText: "−3.2 dB", size: 32)
    }
    .padding(40)
    .background(Color(white: 0.98))
}

#Preview("Value range") {
    HStack(spacing: 24) {
        RotaryPot(value: 0.00, label: "0%", valueText: "−∞", size: 44)
        RotaryPot(value: 0.25, label: "25%", valueText: "−12 dB", size: 44)
        RotaryPot(value: 0.50, label: "50%", valueText: "−6 dB", size: 44)
        RotaryPot(value: 0.75, label: "75%", valueText: "−3 dB", size: 44)
        RotaryPot(value: 1.00, label: "100%", valueText: "0 dB", size: 44)
    }
    .padding(40)
    .background(Color(white: 0.98))
}

#Preview("Interactive") {
    InteractivePotPreview()
        .padding(40)
        .background(Color(white: 0.98))
}

private struct InteractivePotPreview: View {
    @State private var inLevel: Double = 0.75
    @State private var outLevel: Double = 0.5

    var body: some View {
        HStack(spacing: 40) {
            RotaryPot(
                value: $inLevel,
                label: "In",
                valueText: String(format: "%.2f", inLevel),
                size: 64,
                defaultValue: 0.75
            )
            RotaryPot(
                value: $outLevel,
                label: "Out",
                valueText: String(format: "%.2f", outLevel),
                size: 64,
                defaultValue: 0.5
            )
        }
    }
}

#Preview("Header strip (mock)") {
    HStack(spacing: 20) {
        HStack(spacing: 16) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.secondary)
            RotaryPot(value: 0.75, label: "In", valueText: "−3.0 dB", size: 44)
        }
        Spacer()
        VStack(spacing: 4) {
            Text("Filter")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack(spacing: 28) {
                Text("← PreviousEffect")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("Highpass")
                    .font(.system(size: 26, weight: .semibold))
                Text("NextEffect →")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        Spacer()
        RotaryPot(value: 0.75, label: "Out", valueText: "−3.0 dB", size: 44)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
    .background(Color.white)
    .frame(width: 900)
    .padding(40)
    .background(Color(white: 0.95))
}
