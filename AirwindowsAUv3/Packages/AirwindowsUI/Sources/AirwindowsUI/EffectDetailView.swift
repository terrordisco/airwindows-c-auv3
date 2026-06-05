//
//  EffectDetailView.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The plugin's main workspace, shown whenever an effect is selected.
//  AirwindowsAUView hands it the current effect plus parameter bindings;
//  it arranges HeaderStripView, ParameterGrid, and the description
//  scroller underneath.
//

import SwiftUI

/// Effect detail surface — the main workspace.
///
/// Layout:
/// ```
/// ┌────────────────────────────────────────────────────┐
/// │ HeaderStrip (sidebar | IN | category/prev/name/next | OUT) │
/// │ ──────────────────────────────────────────────────── │
/// │     "tagline"         [MONO] [nP] [🌙] [↺]          │
/// │                                                       │
/// │   ParameterGrid (1/2/3 col)                          │
/// │                                                       │
/// │   ───  scrollable description from awpdoc  ───       │
/// └────────────────────────────────────────────────────┘
/// ```
public struct EffectDetailView: View {
    public let effect: EffectBrowseModel
    public let parameterCount: Int
    public let parameterNames: [String]
    public let parameterDisplays: [String]
    public let parameterLabels: [String]
    /// Per-parameter step count. 0 = continuous; N≥2 = stepped/popup.
    /// Empty array means all-continuous.
    public let parameterStepCounts: [Int]
    /// Per-parameter default values, used for double-tap-to-reset on each
    /// fader/pot. Empty array → controls fall back to 0.5.
    public let parameterDefaults: [Double]
    public let description: String
    public let previousName: String?
    public let nextName: String?
    public let inputDisplay: String
    public let outputDisplay: String
    @Binding public var parameterValues: [Double]
    @Binding public var inputLevel: Double
    @Binding public var outputLevel: Double
    public let onPrevious: () -> Void
    public let onNext: () -> Void
    public let onTitleTap: () -> Void
    public let onReset: () -> Void
    /// Optional — when provided, a Randomize chip appears next to Reset.
    public let onRandomize: (() -> Void)?
    /// Optional undo/redo. When provided, Undo/Redo chips appear left of
    /// Random/Reset, dimmed and inert when their stack is empty.
    public let onUndo: (() -> Void)?
    public let onRedo: (() -> Void)?
    public let canUndo: Bool
    public let canRedo: Bool
    public let isDarkMode: Bool
    public let onToggleTheme: (() -> Void)?
    public let useRotaryPots: Bool
    public let onToggleControlStyle: (() -> Void)?
    /// Optional — when provided, a favorite star appears right of the name box
    /// and toggles this effect's membership in the shared favorites store.
    public let favorites: FavoritesStore?

    @Environment(\.colorScheme) private var scheme

    public init(
        effect: EffectBrowseModel,
        parameterCount: Int,
        parameterNames: [String],
        parameterDisplays: [String],
        parameterLabels: [String],
        parameterStepCounts: [Int] = [],
        parameterDefaults: [Double] = [],
        description: String,
        previousName: String?,
        nextName: String?,
        inputDisplay: String,
        outputDisplay: String,
        parameterValues: Binding<[Double]>,
        inputLevel: Binding<Double>,
        outputLevel: Binding<Double>,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onTitleTap: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onRandomize: (() -> Void)? = nil,
        onUndo: (() -> Void)? = nil,
        onRedo: (() -> Void)? = nil,
        canUndo: Bool = false,
        canRedo: Bool = false,
        isDarkMode: Bool = false,
        onToggleTheme: (() -> Void)? = nil,
        useRotaryPots: Bool = false,
        onToggleControlStyle: (() -> Void)? = nil,
        favorites: FavoritesStore? = nil
    ) {
        self.effect = effect
        self.parameterCount = parameterCount
        self.parameterNames = parameterNames
        self.parameterDisplays = parameterDisplays
        self.parameterLabels = parameterLabels
        self.parameterStepCounts = parameterStepCounts
        self.parameterDefaults = parameterDefaults
        self.description = description
        self.previousName = previousName
        self.nextName = nextName
        self.inputDisplay = inputDisplay
        self.outputDisplay = outputDisplay
        self._parameterValues = parameterValues
        self._inputLevel = inputLevel
        self._outputLevel = outputLevel
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onTitleTap = onTitleTap
        self.onReset = onReset
        self.onRandomize = onRandomize
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.isDarkMode = isDarkMode
        self.onToggleTheme = onToggleTheme
        self.useRotaryPots = useRotaryPots
        self.onToggleControlStyle = onToggleControlStyle
        self.favorites = favorites
    }

