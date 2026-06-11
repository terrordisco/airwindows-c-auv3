//
//  Chip.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The single chip primitive for the whole plugin. It replaces a drawer full of
//  one-off chip designs (a stroked rounded-rect MONO marker, a solid-filled
//  action chip, a stroked link chip, a capsule filter tab, a capsule meta pill,
//  the capsule Select button) — each of which had drifted to its own corner
//  radius, fill, and metrics.
//
//  Two rules unify them:
//    1. Corners are ALWAYS a fixed-radius rounded rectangle (never a capsule),
//       at one radius across every size — so the corner *appearance* is uniform.
//    2. **Fill encodes "active."** Outline is the resting state for everything;
//       a solid/tinted fill means a toggle is ON or a chip is the primary
//       call-to-action. Inert (display-only) chips are the faintest of all.
//
//  A chip's *role* picks its look; its *size* picks only type + padding. All
//  tokens are multiplied by `\.uiScale` so chips scale with the rest of the UI.
//

import SwiftUI

// MARK: - Role & size

/// What a chip *is* — drives its visual emphasis under the "fill = active" rule.
public enum ChipRole: Equatable {
    /// Non-interactive display (MONO/STEREO, date). Also the look an `.action`
    /// falls back to when disabled. Faintest outline, never presses.
    case inert
    /// A momentary command — Reset, Random, a blog link, or a mode switch like
    /// Day/Night whose label names the destination. Outline, pressable.
    case action
    /// A persistent on/off filter (the sidebar collection tabs). Outline when
    /// off; a faint fill when on.
    case toggle(isOn: Bool)
    /// The one accent-filled call-to-action (Select). Solid accent, white label.
    case primary
}

/// Size token. The corner radius is identical across sizes (see the file note),
/// so only the font, icon, and padding change here.
public enum ChipSize {
    case small      // compact marker — MONO/STEREO
    case regular    // default
    case large      // primary CTA — Select
}

// MARK: - Chip

/// One chip. Supply an optional icon, optional label, a `role`, and a `size`.
/// Pass `action` for interactive roles; `.inert` ignores it and renders as a
/// plain (non-button) view. An optional `longPressAction` adds a secondary
/// hold gesture (used by Recall settings → clear); tap and hold are exclusive,
/// so a long press never also fires the tap.
public struct Chip: View {
    private let systemName: String?
    private let text: String?
    private let role: ChipRole
    private let size: ChipSize
    private let isEnabled: Bool
    private let accessibility: String?
    private let action: (() -> Void)?
    private let longPressAction: (() -> Void)?

    @Environment(\.uiScale) private var uiScale

    public init(
        systemName: String? = nil,
        text: String? = nil,
        role: ChipRole,
        size: ChipSize = .regular,
        isEnabled: Bool = true,
        accessibility: String? = nil,
        action: (() -> Void)? = nil,
        longPressAction: (() -> Void)? = nil
    ) {
        self.systemName = systemName
        self.text = text
        self.role = role
        self.size = size
        self.isEnabled = isEnabled
        self.accessibility = accessibility
        self.action = action
        self.longPressAction = longPressAction
    }

    public var body: some View {
        let visual = ChipVisual(role: role, isEnabled: isEnabled)

        if visual.interactive, let action, let longPressAction {
            // Gesture-based variant: .onTapGesture and .onLongPressGesture
            // compose exclusively (a hold never also fires the tap), which a
            // Button + simultaneous long-press gesture does not guarantee.
            label(visual)
                .opacity(visual.opacity)
                .onTapGesture(perform: action)
                .onLongPressGesture(perform: longPressAction)
                .accessibilityAddTraits(.isButton)
                .modify { applyAccessibility($0) }
        } else if visual.interactive, let action {
            Button(action: action) { label(visual) }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
                .opacity(visual.opacity)
                .modify { applyAccessibility($0) }
        } else {
            label(visual)
                .opacity(visual.opacity)
                .modify { applyAccessibility($0) }
        }
    }

    // MARK: Pieces

