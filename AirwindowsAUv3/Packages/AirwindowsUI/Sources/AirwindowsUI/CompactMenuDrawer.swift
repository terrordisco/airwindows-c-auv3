//
//  CompactMenuDrawer.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The right-hand menu drawer of the compact layout. In `.full` mode the
//  workspace's actions are spread along the bottom bar as chips; in
//  `.compact` mode there is no room for that, so every action collects here,
//  behind the hamburger button at the top right of CompactWorkspaceView.
//
//  Order and copy follow the 2026-09-28 design canvas, top to bottom:
//
//      [ Undo | Redo ]                       paired, most-used first
//      Add to favorites / Remove from favorites
//      Randomize settings
//      Reset settings
//      Remember settings   →  Recall settings + Forget saved settings
//      ─────
//      Pots / Sliders      [switch]
//      Night Mode          Auto / Night / Day
//      ─────
//      Airwindows Settings…
//      About Airwindows
//
//  Every action is optional (nil hides its row) so the same gating the
//  bottom bar uses — personalisation toggle, app-only monitoring — applies
//  here unchanged. The drawer is chrome, not content, so its metrics are
//  fixed points rather than `uiScale`-multiplied; it reads like an OS sheet.
//

import SwiftUI

public struct CompactMenuDrawer: View {
    public let effectName: String
    public let onClose: () -> Void

    // Edit history
    public let onUndo: (() -> Void)?
    public let onRedo: (() -> Void)?
    public let canUndo: Bool
    public let canRedo: Bool

    // This effect
    public let isFavorite: Bool
    public let onToggleFavorite: (() -> Void)?
    /// Startup-effect pin (same store the browser's pin button writes). nil
    /// hides the row (personalisation off).
    public let isDefaultEffect: Bool
    public let onToggleDefaultEffect: (() -> Void)?
    public let onRandomize: (() -> Void)?
    /// Safety limiter switch, shown indented under Randomize Settings (it's
    /// there for the wild values Randomize can produce). nil hides the row.
    public let isLimiterOn: Bool
    public let onToggleLimiter: (() -> Void)?
    public let onReset: () -> Void
    public let hasSavedSettings: Bool
    public let onSaveSettings: (() -> Void)?
    public let onRecallSettings: (() -> Void)?
    public let onClearSavedSettings: (() -> Void)?

    // View
    public let useRotaryPots: Bool
    public let onToggleControlStyle: (() -> Void)?
    /// "Long Press to Lock" — enables the long-press gesture that locks a
    /// parameter against Randomize / Reset. Shown indented under Randomize
    /// Settings, next to the Limiter. nil hides the row.
    public let isLongPressLockOn: Bool
    public let onToggleLongPressLock: (() -> Void)?
    public let appearance: AirwindowsAppearance
    public let onCycleAppearance: () -> Void
    /// App-only input monitoring (mic → effect → speaker). nil in the AUv3.
    public let isMonitoring: Bool
    public let onToggleMonitoring: (() -> Void)?

    // Elsewhere
    public let onOpenSettings: (() -> Void)?
    public let onOpenAbout: (() -> Void)?

    // Scrollpad edge
    public let scrollpad: ScrollpadPlacement
    public let onCycleScrollpad: () -> Void

    // The global interface scale, moved in from the Preferences sheet
    // (Sveinbjörn, 2026-09-30). Personalisation and the window-size readout
    // stay in the sheet behind "Airwindows Settings…". A binding straight onto
    // the shared @AppStorage key, so dragging the slider rescales the live
    // workspace behind the drawer. nil hides the row (previews).
    public let uiScale: Binding<Double>?

    @Environment(\.colorScheme) private var scheme
    @State private var showClearSavedSettingsDialog = false