    // Sliders-layout scroll-gutter geometry. The gutter mirrors the header's
    // IN pot (48pt wide at a 20pt outer inset); `gutterGap` is used on both
    // sides of the faders so the field is symmetric (gutter→faders == faders→edge).
    private static let gutterWidth: CGFloat = 48
    private static let gutterOuterInset: CGFloat = 20
    private static let gutterGap: CGFloat = 20

    /// The parameter grid itself, built once and positioned by the slider/pot
    /// branches in `body` (sliders add a left scroll gutter; pots tile to the
    /// edges).
    private var parameterGridView: some View {
        ParameterGrid(
            parameterCount: parameterCount,
            parameterNames: parameterNames,
            parameterDisplays: parameterDisplays,
            parameterLabels: parameterLabels,
            parameterValues: $parameterValues,
            parameterStepCounts: parameterStepCounts,
            parameterDefaults: parameterDefaults,
            useRotaryPots: useRotaryPots
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Tagline reads as a title at the very top — sits at the same
            // vertical level as the host's window controls (traffic lights),
            // which the host paints over the top-left corner of the plugin
            // frame. The wide horizontal padding keeps the centered text
            // clear of those controls.
            if !effect.whatText.isEmpty {
                Text("\u{201C}\(effect.whatText)\u{201D}")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 140)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
            }

            HeaderStripView(
                category: effect.category,
                effectName: effect.name,
                previousName: previousName,
                nextName: nextName,
                inputLevel: $inputLevel,
                outputLevel: $outputLevel,
                inputDisplay: inputDisplay,
                outputDisplay: outputDisplay,
                onPrevious: onPrevious,
                onNext: onNext,
                onTitleTap: onTitleTap,
                isFavorite: favorites?.isFavorite(effect.name) ?? false,
                onToggleFavorite: favorites.map { store in
                    { store.toggle(effect.name) }
                }
            )

            Divider()
                .opacity(0.4)

            // Chip row — MONO/STEREO on the left, action toggles on the right.
            // The tagline lives above the header now, so this row is no longer
            // shared with text and chips can't collide.
            HStack(spacing: 8) {
                MetaChip(text: effect.isMono ? "MONO" : "STEREO")

                Spacer()

                // Button chips right, filled style. Each chip's label
                // states the destination (where you go when you tap it),
                // matching the convention Apple uses for context menu
                // toggles. The Reset chip stays a constant verb because
                // it isn't a state toggle.
                // Blog post / video chips live in the browser preview pane,
                // not here — see EffectPreviewColumn in BrowserView.swift.
                if let onToggleTheme {
                    FilledIconChip(
                        systemName: isDarkMode ? "sun.max" : "moon",
                        text: isDarkMode ? "Day" : "Night",
                        accessibility: isDarkMode ? "Switch to light mode" : "Switch to dark mode",
                        action: onToggleTheme
                    )
                }

                if let onToggleControlStyle {
                    FilledIconChip(
                        systemName: useRotaryPots ? "slider.horizontal.below.rectangle" : "dial.medium",
                        text: useRotaryPots ? "Sliders" : "Pots",
                        accessibility: useRotaryPots
                            ? "Switch parameter controls to sliders"
                            : "Switch parameter controls to pots",
                        action: onToggleControlStyle
                    )
                }

                // Undo/Redo sit left of the destructive Random/Reset pair.
                // They dim and stop responding when their history is empty,
                // so the row never loses its shape but reads as unavailable.
                if let onUndo {
                    FilledIconChip(
                        systemName: "arrow.uturn.backward",
                        text: "Undo",
                        accessibility: "Undo last change",
                        isEnabled: canUndo,
                        action: onUndo
                    )
                }

                if let onRedo {
                    FilledIconChip(
                        systemName: "arrow.uturn.forward",
                        text: "Redo",
                        accessibility: "Redo",
                        isEnabled: canRedo,
                        action: onRedo
                    )
                }

                if let onRandomize {
                    FilledIconChip(
                        systemName: "dice",
                        text: "Random",
                        accessibility: "Randomize parameters",
                        action: onRandomize
                    )
                }

                FilledIconChip(
                    systemName: "arrow.counterclockwise",
                    text: "Reset",
                    accessibility: "Reset parameters",
                    action: onReset
                )
            }
            .frame(minHeight: 22)
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 18)

