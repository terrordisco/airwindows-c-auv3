//
//  ParameterGrid.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Lays out the current effect's parameters inside EffectDetailView,
//  one ParameterRow per parameter. Each row picks LinearFader or
//  RotaryPot based on the useRotaryPots flag, which originates in
//  AirwindowsAUView's auto/sliders/pots preference.
//

import SwiftUI

/// A single parameter row: enclosed-alphanumeric glyph + name + (value + label),
/// with either a horizontal slider (default) or a rotary pot below — chosen
/// by the `useRotaryPots` flag, which the user toggles via the chip in
/// EffectDetailView's header. The pot variant uses a smaller, centered
/// RotaryPot that takes up less vertical real estate; layout-wise the row
/// still reserves the same vertical strip so the grid doesn't reflow when
/// the user toggles.
public struct ParameterRow: View {
    public let index: Int  // 0-based, used for the numbered glyph
    public let name: String
    public let displayValue: String
    public let label: String
    public let useRotaryPots: Bool
    /// 0 = continuous parameter; N≥2 = stepped/popup. Forwarded to the
    /// LinearFader / RotaryPot so they render step dots and snap on release.
    public let stepCount: Int
    @Binding public var value: Double

    public init(
        index: Int,
        name: String,
        displayValue: String,
        label: String,
        value: Binding<Double>,
        useRotaryPots: Bool = false,
        stepCount: Int = 0
    ) {
        self.index = index
        self.name = name
        self.displayValue = displayValue
        self.label = label
        self.useRotaryPots = useRotaryPots
        self.stepCount = stepCount
        self._value = value
    }

    public var body: some View {
        if useRotaryPots {
            potBody
        } else {
            sliderBody
        }
    }

    /// Pot layout — compact, vertical, designed to tile in a flowing grid:
    /// ```
    ///     [#] Name           ← centered as a unit; name left-aligned
    ///     [#] Reaction         within itself so it wraps cleanly
    ///         Speed
    ///       [ pot ]
    ///        value
    /// ```
    /// The number+name pair is centered horizontally as one unit (Spacers
    /// either side push them inward). The parameter name uses leading
    /// multiline alignment so on the rare 14-char name like "Reaction Speed"
    /// the second line tucks under the first instead of zig-zagging. The
    /// display value sits centered under the pot it belongs to.
    private var potBody: some View {
        VStack(spacing: 5) {
            HStack(alignment: .top, spacing: 10) {
                Spacer(minLength: 0)

                Text("\(index + 1)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1.2)
                    )
                    // Optical-alignment nudge: the circle's geometric center
                    // sits a hair below where the eye expects it to align with
                    // the title's cap height. Shift up 1pt; balance with the
                    // title's +2pt nudge below to land on the same baseline.
                    .offset(y: -1)

                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .offset(y: 2)

                Spacer(minLength: 0)
            }

            // Empty label — the name already sits in the header above.
            RotaryPot(
                value: $value,
                label: "",
                size: 56,
                defaultValue: 0.5,
                stepCount: stepCount
            )

            Text(formattedValue)
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
    }

    private var sliderBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                    )

                Text(name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(formattedValue)
                    .font(.system(size: 15).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Custom fader: relative-drag, no touch-teleport. See LinearFader.swift.
            LinearFader(value: $value, stepCount: stepCount)
        }
    }

    /// Concatenates the display value with the parameter's unit label, when
    /// the label is non-empty. For example: `18.0 dB`. Many Airwindows
    /// effects leave the label empty; in that case we show just the value.
    private var formattedValue: String {
        let label = self.label.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return displayValue }
        return "\(displayValue) \(label)"
    }

}

/// Parameter grid with adaptive column count.
///
/// Column rules (matching Figma spec):
/// - 0 params: shows nothing (caller decides what to render)
/// - 1–2 params: 1 column
/// - 3–6 params: 2 columns
/// - 7+ params: 3 columns
public struct ParameterGrid: View {
    public let parameterCount: Int
    public let parameterNames: [String]
    public let parameterDisplays: [String]
    public let parameterLabels: [String]
    /// Per-parameter step count. Empty array or zeros → all continuous.
    /// Non-zero entries flag stepped/popup parameters; the corresponding row
    /// renders step dots and snaps on release.
    public let parameterStepCounts: [Int]
    public let useRotaryPots: Bool
    @Binding public var parameterValues: [Double]

