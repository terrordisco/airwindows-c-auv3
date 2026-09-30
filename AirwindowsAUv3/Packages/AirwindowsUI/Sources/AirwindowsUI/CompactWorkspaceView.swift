//
//  CompactWorkspaceView.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The `.compact` layout-mode counterpart of EffectDetailView, shown when the
//  container is narrower than ~600 pt or shorter than ~360 pt (Split View,
//  Slide Over, a GarageBand strip, an iPhone). Same parameters, same
//  bindings; only the arrangement differs:
//
//  ```
//  ┌──────────────────────────────────────────┐
//  │ [▤]   ‹  FILTER  Highpass  ›        [≡]  │  header: browser · title · menu
//  │ ──────────────────────────────────────── │
//  │  (In) 0.0 dB     STEREO     (Out) 0.0 dB │  levels row
//  │ ──────────────────────────────────────── │
//  │  Cutoff     ───────●──────────    0.50   │  one-column faders (or pots)
//  │  …                                       │
//  │ ──────────────────────────────────────── │
//  │        “tagline, centered, italic”       │  tagline band
//  │ ──────────────────────────────────────── │
//  │  # Highpass  long description…           │
//  └──────────────────────────────────────────┘
//  ```
//
//  Everything the full layout puts in the bottom bar (Undo/Redo, Random,
//  Reset, Save/Recall, Pots/Sliders, Night/Day, Settings) lives behind the
//  menu button in CompactMenuDrawer, which slides in from the right over a
//  dimmed workspace. The browser button on the left opens the effect
//  browser; the title box holds the prev/next jogs and is otherwise inert.
//

import SwiftUI

public struct CompactWorkspaceView: View {
    public let effect: EffectBrowseModel
    public let parameterCount: Int
    public let parameterNames: [String]
    public let parameterDisplays: [String]
    public let parameterLabels: [String]
    public let parameterStepCounts: [Int]
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
    public let onOpenBrowser: () -> Void
    public let onReset: () -> Void
    public let onRandomize: (() -> Void)?
    public let onUndo: (() -> Void)?
    public let onRedo: (() -> Void)?
    public let canUndo: Bool
    public let canRedo: Bool
    public let appearance: AirwindowsAppearance
    public let onCycleAppearance: () -> Void
    public let useRotaryPots: Bool
    public let onToggleControlStyle: (() -> Void)?
    public let hasSavedSettings: Bool
    public let onSaveSettings: (() -> Void)?
    public let onRecallSettings: (() -> Void)?
    public let onClearSavedSettings: (() -> Void)?
    public let favorites: FavoritesStore?
    public let onOpenSettings: (() -> Void)?
    public let onOpenAbout: (() -> Void)?
    public let isMonitoring: Bool
    public let onToggleMonitoring: (() -> Void)?
    /// Scrollpad edge (left / right / off) and the menu row's cycle action.
    public let scrollpad: ScrollpadPlacement
    public let onCycleScrollpad: () -> Void
    /// Settings rows in the menu drawer (see CompactMenuDrawer). nil hides them.
    public let uiScaleBinding: Binding<Double>?
    public let compactEverywhereBinding: Binding<Bool>?