            // Parameter grid — or, for the ~48 fixed-character effects with
            // no exposed parameters (dithers, console fixed buses, etc.),
            // a centered empty-state mirroring the "No effect selected"
            // placeholder used by the browser's preview column.
            //
            // With parameters present, the grid and the description scroll
            // together as one field. Empty space scrolls with one finger; a
            // touch landing on a fader/pot drives that control instead of
            // scrolling (so two controls can be grabbed at once). See
            // ParameterScrollView.
            if parameterCount > 0 {
                ParameterScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if useRotaryPots {
                            parameterGridView
                                .padding(.horizontal, 24)
                                // Breathing room above row 1 so the header strip
                                // doesn't crowd the first parameter's number ring
                                // (the stroked circle's top was getting clipped).
                                .padding(.top, 10)
                                .padding(.bottom, 22)
                        } else {
                            // Sliders gain a left-edge scroll gutter: a faint
                            // hatch column aligned under the header's IN pot
                            // (same 48pt width, same 20pt outer inset). The
                            // faders shift right to clear it; the gutter→faders
                            // gap (20) equals the faders→right-edge gap (20), so
                            // the field reads symmetrically. The hatch is a
                            // background applied *before* the top/bottom padding
                            // so it spans exactly the rows (top of row 1 to bottom
                            // of the last row) and isn't stretched into the
                            // breathing space above or the gap below.
                            parameterGridView
                                .padding(.leading, Self.gutterOuterInset + Self.gutterWidth + Self.gutterGap)
                                .padding(.trailing, Self.gutterGap)
                                .background(alignment: .topLeading) {
                                    ScrollHatchGutter()
                                        .frame(width: Self.gutterWidth)
                                        .padding(.leading, Self.gutterOuterInset)
                                        // Stop one hatch line short of the last
                                        // row's bottom edge.
                                        .padding(.bottom, ScrollHatchGutter.lineStep)
                                }
                                .padding(.top, 10)
                                .padding(.bottom, 22)
                        }

                        if shouldShowDescription {
                            Divider()
                                .opacity(0.4)

                            // Promotes the awpdoc's leading `# ` line into a
                            // heading instead of showing the literal `#`.
                            EffectDescriptionText(description)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 18)
                        }
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("This effect has no parameters")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // No faders here to clash with, so this description keeps
                // ordinary single-finger scrolling.
                if shouldShowDescription {
                    Divider()
                        .opacity(0.4)

                    ScrollView {
                        EffectDescriptionText(description)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                    }
                    .scrollIndicators(.automatic)
                } else {
                    Spacer(minLength: 0)
                }
            }
        }
        .background(AirwindowsPalette.surface(scheme))
    }

    private var shouldShowDescription: Bool {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagline = effect.whatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed != tagline
    }
}

/// Left-edge scroll affordance for the sliders layout: a column of faint
/// horizontal hatch lines, aligned under the header's IN pot. It is purely an
/// empty-space scroll target — it carries no `.scrollDragControl()`, so a touch
/// landing here scrolls the workspace (unlike a touch on a fader). The lines
/// match the UI's dividers (`Color(.separator)` at 0.4 opacity, hairline) and
/// sit 5pt apart.
private struct ScrollHatchGutter: View {
    private static let lineSpacing: CGFloat = 5
    private static let lineThickness: CGFloat = 2
    /// Center-to-center distance between hatch lines; also the amount the
    /// caller insets to drop exactly one line off an edge.
    static let lineStep: CGFloat = lineSpacing + lineThickness

