//
//  ActionButton.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The button: the one primitive for anything that RUNS A FUNCTION — Select,
//  Random Effect, the blog / video links, the collection filter toggles. Blue
//  (the palette's action colour), Title Case label, rounded rectangle. It is
//  deliberately NOT derived from `Chip`: chips are non-interactive markers,
//  and the two have independent metrics so one can be tuned without moving
//  the other (Sveinbjörn, 2026-09-30). It starts life at 200% of a chip.
//
//  Roles:
//    .filled           solid blue, white label — the default; a command.
//    .toggle(isOn:)    a persistent on/off (filter tabs): solid blue when on,
//                      blue outline when off.
//    .outlined         a lesser command — blue outline, blue label.
//
//  Disabled buttons dim and stop responding. All tokens scale with `\.uiScale`.
//

import SwiftUI

public enum ActionButtonRole: Equatable {
    case filled
    case outlined
    case toggle(isOn: Bool)
}

public enum ActionButtonSize {
    case regular
    case large
}

public struct ActionButton: View {
    private let systemName: String?
    private let text: String?
    private let role: ActionButtonRole
    private let size: ActionButtonSize
    private let isEnabled: Bool
    private let accessibility: String?
    private let action: () -> Void

    @Environment(\.uiScale) private var uiScale

    public init(
        systemName: String? = nil,
        text: String? = nil,
        role: ActionButtonRole = .filled,
        size: ActionButtonSize = .regular,
        isEnabled: Bool = true,
        accessibility: String? = nil,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.text = text
        self.role = role
        self.size = size
        self.isEnabled = isEnabled
        self.accessibility = accessibility
        self.action = action
    }

    public var body: some View {
        let look = ActionButtonLook(role: role)
        Button(action: action) {
            HStack(spacing: 7 * uiScale) {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: metrics.iconSize * uiScale, weight: .semibold))
                }
                if let text {
                    Text(text)
                        .font(.system(size: metrics.fontSize * uiScale, weight: .semibold))
                }
            }
            .foregroundStyle(look.foreground)
            .padding(.horizontal, metrics.padH * uiScale)
            .padding(.vertical, metrics.padV * uiScale)
            .background(
                RoundedRectangle(cornerRadius: Self.cornerRadius * uiScale, style: .continuous)
                    .fill(look.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Self.cornerRadius * uiScale, style: .continuous)
                    .stroke(look.stroke, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius * uiScale, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(accessibility ?? text ?? "")
        .modifier(SelectedTrait(isSelected: { if case .toggle(true) = role { return true }; return false }()))
    }

    // MARK: Tokens (independent of Chip's — do not link)

    private static let cornerRadius: CGFloat = 10

    private var metrics: ChipMetrics {
        switch size {
        case .regular: return ChipMetrics(fontSize: 18, iconSize: 20, weight: .semibold, padH: 14, padV: 8, kerning: 0)
        case .large:   return ChipMetrics(fontSize: 22, iconSize: 24, weight: .semibold, padH: 28, padV: 14, kerning: 0)
        }
    }
}

private struct ActionButtonLook {
    let foreground: Color
    let fill: Color
    let stroke: Color

    init(role: ActionButtonRole) {
        let blue = AirwindowsPalette.actionButton
        switch role {
        case .filled, .toggle(isOn: true):
            foreground = .white; fill = blue; stroke = .clear
        case .outlined, .toggle(isOn: false):
            foreground = blue; fill = .clear; stroke = blue.opacity(0.7)
        }
    }
}

private struct SelectedTrait: ViewModifier {
    let isSelected: Bool
    func body(content: Content) -> some View {
        if isSelected { content.accessibilityAddTraits(.isSelected) } else { content }
    }
}

// MARK: - Preview

#Preview("Buttons") {
    VStack(alignment: .leading, spacing: 14) {
        ActionButton(text: "Select", action: {})
        ActionButton(systemName: "dice", text: "Random Effect", role: .outlined, action: {})
        HStack {
            ActionButton(text: "Recommended", role: .toggle(isOn: true), action: {})
            ActionButton(text: "Basic", role: .toggle(isOn: false), action: {})
        }
        ActionButton(text: "Select", size: .large, action: {})
        ActionButton(text: "Disabled", isEnabled: false, action: {})
    }
    .padding(24)
}