    @Environment(\.colorScheme) private var scheme
    @Environment(\.uiScale) private var uiScale
    @Environment(\.containerSize) private var containerSize
    @State private var showMenu = false
    /// Measured heights for the scrollpad rule: the strip only shows when the
    /// pots/fader field is taller than the scrollable area it sits in, i.e.
    /// when there is actually something to scroll to. A short field that fits
    /// gets no strip.
    @State private var fieldHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0

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
        onOpenBrowser: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onRandomize: (() -> Void)? = nil,
        onUndo: (() -> Void)? = nil,
        onRedo: (() -> Void)? = nil,
        canUndo: Bool = false,
        canRedo: Bool = false,
        appearance: AirwindowsAppearance = .auto,
        onCycleAppearance: @escaping () -> Void = {},
        useRotaryPots: Bool = false,
        onToggleControlStyle: (() -> Void)? = nil,
        hasSavedSettings: Bool = false,
        onSaveSettings: (() -> Void)? = nil,
        onRecallSettings: (() -> Void)? = nil,
        onClearSavedSettings: (() -> Void)? = nil,
        favorites: FavoritesStore? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onOpenAbout: (() -> Void)? = nil,
        isMonitoring: Bool = false,
        onToggleMonitoring: (() -> Void)? = nil,
        scrollpad: ScrollpadPlacement = .left,
        onCycleScrollpad: @escaping () -> Void = {},
        uiScaleBinding: Binding<Double>? = nil,
        compactEverywhereBinding: Binding<Bool>? = nil
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
        self.onOpenBrowser = onOpenBrowser
        self.onReset = onReset
        self.onRandomize = onRandomize
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.appearance = appearance
        self.onCycleAppearance = onCycleAppearance
        self.useRotaryPots = useRotaryPots
        self.onToggleControlStyle = onToggleControlStyle
        self.hasSavedSettings = hasSavedSettings
        self.onSaveSettings = onSaveSettings
        self.onRecallSettings = onRecallSettings
        self.onClearSavedSettings = onClearSavedSettings
        self.favorites = favorites
        self.onOpenSettings = onOpenSettings
        self.onOpenAbout = onOpenAbout
        self.isMonitoring = onToggleMonitoring == nil ? false : isMonitoring
        self.onToggleMonitoring = onToggleMonitoring
        self.scrollpad = scrollpad
        self.onCycleScrollpad = onCycleScrollpad
        self.uiScaleBinding = uiScaleBinding
        self.compactEverywhereBinding = compactEverywhereBinding
    }

    /// Scrollpad strip width. Flush to the container edge, no outer inset —
    /// the point is that a thumb resting on the edge lands on it.
    private static let scrollpadWidth: CGFloat = 44
    private static let scrollpadGap: CGFloat = 12

    // Fixed chrome metrics — the header row is chrome and doesn't scale.
    private static let chromeInset: CGFloat = 12
    /// Below this container width faders stack in one column; wider
    /// containers fall back to ParameterGrid's count-based column rule so a
    /// big window doesn't get metre-long faders.
    private static let singleColumnBelow: CGFloat = 600
    private static let drawerWidth: CGFloat = 300
    /// Below this container width the drawer covers the whole container
    /// (iPhone portrait) instead of leaving a sliver of workspace showing.
    private static let fullWidthDrawerBelow: CGFloat = 430

    public var body: some View {
        ZStack(alignment: .trailing) {
            workspace
                .accessibilityHidden(showMenu)

            if showMenu {
                // Scrim: dims the workspace and closes the drawer on tap.
                // Explicit zIndex on both layers: a view leaving a ZStack
                // otherwise drops BEHIND its siblings for the duration of its
                // exit transition, so the drawer's text would slide out over
                // the workspace with its background underneath.
                Color.black.opacity(scheme == .dark ? 0.35 : 0.18)
                    .ignoresSafeArea()
                    .onTapGesture { closeMenu() }
                    .transition(.opacity)
                    .zIndex(1)
                    .accessibilityLabel("Close menu")
                    .accessibilityAddTraits(.isButton)

                menuDrawer
                    .frame(width: drawerWidth)
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.18), radius: 16, x: -4)
                    .transition(.move(edge: .trailing))
                    .zIndex(2)
            }
        }
        .background(AirwindowsPalette.surface(scheme))
        // Same stable anchor the full layout exposes for the UI smoke test.
        .accessibilityIdentifier("effectDetailView")
    }

    private var drawerWidth: CGFloat {
        containerSize.width > 1 && containerSize.width < Self.fullWidthDrawerBelow
            ? containerSize.width
            : Self.drawerWidth
    }

    private static let drawerAnimation: Animation = .spring(duration: 0.32, bounce: 0)

    private func openMenu() {
        withAnimation(Self.drawerAnimation) { showMenu = true }
    }

    private func closeMenu() {
        withAnimation(Self.drawerAnimation) { showMenu = false }
    }

    /// Wraps a drawer action so choosing it also dismisses the drawer. Toggle
    /// rows (favorite, style, appearance, monitoring) stay open so the
    /// indicator visibly changes; commands close.
    private func closing(_ action: (() -> Void)?) -> (() -> Void)? {
        action.map { act in { act(); closeMenu() } }
    }

    // MARK: Workspace

    private var workspace: some View {
        VStack(spacing: 0) {
            header
            hairline
            levelsRow
            hairline
            body_parameters
        }
    }

    private var hairline: some View {
        Divider().opacity(0.4)
    }

    /// `[▤]  ‹ FILTER Highpass ›  [≡]`
    private var header: some View {
        HStack(spacing: 8) {
            CompactChromeButton(systemName: "sidebar.left", accessibility: "Browse effects", action: onOpenBrowser)

            titleBox
                .frame(maxWidth: .infinity)

            CompactChromeButton(systemName: "line.3.horizontal", accessibility: "Menu", action: { openMenu() })
        }
        .padding(.horizontal, Self.chromeInset)
        .padding(.top, headerTopInset)
        .padding(.bottom, 10)
    }

    private var headerTopInset: CGFloat {
        CompactChrome.headerTopInset(containerHeight: containerSize.height)
    }

    private var sliderColumnCap: Int? {
        containerSize.width > 1 && containerSize.width < Self.singleColumnBelow ? 1 : nil
    }

    /// Stroked box holding the prev/next jogs around the category kicker and
    /// effect name. The name scales with the UI but is capped so it always
    /// fits between the jogs; the box itself is inert (the browser button
    /// opens the browser).
    private var titleBox: some View {
        HStack(spacing: 4) {
            JogChevron(direction: .previous, enabled: previousName != nil, targetName: previousName, action: onPrevious)

            HStack(spacing: 8 * uiScale) {
                Text(effect.category.uppercased())
                    .font(.system(size: 10 * uiScale, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(effect.name)
                    .font(.system(size: 22 * uiScale, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(effect.category), \(effect.name)")

            JogChevron(direction: .next, enabled: nextName != nil, targetName: nextName, action: onNext)
        }
        .padding(.horizontal, 6)
        .frame(height: 44)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
        )
    }

    /// `(In) 0.0 dB     STEREO     (Out) 0.0 dB`
    private var levelsRow: some View {
        HStack(spacing: 0) {
            LevelPot(label: "In", value: $inputLevel, display: inputDisplay)
            Spacer(minLength: 8)
            Chip(text: effect.isMono ? "MONO" : "STEREO PROCESS", role: .inert, size: .small)
            Spacer(minLength: 8)
            LevelPot(label: "Out", value: $outputLevel, display: outputDisplay, trailing: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8 * uiScale)
    }

    @ViewBuilder
    private var body_parameters: some View {
        if parameterCount > 0 {
            ParameterScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    parameterField
                        .padding(.top, 14 * uiScale)
                        .padding(.bottom, 20 * uiScale)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { fieldHeight = $0 }

                    taglineBand
                    descriptionBlock
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
        } else {
            VStack(spacing: 0) {
                Text("This effect has no parameters")
                    .font(.system(size: 15 * uiScale))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28 * uiScale)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        taglineBand
                        descriptionBlock
                    }
                }
                .scrollIndicators(.automatic)
            }
        }
    }

    /// The parameter grid with the scrollpad strip on the chosen edge. The
    /// strip is a background so it tracks the grid's height exactly (a
    /// `maxHeight: .infinity` frame collapses inside a ScrollView), stopping
    /// one hatch line short of the last row. The grid keeps the usual edge
    /// inset on the strip-less side; on the strip side it clears the strip by
    /// `scrollpadGap`, and the strip itself touches the edge.
    /// Strip shows only when the field overflows its viewport (see the
    /// measured heights above). Both start at 0 before first layout, which
    /// reads as "fits" — no flash of a strip that then disappears.
    private var showsScrollpad: Bool {
        scrollpad != .off && viewportHeight > 0 && fieldHeight > viewportHeight
    }

    private var parameterField: some View {
        let stripWidth = Self.scrollpadWidth * uiScale
        let gap = Self.scrollpadGap * uiScale
        let edge = airwindowsEdgeInset(16, scale: uiScale)
        let strip = showsScrollpad
        return ParameterGrid(
            parameterCount: parameterCount,
            parameterNames: parameterNames,
            parameterDisplays: parameterDisplays,
            parameterLabels: parameterLabels,
            parameterValues: $parameterValues,
            parameterStepCounts: parameterStepCounts,
            parameterDefaults: parameterDefaults,
            useRotaryPots: useRotaryPots,
            maxSliderColumns: sliderColumnCap
        )
        .padding(.leading, strip && scrollpad == .left ? stripWidth + gap : edge)
        .padding(.trailing, strip && scrollpad == .right ? stripWidth + gap : edge)
        .background(alignment: scrollpad == .right ? .topTrailing : .topLeading) {
            if strip {
                ScrollHatchGutter()
                    .frame(width: stripWidth)
                    .padding(.bottom, ScrollHatchGutter.lineStep)
            }
        }
    }

    /// The tagline in its own centered band between two hairlines.
    @ViewBuilder
    private var taglineBand: some View {
        if !effect.whatText.isEmpty {
            hairline
            Text("\u{201C}\(effect.whatText)\u{201D}")
                // New York Regular Italic — the system serif (variable, so the
                // optical size follows the point size). Same face for every
                // quoted tagline in the plugin.
                .font(.system(size: 20 * uiScale, weight: .regular, design: .serif).italic())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 14 * uiScale)
            hairline
        }
    }

    @ViewBuilder
    private var descriptionBlock: some View {
        if shouldShowDescription {
            EffectDescriptionText(description, omittingHeadingMatching: effect.whatText)
                .hEdgePadding(16)
                .padding(.vertical, 16 * uiScale)
        }
    }

    private var shouldShowDescription: Bool {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagline = effect.whatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed != tagline
    }

    // MARK: Drawer

    private var menuDrawer: some View {
        CompactMenuDrawer(
            effectName: effect.name,
            onClose: closeMenu,
            onUndo: onUndo,
            onRedo: onRedo,
            canUndo: canUndo,
            canRedo: canRedo,
            isFavorite: favorites?.isFavorite(effect.name) ?? false,
            onToggleFavorite: favorites.map { store in { store.toggle(effect.name) } },
            onRandomize: closing(onRandomize),
            onReset: closing(onReset) ?? onReset,
            hasSavedSettings: hasSavedSettings,
            onSaveSettings: closing(onSaveSettings),
            onRecallSettings: closing(onRecallSettings),
            onClearSavedSettings: onClearSavedSettings,
            useRotaryPots: useRotaryPots,
            onToggleControlStyle: onToggleControlStyle,
            appearance: appearance,
            onCycleAppearance: onCycleAppearance,
            isMonitoring: isMonitoring,
            onToggleMonitoring: onToggleMonitoring,
            onOpenSettings: closing(onOpenSettings),
            onOpenAbout: closing(onOpenAbout),
            scrollpad: scrollpad,
            onCycleScrollpad: onCycleScrollpad,
            uiScale: uiScaleBinding,
            compactEverywhere: compactEverywhereBinding
        )
    }
}