    public init(
        effectName: String,
        onClose: @escaping () -> Void,
        onUndo: (() -> Void)? = nil,
        onRedo: (() -> Void)? = nil,
        canUndo: Bool = false,
        canRedo: Bool = false,
        isFavorite: Bool = false,
        onToggleFavorite: (() -> Void)? = nil,
        isDefaultEffect: Bool = false,
        onToggleDefaultEffect: (() -> Void)? = nil,
        onRandomize: (() -> Void)? = nil,
        isLimiterOn: Bool = false,
        onToggleLimiter: (() -> Void)? = nil,
        onReset: @escaping () -> Void,
        hasSavedSettings: Bool = false,
        onSaveSettings: (() -> Void)? = nil,
        onRecallSettings: (() -> Void)? = nil,
        onClearSavedSettings: (() -> Void)? = nil,
        useRotaryPots: Bool = false,
        onToggleControlStyle: (() -> Void)? = nil,
        isLongPressLockOn: Bool = false,
        onToggleLongPressLock: (() -> Void)? = nil,
        appearance: AirwindowsAppearance = .auto,
        onCycleAppearance: @escaping () -> Void = {},
        isMonitoring: Bool = false,
        onToggleMonitoring: (() -> Void)? = nil,
        onOpenSettings: (() -> Void)? = nil,
        onOpenAbout: (() -> Void)? = nil,
        scrollpad: ScrollpadPlacement = .left,
        onCycleScrollpad: @escaping () -> Void = {},
        uiScale: Binding<Double>? = nil
    ) {
        self.effectName = effectName
        self.onClose = onClose
        self.onUndo = onUndo
        self.onRedo = onRedo
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.isFavorite = isFavorite
        self.onToggleFavorite = onToggleFavorite
        self.isDefaultEffect = isDefaultEffect
        self.onToggleDefaultEffect = onToggleDefaultEffect
        self.onRandomize = onRandomize
        self.isLimiterOn = isLimiterOn
        self.onToggleLimiter = onToggleLimiter
        self.onReset = onReset
        self.hasSavedSettings = hasSavedSettings
        self.onSaveSettings = onSaveSettings
        self.onRecallSettings = onRecallSettings
        self.onClearSavedSettings = onClearSavedSettings
        self.useRotaryPots = useRotaryPots
        self.onToggleControlStyle = onToggleControlStyle
        self.isLongPressLockOn = isLongPressLockOn
        self.onToggleLongPressLock = onToggleLongPressLock
        self.appearance = appearance
        self.onCycleAppearance = onCycleAppearance
        self.isMonitoring = isMonitoring
        self.onToggleMonitoring = onToggleMonitoring
        self.onOpenSettings = onOpenSettings
        self.onOpenAbout = onOpenAbout
        self.scrollpad = scrollpad
        self.onCycleScrollpad = onCycleScrollpad
        self.uiScale = uiScale
    }

