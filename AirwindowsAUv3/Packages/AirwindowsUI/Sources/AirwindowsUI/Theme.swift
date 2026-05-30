//
//  Theme.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Static palette consumed by every view in this package via
//  AirwindowsPalette.surface(scheme) and friends. The dark/light toggle
//  in EffectDetailView's header chip drives @Environment(\.colorScheme),
//  which is what flips these calls between modes.
//

import SwiftUI

/// Static palette that adapts to `ColorScheme`.
///
/// Views in this package read `@Environment(\.colorScheme)` and call
/// `AirwindowsPalette.surface(scheme)` etc. for adaptive backgrounds.
/// Text colors remain `.primary` / `.secondary` and adapt automatically
/// from `colorScheme`.
///
/// Accent colors (cyan category selection, blue Select button) are fixed
/// across both themes because they already read well on both.
public enum AirwindowsPalette {
    /// Main card / workspace background.
    public static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.10, green: 0.10, blue: 0.11)
            : Color.white
    }

    /// Secondary surface — sidebar, outer shell.
    public static func subtleSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.14, green: 0.14, blue: 0.15)
            : Color(white: 0.98)
    }

    /// Hairline divider visible on both schemes.
    public static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.08)
    }

    /// Category selection accent (cyan). Same in both themes.
    public static let accent = Color(red: 0.32, green: 0.68, blue: 0.88)

    /// Primary action button (Select). Same in both themes.
    public static let actionButton = Color(red: 0.13, green: 0.45, blue: 0.96)

    /// Per-category dot colors — subtle cycle, same in both themes but
    /// slightly desaturated to read on either background.
    public static let categoryDotPalette: [Color] = [
        Color(red: 0.36, green: 0.72, blue: 0.88),   // cyan
        Color(red: 0.92, green: 0.55, blue: 0.35),   // coral
        Color(red: 0.44, green: 0.71, blue: 0.48),   // sage
        Color(red: 0.85, green: 0.68, blue: 0.30),   // mustard
        Color(red: 0.60, green: 0.52, blue: 0.82),   // lavender
        Color(red: 0.88, green: 0.42, blue: 0.58),   // rose
        Color(red: 0.45, green: 0.55, blue: 0.70)    // slate
    ]

    public static func categoryDot(at index: Int) -> Color {
        categoryDotPalette[index % categoryDotPalette.count]
    }
}
