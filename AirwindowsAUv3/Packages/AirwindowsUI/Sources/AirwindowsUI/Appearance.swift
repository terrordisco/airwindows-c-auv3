//
//  Appearance.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The plugin's Day / Night / Auto appearance setting. Historically this was
//  a single Bool (`airwindows.darkMode`, light by default, ignoring the
//  host). The compact-mode menu introduced a third state, Auto, which follows
//  whatever colour scheme the host hands us (AUM is dark, GarageBand is
//  light). The Bool is kept only to migrate existing installs — see
//  `AirwindowsAppearance.migratingLegacy`.
//

import SwiftUI

public enum AirwindowsAppearance: String, CaseIterable, Sendable {
    /// Follow the host's colour scheme.
    case auto
    /// Always dark.
    case night
    /// Always light.
    case day

    /// UserDefaults key for the persisted raw value. Lives in `.standard`
    /// (per-process, like the legacy Bool) — appearance is a per-host choice
    /// as much as a global one, so it deliberately isn't App-Group-shared.
    public static let storageKey = "airwindows.appearance"

    /// Legacy Bool key this setting replaced.
    public static let legacyDarkModeKey = "airwindows.darkMode"

    /// Resolves to the concrete scheme to render with, given the scheme the
    /// host is currently showing.
    public func resolvedScheme(host: ColorScheme) -> ColorScheme {
        switch self {
        case .auto: return host
        case .night: return .dark
        case .day: return .light
        }
    }

    /// Tap-to-cycle order used by the menu drawer's Night Mode row:
    /// Auto → Night → Day → Auto.
    public var next: AirwindowsAppearance {
        switch self {
        case .auto: return .night
        case .night: return .day
        case .day: return .auto
        }
    }

    /// Short label for the menu indicator.
    public var label: String {
        switch self {
        case .auto: return "Auto"
        case .night: return "Night"
        case .day: return "Day"
        }
    }

    /// Reads the stored appearance, migrating from the legacy Bool on first
    /// use. A fresh install (neither key present) starts on Auto. An existing
    /// install keeps looking exactly as it did: its Bool becomes Night or Day.
    public static func migratingLegacy(from defaults: UserDefaults = .standard) -> AirwindowsAppearance {
        if let raw = defaults.string(forKey: storageKey),
           let stored = AirwindowsAppearance(rawValue: raw) {
            return stored
        }
        let migrated: AirwindowsAppearance
        if defaults.object(forKey: legacyDarkModeKey) == nil {
            migrated = .auto
        } else {
            migrated = defaults.bool(forKey: legacyDarkModeKey) ? .night : .day
        }
        defaults.set(migrated.rawValue, forKey: storageKey)
        return migrated
    }
}