    // Fixed chrome metrics (see file header for why these don't scale).
    static let rowHeight: CGFloat = 48
    static let hInset: CGFloat = 20
    static let iconColumn: CGFloat = 22
    static let iconGap: CGFloat = 14

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 0) {
                    if onUndo != nil || onRedo != nil {
                        undoRedoPair
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                    }

                    effectSection
                    sectionDivider
                    viewSection
                    if onOpenSettings != nil || onOpenAbout != nil {
                        sectionDivider
                        elsewhereSection
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
        }
        // Background and edge hairline extend through the safe area so the
        // drawer reads as one sheet from the very top to the very bottom of
        // the container; the rows themselves stay inside the safe area.
        .background(AirwindowsPalette.surface(scheme).ignoresSafeArea())
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(AirwindowsPalette.divider(scheme))
                .frame(width: 1)
                .ignoresSafeArea()
        }
        // Swipe the drawer off toward its edge to close it.
        .onHorizontalSwipe { swipe in
            if swipe == .right { onClose() }
        }
        .alert("Forget the saved settings for \(effectName)?", isPresented: $showClearSavedSettingsDialog) {
            Button("Forget", role: .destructive) {
                onClearSavedSettings?()
            }
            Button("Cancel", role: .cancel) {}
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Menu")
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Text(effectName)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            CompactChromeButton(systemName: "xmark", accessibility: "Close menu", action: onClose)
        }
        .padding(.leading, Self.hInset)
        .padding(.trailing, 12)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    /// Undo and Redo share one outlined pill, split down the middle — a pair,
    /// not two unrelated rows. Each half dims and goes inert when its stack
    /// is empty.
    private var undoRedoPair: some View {
        HStack(spacing: 0) {
            if let onUndo {
                pairHalf(systemName: "arrow.uturn.backward", title: "Undo", enabled: canUndo, action: onUndo)
            }
            if onUndo != nil, onRedo != nil {
                Rectangle()
                    .fill(AirwindowsPalette.divider(scheme))
                    .frame(width: 1)
            }
            if let onRedo {
                pairHalf(systemName: "arrow.uturn.forward", title: "Redo", enabled: canRedo, action: onRedo)
            }
        }
        .frame(height: 44)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func pairHalf(systemName: String, title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 15))
            }
            .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var effectSection: some View {
        if let onToggleFavorite {
            MenuRow(
                systemName: isFavorite ? "star.fill" : "star",
                title: isFavorite ? "Remove from Favorites" : "Add to Favorites",
                action: onToggleFavorite
            )
        }
        if let onToggleDefaultEffect {
            MenuRow(
                systemName: isDefaultEffect ? "pin.fill" : "pin",
                title: isDefaultEffect ? "Remove as Default Effect" : "Make This the Default Effect",
                action: onToggleDefaultEffect
            )
        }
        if let onRandomize {
            MenuRow(systemName: "dice", title: "Randomize Settings", action: onRandomize)
            if let onToggleLimiter {
                MenuRow(systemName: "waveform.badge.exclamationmark",
                        titleView: { Text("Limiter") },
                        trailing: { StyleSwitchGlyph(isOn: isLimiterOn) },
                        indented: true,
                        accessibility: isLimiterOn ? "Limiter on. Tap to turn off." : "Limiter off. Tap to turn on.",
                        action: onToggleLimiter)
            }
            // Parameter locks are what you set up so Randomize leaves some
            // controls alone, so the switch lives under Randomize too.
            if let onToggleLongPressLock {
                MenuRow(systemName: "lock",
                        titleView: { Text("Long Press to Lock") },
                        trailing: { StyleSwitchGlyph(isOn: isLongPressLockOn) },
                        indented: true,
                        accessibility: isLongPressLockOn
                            ? "Long press to lock a parameter, on. Tap to turn off."
                            : "Long press to lock a parameter, off. Tap to turn on.",
                        action: onToggleLongPressLock)
            }
        }
        MenuRow(systemName: "arrow.counterclockwise", title: "Reset Settings", action: onReset)

        // Per-effect saved settings. The effect always loads factory defaults;
        // once a snapshot exists the row becomes "Recall settings" and a
        // secondary "Forget saved settings" row appears under it (the drawer
        // replaces the full-mode chip's long-press with a visible row).
        if let onSaveSettings, let onRecallSettings, onClearSavedSettings != nil {
            if hasSavedSettings {
                MenuRow(systemName: "bookmark.fill", title: "Recall Settings", action: onRecallSettings)
                MenuRow(
                    systemName: "bookmark.slash",
                    title: "Forget Saved Settings",
                    isSecondary: true,
                    action: { showClearSavedSettingsDialog = true }
                )
            } else {
                MenuRow(systemName: "bookmark", title: "Remember Settings", action: onSaveSettings)
            }
        }
    }

    @ViewBuilder
    private var viewSection: some View {
        if let onToggleControlStyle {
            MenuRow(systemName: useRotaryPots ? "dial.medium" : "slider.horizontal.below.rectangle",
                    titleView: {
                        // "Pots / Sliders" with the active style in primary ink.
                        HStack(spacing: 0) {
                            Text("Pots").foregroundStyle(useRotaryPots ? Color.primary : Color.secondary.opacity(0.6))
                            Text(" / ").foregroundStyle(Color.secondary.opacity(0.6))
                            Text("Sliders").foregroundStyle(useRotaryPots ? Color.secondary.opacity(0.6) : Color.primary)
                        }
                    },
                    trailing: { StyleSwitchGlyph(isOn: !useRotaryPots) },
                    accessibility: useRotaryPots ? "Switch parameter controls to sliders" : "Switch parameter controls to pots",
                    action: onToggleControlStyle)
        }

        MenuRow(systemName: appearance == .day ? "sun.max" : "moon",
                titleView: { Text("Night Mode") },
                trailing: { ChoiceIndicator(options: AirwindowsAppearance.allCases.map(\.label), current: appearance.label) },
                accessibility: "Night mode, \(appearance.label). Tap to change.",
                action: onCycleAppearance)

        MenuRow(systemName: scrollpad == .right ? "inset.filled.righthalf.rectangle" : "inset.filled.lefthalf.rectangle",
                titleView: { Text("Scrollpad") },
                trailing: { ChoiceIndicator(options: ScrollpadPlacement.allCases.map(\.label), current: scrollpad.label) },
                accessibility: "Scrollpad, \(scrollpad.label). Tap to change.",
                action: onCycleScrollpad)

        if let uiScale {
            ScaleRow(scale: uiScale)
        }

        if let onToggleMonitoring {
            MenuRow(systemName: isMonitoring ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    titleView: { Text("Input Monitoring") },
                    trailing: {
                        Text(isMonitoring ? "Live" : "Muted")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    },
                    accessibility: isMonitoring ? "Mute input monitoring" : "Start input monitoring",
                    action: onToggleMonitoring)
        }
    }

    @ViewBuilder
    private var elsewhereSection: some View {
        if let onOpenSettings {
            MenuRow(systemName: "gearshape", title: "Airwindows Settings…", action: onOpenSettings)
        }
        if let onOpenAbout {
            MenuRow(systemName: "info.circle", title: "About Airwindows", action: onOpenAbout)
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(AirwindowsPalette.divider(scheme))
            .frame(height: 1)
            .padding(.vertical, 6)
    }
}

