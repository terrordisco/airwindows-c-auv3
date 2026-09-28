//
//  LayoutMode.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Discrete layout modes layered on top of the continuous `uiScale`.
//  `uiScale` makes everything proportionally smaller; a layout mode changes
//  the *arrangement* — which chrome exists at all and where it lives.
//
//    - `.full`     the iPad workspace as designed on a 13": header strip with
//                  named jog labels, bottom bar with chips + Settings box,
//                  three-column browser.
//    - `.compact`  narrow or short containers (Split View, Slide Over, a
//                  GarageBand strip, an iPhone). One header row with a
//                  browser button on the left and a menu button on the
//                  right; every action collects in the right-hand menu
//                  drawer. See CompactWorkspaceView.
//
//  Derived from the container size at the AirwindowsAUView root (the same
//  GeometryReader that feeds `\.containerSize`) and injected as
//  `\.layoutMode`. Like the other custom environment values it has to be
//  re-applied on sheets and fullScreenCovers.
//

import SwiftUI

public enum LayoutMode: Equatable, Sendable {
    case full
    case compact
}

public enum LayoutModeConfig {
    /// Containers narrower than this are compact. 600 pt catches iPad Split
    /// View at one third (320), Slide Over (320–375), a half-width Split View
    /// on a 13" (≈507), and every iPhone in portrait. Design call from the
    /// 2026-09-28 compact-mode review; retune when tester container sizes
    /// come in (see the container-size research item in ROADMAP).
    public static let compactMaxWidth: CGFloat = 600

    /// Containers shorter than this are compact regardless of width — the
    /// "short rack" case (GarageBand's effect strip, small AUM windows, an
    /// iPhone in landscape).
    public static let compactMaxHeight: CGFloat = 360

    /// UserDefaults key (App-Group-shared) for the "compact layout at every
    /// size" switch in Preferences. While it's on, the size thresholds are
    /// ignored and every container gets the compact arrangement — added so
    /// the compact design can be judged on a full 13" workspace, not only in
    /// Split View. Default ON for the 2026-09-28 review build.
    public static let compactEverywhereKey = "airwindows.compactEverywhere"
    public static let compactEverywhereDefault = true

    /// Picks the layout mode for a container. A zero/garbage size (SwiftUI's
    /// pre-layout proposals) resolves to `.full` so nothing flashes compact
    /// on the way in. `compactEverywhere` short-circuits the thresholds.
    public static func mode(for size: CGSize, compactEverywhere: Bool = false) -> LayoutMode {
        guard size.width > 1, size.height > 1 else { return compactEverywhere ? .compact : .full }
        if compactEverywhere { return .compact }
        if size.width < compactMaxWidth || size.height < compactMaxHeight {
            return .compact
        }
        return .full
    }
}

private struct LayoutModeKey: EnvironmentKey {
    static let defaultValue: LayoutMode = .full
}

public extension EnvironmentValues {
    /// The current discrete layout mode. See file header.
    var layoutMode: LayoutMode {
        get { self[LayoutModeKey.self] }
        set { self[LayoutModeKey.self] = newValue }
    }
}