    var body: some View {
        Canvas { context, size in
            let step = Self.lineStep
            var y: CGFloat = 0
            while y <= size.height {
                let line = Path(CGRect(x: 0, y: y, width: size.width, height: Self.lineThickness))
                context.fill(line, with: .color(Color(uiColor: .separator)))
                y += step
            }
        }
        .opacity(0.4)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct MetaChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
    }
}

/// Stroked chip that opens an external URL (blog post, YouTube video).
/// Used in the browser preview pane. Module-internal so BrowserView can render
/// these chips without re-implementing them.
///
/// `text` is optional — when nil the chip is icon-only (legacy compact
/// presentation). When set, the icon sits to the left of the label.
struct LinkChip: View {
    let url: URL
    let systemName: String
    let text: String?
    let accessibility: String

    @Environment(\.openURL) private var openURL

    init(url: URL, systemName: String, text: String? = nil, accessibility: String) {
        self.url = url
        self.systemName = systemName
        self.text = text
        self.accessibility = accessibility
    }

    var body: some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .medium))
                if let text {
                    Text(text)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }
}

private struct FilledIconChip: View {
    let systemName: String
    let text: String?
    let accessibility: String
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    init(
        systemName: String,
        text: String? = nil,
        accessibility: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.text = text
        self.accessibility = accessibility
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .medium))
                if let text {
                    Text(text)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundStyle(scheme == .dark ? Color.black : Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.85))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        // Dim the whole chip when there's nothing to do, matching the
        // standard "unavailable control" affordance.
        .opacity(isEnabled ? 1 : 0.3)
        .accessibilityLabel(accessibility)
    }
}

// MARK: - Preview

#Preview("Detail — 4 params (light)") {
    DetailPreviewWrapper(paramCount: 4)
        .frame(width: 900, height: 640)
        .background(Color(white: 0.93))
}

#Preview("Detail — 8 params (dark)") {
    DetailPreviewWrapper(paramCount: 8, mono: true, dark: true)
        .frame(width: 900, height: 640)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
}

private struct DetailPreviewWrapper: View {
    let paramCount: Int
    var mono: Bool = false
    var dark: Bool = false

    @State private var values: [Double] = Array(repeating: 0.5, count: 10)
    @State private var inLevel: Double = 1.0
    @State private var outLevel: Double = 1.0
    @State private var darkMode: Bool = false

    var body: some View {
        let effect = EffectBrowseModel(
            registryIndex: 0,
            name: "Highpass",
            category: "Filter",
            whatText: "an analog-feel highpass filter that doesn't kill the lows",
            nParams: paramCount,
            isMono: mono,
            catChrisOrdering: 12,
            firstCommitDate: "2018-04-12",
            collections: ["Recommended", "Basic"]
        )

        EffectDetailView(
            effect: effect,
            parameterCount: paramCount,
            parameterNames: (0..<paramCount).map { "Param \($0 + 1)" },
            parameterDisplays: (0..<paramCount).map { _ in "0.50" },
            parameterLabels: (0..<paramCount).map { $0 == 0 ? "dB" : "" },
            description: """
            The Highpass filter rolls off the bottom of the spectrum without removing the warmth.
            Drag the cutoff to taste. Resonance and slope shape the curve. Best used as a subtle
            cleanup tool rather than a brick wall — most Airwindows tools follow this analog-leaning
            philosophy.
            """,
            previousName: "Bassdrive",
            nextName: "Lowpass",
            inputDisplay: "0.0 dB",
            outputDisplay: "0.0 dB",
            parameterValues: $values,
            inputLevel: $inLevel,
            outputLevel: $outLevel,
            onPrevious: {},
            onNext: {},
            onTitleTap: {},
            onReset: {},
            isDarkMode: darkMode,
            onToggleTheme: { darkMode.toggle() }
        )
        .padding(20)
    }
}