    private func label(_ visual: ChipVisual) -> some View {
        HStack(spacing: 6 * uiScale) {
            if let systemName {
                Image(systemName: systemName)
                    .font(.system(size: metrics.iconSize * uiScale, weight: metrics.weight))
            }
            if let text {
                Text(text)
                    .font(.system(size: metrics.fontSize * uiScale, weight: metrics.weight))
                    .kerning(metrics.kerning)
            }
        }
        .foregroundStyle(visual.foreground)
        .padding(.horizontal, metrics.padH * uiScale)
        .padding(.vertical, metrics.padV * uiScale)
        .background(
            RoundedRectangle(cornerRadius: Self.cornerRadius * uiScale, style: .continuous)
                .fill(visual.fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius * uiScale, style: .continuous)
                .stroke(visual.stroke, lineWidth: visual.strokeWidth)
        )
        .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius * uiScale, style: .continuous))
    }

    @ViewBuilder
    private func applyAccessibility<V: View>(_ view: V) -> some View {
        if let accessibility {
            if case .toggle(let isOn) = role {
                view.accessibilityLabel(accessibility)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
            } else {
                view.accessibilityLabel(accessibility)
            }
        } else {
            view
        }
    }

    // MARK: Tokens

    /// One radius for every chip, every size — the whole point of the unifier.
    private static let cornerRadius: CGFloat = 8

    private var metrics: ChipMetrics {
        switch size {
        case .small:   return ChipMetrics(fontSize: 13, iconSize: 13, weight: .semibold, padH: 8, padV: 4, kerning: 0.5)
        case .regular: return ChipMetrics(fontSize: 14, iconSize: 15, weight: .medium, padH: 10, padV: 6, kerning: 0)
        case .large:   return ChipMetrics(fontSize: 17, iconSize: 17, weight: .semibold, padH: 20, padV: 10, kerning: 0)
        }
    }
}

// MARK: - Resolved look

private struct ChipMetrics {
    let fontSize: CGFloat
    let iconSize: CGFloat
    let weight: Font.Weight
    let padH: CGFloat
    let padV: CGFloat
    let kerning: CGFloat
}

/// The concrete colors/stroke/opacity a (role, enabled) pair resolves to.
/// Centralizing it here is what guarantees every chip of the same nature looks
/// identical no matter where it's used.
private struct ChipVisual {
    let foreground: Color
    let fill: Color
    let stroke: Color
    let strokeWidth: CGFloat
    let opacity: Double
    let interactive: Bool

    init(role: ChipRole, isEnabled: Bool) {
        switch role {
        case .inert:
            foreground = .secondary
            fill = .clear
            stroke = Color.secondary.opacity(0.22)
            strokeWidth = 1
            opacity = 1
            interactive = false

        case .action:
            if isEnabled {
                foreground = .primary
                fill = .clear
                stroke = Color.secondary.opacity(0.32)
                strokeWidth = 1
                opacity = 1
                interactive = true
            } else {
                // A disabled action reads as inert — the look the user grouped
                // with MONO and a fresh (empty-stack) Undo/Redo.
                foreground = .secondary
                fill = .clear
                stroke = Color.secondary.opacity(0.2)
                strokeWidth = 1
                opacity = 0.4
                interactive = false
            }

        case .toggle(let isOn):
            if isOn {
                foreground = .primary
                fill = Color.secondary.opacity(0.16)   // fill = active
                stroke = Color.secondary.opacity(0.3)
                strokeWidth = 1
            } else {
                foreground = .secondary
                fill = .clear
                stroke = Color.secondary.opacity(0.24)
                strokeWidth = 1
            }
            opacity = 1
            interactive = true

        case .primary:
            foreground = .white
            fill = AirwindowsPalette.actionButton
            stroke = .clear
            strokeWidth = 0
            opacity = isEnabled ? 1 : 0.4
            interactive = isEnabled
        }
    }
}

// MARK: - Small helper

private extension View {
    /// Apply a transform that returns a different concrete view type.
    func modify<V: View>(_ transform: (Self) -> V) -> V { transform(self) }
}