// MARK: - Pieces

/// Chevron jog inside the compact title box. Dimmed and inert at the end of
/// the browse pool.
private struct JogChevron: View {
    enum Direction { case previous, next }
    let direction: Direction
    let enabled: Bool
    let targetName: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: direction == .previous ? "chevron.left" : "chevron.right")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(enabled ? Color.secondary : Color.secondary.opacity(0.3))
                .frame(width: 32, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(
            direction == .previous
                ? "Previous effect\(targetName.map { ", \($0)" } ?? "")"
                : "Next effect\(targetName.map { ", \($0)" } ?? "")"
        )
        .accessibilityHidden(!enabled)
    }
}

/// A small IN/OUT level pot with its caption and readout beside it rather
/// than above/below (the full header's arrangement is too tall here).
private struct LevelPot: View {
    let label: String
    @Binding var value: Double
    let display: String
    var trailing: Bool = false

    @Environment(\.uiScale) private var uiScale

    var body: some View {
        HStack(spacing: 8 * uiScale) {
            if trailing { readout }
            // Empty label + no valueText: the pot draws just its arc. Same
            // 0...2 range / unity default / detent as the full header.
            RotaryPot(
                value: $value,
                label: "",
                size: 34 * uiScale,
                defaultValue: 1.0,
                range: 0...2
            )
            if !trailing { readout }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) level, \(display)")
    }