    public init(
        parameterCount: Int,
        parameterNames: [String],
        parameterDisplays: [String],
        parameterLabels: [String],
        parameterValues: Binding<[Double]>,
        parameterStepCounts: [Int] = [],
        useRotaryPots: Bool = false
    ) {
        self.parameterCount = parameterCount
        self.parameterNames = parameterNames
        self.parameterDisplays = parameterDisplays
        self.parameterLabels = parameterLabels
        self.parameterStepCounts = parameterStepCounts
        self.useRotaryPots = useRotaryPots
        self._parameterValues = parameterValues
    }

    public var body: some View {
        if parameterCount == 0 {
            EmptyView()
        } else if useRotaryPots {
            // Pots tile in an adaptive grid that reflows with the available
            // width: as the plugin window grows, more pots fit per row. Each
            // column is constrained between `potColumnMinWidth` and
            // `potColumnMaxWidth` so the cells stay tight around the 56pt pot
            // instead of stretching like the slider rows do.
            LazyVGrid(columns: potColumns, alignment: .center, spacing: 22) {
                rows
            }
        } else {
            LazyVGrid(columns: sliderColumns, alignment: .leading, spacing: 22) {
                rows
            }
        }
    }

    @ViewBuilder
    private var rows: some View {
        ForEach(0..<parameterCount, id: \.self) { i in
            ParameterRow(
                index: i,
                name: safeName(at: i),
                displayValue: safeDisplay(at: i),
                label: safeLabel(at: i),
                value: Binding(
                    get: { parameterValues.indices.contains(i) ? parameterValues[i] : 0 },
                    set: { newValue in
                        guard parameterValues.indices.contains(i) else { return }
                        parameterValues[i] = newValue
                    }
                ),
                useRotaryPots: useRotaryPots,
                stepCount: safeStepCount(at: i)
            )
        }
    }

    private func safeStepCount(at i: Int) -> Int {
        parameterStepCounts.indices.contains(i) ? parameterStepCounts[i] : 0
    }

    /// Bounds for an adaptive pot column. Wider cells with tighter spacing
    /// between them — the previous 80/38 ratio left too little text space
    /// for parameter names like "Reaction Speed" relative to the empty
    /// gutters between cells. Now ~85% of horizontal real estate is the
    /// cell itself, ~15% the inter-cell gap.
    private let potColumnMinWidth: CGFloat = 115
    private let potColumnMaxWidth: CGFloat = 140
    private let potColumnSpacing: CGFloat = 18

    private var potColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: potColumnMinWidth, maximum: potColumnMaxWidth),
                spacing: potColumnSpacing,
                alignment: .top
            )
        ]
    }

    private var sliderColumns: [GridItem] {
        let columnCount: Int = {
            switch parameterCount {
            case 0...2: return 1
            case 3...6: return 2
            case 7...12: return 3
            default: return 4
            }
        }()
        return Array(
            repeating: GridItem(.flexible(), spacing: 28, alignment: .top),
            count: columnCount
        )
    }

    private func safeName(at i: Int) -> String {
        parameterNames.indices.contains(i) ? parameterNames[i] : ""
    }

    private func safeDisplay(at i: Int) -> String {
        parameterDisplays.indices.contains(i) ? parameterDisplays[i] : ""
    }

    private func safeLabel(at i: Int) -> String {
        parameterLabels.indices.contains(i) ? parameterLabels[i] : ""
    }
}

// MARK: - Preview

#Preview("1 column (2 params)") {
    GridPreviewWrapper(count: 2)
        .padding(40)
        .background(Color.white)
}

#Preview("2 columns (4 params)") {
    GridPreviewWrapper(count: 4)
        .padding(40)
        .background(Color.white)
}

#Preview("3 columns (8 params)") {
    GridPreviewWrapper(count: 8)
        .padding(40)
        .background(Color.white)
}

private struct GridPreviewWrapper: View {
    let count: Int
    @State private var values: [Double] = Array(repeating: 0.5, count: 10)

    var body: some View {
        ParameterGrid(
            parameterCount: count,
            parameterNames: (0..<count).map { "Param \($0 + 1)" },
            parameterDisplays: (0..<count).map { _ in "0.50" },
            parameterLabels: (0..<count).map { $0 == 0 ? "dB" : "" },
            parameterValues: $values
        )
        .frame(width: 700)
    }
}