// MARK: - Rows

/// One drawer row: leading SF Symbol in a fixed column, title, optional
/// trailing indicator pushed to the right edge. `isSecondary` renders a
/// dependent sub-action (Forget saved settings) in secondary ink.
private struct MenuRow<Title: View, Trailing: View>: View {
    let systemName: String
    let titleView: () -> Title
    let trailing: () -> Trailing
    let isSecondary: Bool
    /// Indented one icon-column to read as a child of the row above it
    /// (the Limiter switch under Randomize Settings).
    let indented: Bool
    let accessibility: String?
    let action: () -> Void

    init(
        systemName: String,
        @ViewBuilder titleView: @escaping () -> Title,
        @ViewBuilder trailing: @escaping () -> Trailing,
        isSecondary: Bool = false,
        indented: Bool = false,
        accessibility: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.titleView = titleView
        self.trailing = trailing
        self.isSecondary = isSecondary
        self.indented = indented
        self.accessibility = accessibility
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CompactMenuDrawer.iconGap) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: CompactMenuDrawer.iconColumn)
                titleView()
                    .font(.system(size: 15))
                    .foregroundStyle(isSecondary ? Color.secondary : Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                trailing()
            }
            .padding(.leading, CompactMenuDrawer.hInset + (indented ? CompactMenuDrawer.iconColumn + CompactMenuDrawer.iconGap : 0))
            .padding(.trailing, CompactMenuDrawer.hInset)
            .frame(height: CompactMenuDrawer.rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility ?? "")
    }
}

private extension MenuRow where Title == Text, Trailing == EmptyView {
    init(systemName: String, title: String, isSecondary: Bool = false, action: @escaping () -> Void) {
        self.init(
            systemName: systemName,
            titleView: { Text(title) },
            trailing: { EmptyView() },
            isSecondary: isSecondary,
            accessibility: title,
            action: action
        )
    }
}