    private var readout: some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 11 * uiScale))
                .foregroundStyle(.secondary)
            Text(display)
                .font(.system(size: 11 * uiScale).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .lineLimit(1)
    }
}

// MARK: - Preview

#Preview("Compact — 4 params") {
    CompactPreviewWrapper(paramCount: 4)
        .frame(width: 390, height: 640)
        .environment(\.containerSize, CGSize(width: 390, height: 640))
        .environment(\.layoutMode, .compact)
}

#Preview("Compact — 6 params, dark") {
    CompactPreviewWrapper(paramCount: 6, mono: true)
        .frame(width: 375, height: 560)
        .environment(\.containerSize, CGSize(width: 375, height: 560))
        .environment(\.layoutMode, .compact)
        .environment(\.colorScheme, .dark)
}

private struct CompactPreviewWrapper: View {
    let paramCount: Int
    var mono: Bool = false

    @State private var values: [Double] = Array(repeating: 0.5, count: 10)
    @State private var inLevel: Double = 1.0
    @State private var outLevel: Double = 1.0
    @State private var appearance: AirwindowsAppearance = .auto
    @State private var pots = false

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

        CompactWorkspaceView(
            effect: effect,
            parameterCount: paramCount,
            parameterNames: ["Cutoff", "Resonance", "Slope", "Dry/Wet", "Drive", "Tone"],
            parameterDisplays: (0..<paramCount).map { _ in "0.50" },
            parameterLabels: (0..<paramCount).map { _ in "" },
            description: """
            # Highpass
            Highpass rolls off the bottom of the spectrum without removing the warmth.
            Drag the cutoff to taste; resonance and slope shape the curve.
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
            onOpenBrowser: {},
            onReset: {},
            onRandomize: {},
            onUndo: {},
            onRedo: {},
            canUndo: true,
            appearance: appearance,
            onCycleAppearance: { appearance = appearance.next },
            useRotaryPots: pots,
            onToggleControlStyle: { pots.toggle() },
            onSaveSettings: {},
            onRecallSettings: {},
            onClearSavedSettings: {},
            onOpenSettings: {},
            onOpenAbout: {}
        )
    }
}
