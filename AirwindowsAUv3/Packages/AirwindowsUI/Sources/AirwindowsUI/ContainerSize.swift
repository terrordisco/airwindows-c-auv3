//
//  ContainerSize.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Environment plumbing for the live size (in points) of the box the host
//  gave the plugin — AUM window, GarageBand strip, Logic tile, or the
//  standalone app's own window.
//
//  Today this exists as a research instrument: PreferencesView shows the
//  value so we (and beta testers) can read real host dimensions straight off
//  each DAW, feeding the responsive-design work (rack-height / thin-strip
//  layout modes). Later, the same value is what those layout modes will be
//  derived from.
//
//  Injected at the root by AirwindowsAUView from its GeometryReader, the same
//  pattern as \.uiScale. Like uiScale, it must be re-applied explicitly on
//  sheets and fullScreenCovers — they don't reliably inherit custom
//  environment values.
//

import SwiftUI

private struct ContainerSizeKey: EnvironmentKey {
    /// .zero = "not injected" (e.g. a bare preview). Views showing the value
    /// should hide it when zero rather than print "0 × 0".
    static let defaultValue: CGSize = .zero
}

public extension EnvironmentValues {
    /// The plugin container's current size in points. See file header.
    var containerSize: CGSize {
        get { self[ContainerSizeKey.self] }
        set { self[ContainerSizeKey.self] = newValue }
    }
}