/// Interface-scale row: icon, label, live percentage, and the slider on its
/// own line beneath so it has the full drawer width to travel. Bounds and
/// the 100% reference come from UIScaleConfig, same as the Preferences sheet.
private struct ScaleRow: View {
    @Binding var scale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: CompactMenuDrawer.iconGap) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: CompactMenuDrawer.iconColumn)
                Text("Interface Scale")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text("\(Int((scale * 100).rounded()))%")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: $scale,
                in: Double(UIScaleConfig.minimum)...Double(UIScaleConfig.maximum),
                step: 0.01
            )
            .tint(Color.primary)
            .padding(.leading, CompactMenuDrawer.iconColumn + CompactMenuDrawer.iconGap)
            .accessibilityLabel("Interface scale")
            .accessibilityValue("\(Int((scale * 100).rounded())) percent")
        }
        .padding(.horizontal, CompactMenuDrawer.hInset)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

/// "A / B / C" choice indicator (Night Mode's Auto / Night / Day, the
/// Scrollpad's Left / Right / Off). The current choice is primary ink, the
/// others are dimmed; the separators stay dim.
private struct ChoiceIndicator: View {
    let options: [String]
    let current: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                if i > 0 {
                    Text(" / ").foregroundStyle(Color.secondary.opacity(0.6))
                }
                Text(option)
                    .foregroundStyle(option == current ? Color.primary : Color.secondary.opacity(0.6))
            }
        }
        .font(.system(size: 12))
        .accessibilityHidden(true)
    }
}

/// Small switch-shaped glyph for the Pots / Sliders row: knob LEFT for pots,
/// RIGHT for sliders — it tracks the "Pots / Sliders" label order to its
/// left, so the knob sits under the word that's active. Purely indicative —
/// the whole row is the button.
private struct StyleSwitchGlyph: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .stroke(Color.secondary.opacity(0.7), lineWidth: 1.5)
                .frame(width: 34, height: 20)
            Circle()
                .fill(Color.primary)
                .frame(width: 13, height: 13)
                .padding(.horizontal, 3.5)
        }
        .animation(.easeOut(duration: 0.15), value: isOn)
        .accessibilityHidden(true)
    }
}

// MARK: - Shared chrome metrics

/// Metrics shared by the compact layout's chrome (workspace header, drawer
/// headers).
enum CompactChrome {
    /// Extra top inset so a header's left-hand button clears the window
    /// controls iPadOS (Stage Manager) paints over the top-left of a
    /// standalone window — about 28pt tall. Only on iPad, and only when the
    /// container is tall enough to afford it; a short rack (host strip,
    /// iPhone landscape) has no window controls and can't spare the height.
    static let windowControlsClearance: CGFloat = 26
    static let windowControlsClearanceMinHeight: CGFloat = 420

    static func headerTopInset(containerHeight: CGFloat, base: CGFloat = 12) -> CGFloat {
        #if canImport(UIKit)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        #else
        let isPad = true
        #endif
        return isPad && containerHeight >= windowControlsClearanceMinHeight
            ? base + windowControlsClearance
            : base
    }
}

// MARK: - Shared chrome button

/// The 40pt outlined square button used for the compact header's browser and
/// menu buttons and the drawers' close buttons. Fixed chrome size.
struct CompactChromeButton: View {
    let systemName: String
    let accessibility: String
    let action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(AirwindowsPalette.surface(scheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }
}

// MARK: - Preview

#Preview("Menu drawer") {
    CompactMenuDrawer(
        effectName: "Highpass",
        onClose: {},
        onUndo: {},
        onRedo: {},
        canUndo: true,
        canRedo: false,
        isFavorite: false,
        onToggleFavorite: {},
        onRandomize: {},
        onReset: {},
        hasSavedSettings: true,
        onSaveSettings: {},
        onRecallSettings: {},
        onClearSavedSettings: {},
        useRotaryPots: false,
        onToggleControlStyle: {},
        appearance: .auto,
        onCycleAppearance: {},
        onOpenSettings: {},
        onOpenAbout: {}
    )
    .frame(width: 300, height: 640)
}
