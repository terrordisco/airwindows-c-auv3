//
//  UIScale.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Global UI-scale factor. The plugin's sized "design tokens" (font sizes,
//  control diameters, spacing, grid column widths) are all multiplied by this
//  value so the whole workspace scales proportionally as one piece. A smaller
//  scale fits more on screen — so an 8.3" iPad can show the same parameter
//  density a 13" does at 100%.
//
//  The value is owned by `@AppStorage("airwindows.uiScale")` and injected into
//  the environment once at the AirwindowsAUView root; sized views read it via
//  `@Environment(\.uiScale)`. 1.0 == the sizing tuned on a 13" iPad, so the
//  reference device sees no change at the default.
//

import SwiftUI

// MARK: - Environment

private struct UIScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

public extension EnvironmentValues {
    /// Global UI-scale multiplier. 1.0 == reference (13") sizing.
    var uiScale: CGFloat {
        get { self[UIScaleKey.self] }
        set { self[UIScaleKey.self] = newValue }
    }
}

// MARK: - Calibration

/// Shared calibration for the global UI scale: the clamp range, the reference
/// device, the iPad guide marks shown under the Preferences slider, and the
/// auto-match-on-first-launch mapping. Kept in one place so the slider and the
/// auto-default can't drift apart.
public enum UIScaleConfig {
    /// 100% — exactly the sizing tuned on a 13" iPad. The default, and the
    /// value at which the reference device is unchanged.
    public static let reference: CGFloat = 1.0

    /// Slider bounds. Below `min` controls get too small to hit; above `max`
    /// the 13" workspace just wastes space.
    public static let minimum: CGFloat = 0.65
    public static let maximum: CGFloat = 1.25

    /// Short-side point width of the reference 13" iPad (1024 pt). A device or
    /// container's short side divided by this gives the scale at which it shows
    /// roughly 13"-equivalent density — the basis for both the guide marks and
    /// the auto-match default.
    public static let referenceShortSide: CGFloat = 1024

    /// iPad guide marks for the Preferences slider, as (label, scale) pairs.
    /// Each scale is that iPad's short-side points ÷ 1024, i.e. the setting at
    /// which it matches 13" density. Used purely as on-slider signposts.
    public static let deviceGuides: [(label: String, scale: CGFloat)] = [
        ("8.3\"", 744.0 / 1024.0),   // iPad mini    ≈ 0.73
        ("11\"", 834.0 / 1024.0),    // iPad 11"/Air ≈ 0.81
        ("13\"", 1.0)                // reference
    ]

    /// Clamp an arbitrary scale into the supported range.
    public static func clamp(_ value: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }

    /// Auto-match default for a fresh install: map the container's short side
    /// to a proportional scale so a smaller iPad starts out showing the same
    /// density as the 13". Container-based (not `UIScreen`) because that's the
    /// only signal available in an AUv3 app extension, and it adapts to the
    /// host's window too. The user can still override via the slider.
    public static func autoScale(forShortSide shortSide: CGFloat) -> CGFloat {
        clamp(shortSide / referenceShortSide)
    }
}

// MARK: - Shared preference store

public extension UserDefaults {
    /// App Group store for cross-instance preferences (the UI scale). Uses the
    /// SAME suite as FavoritesStore so a scale set in the standalone app — or in
    /// one AUv3 instance — is shared by every instance. Falls back to `.standard`
    /// if the group container can't be opened (previews / misconfig).
    ///
    /// Within one process, instances sharing this store update live via KVO.
    /// Across processes (app ↔ plugin, or separate hosts) the value persists and
    /// is picked up on the next launch/appear — modern iOS doesn't deliver live
    /// cross-process KVO (same caveat as FavoritesStore).
    static let airwindowsShared: UserDefaults =
        UserDefaults(suiteName: FavoritesStore.appGroupSuite) ?? .standard
}

// MARK: - Edge padding

/// A side (left/right) edge inset that is half fixed, half scaled:
/// `base/2 + base/2 × scale`. Fully scaling the side insets lets content crowd
/// the panel edge at small scales; holding half the inset constant guarantees a
/// minimum margin while still tightening as the UI shrinks. At 100% it equals
/// `base`. Used both as a raw value (for layout math like the slider gutter)
/// and via the `hEdgePadding` modifier.
public func airwindowsEdgeInset(_ base: CGFloat, scale: CGFloat) -> CGFloat {
    base * 0.5 + base * 0.5 * scale
}

public extension View {
    /// Applies `airwindowsEdgeInset` as horizontal padding, reading the current
    /// `\.uiScale`. Use for pane-edge insets so content keeps a margin from the
    /// edge at small scales.
    func hEdgePadding(_ base: CGFloat) -> some View {
        modifier(HorizontalEdgePadding(base: base))
    }
}

private struct HorizontalEdgePadding: ViewModifier {
    let base: CGFloat
    @Environment(\.uiScale) private var uiScale

    func body(content: Content) -> some View {
        content.padding(.horizontal, airwindowsEdgeInset(base, scale: uiScale))
    }
}

// MARK: - Fixed layout constants

/// Layout dimensions that are deliberately NOT affected by `uiScale` — they
/// belong to the plugin's chrome, not its scalable content. Keeping them in
/// one place lets surfaces that must align (the browser sidebar and the
/// workspace bottom bar's Settings box) share a single source of truth.
public enum AirwindowsLayout {
    /// Width of the browser's left sidebar column, and — matched to it on
    /// purpose — the workspace bottom bar's Settings box. The two surfaces
    /// echo each other, so a user moving between browser and workspace sees
    /// the same left-column width in both. Fixed: it's structural chrome.
    public static let sidebarWidth: CGFloat = 280
}
