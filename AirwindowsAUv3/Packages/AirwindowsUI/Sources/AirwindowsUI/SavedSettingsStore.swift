//
//  SavedSettingsStore.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Persists one saved parameter snapshot per effect (keyed by effect name)
//  in the App Group container — the storage behind the "Save settings" /
//  "Recall settings" chip in the workspace.
//
//  DESIGN (Sveinbjörn's spec)
//  --------------------------
//  An effect ALWAYS starts from factory settings; the saved snapshot is only
//  applied when the user taps "Recall settings". One snapshot per effect:
//  saving again (after a clear) replaces it. Long-press on Recall offers to
//  clear the snapshot, returning the chip to "Save settings".
//
//  Same App Group + cross-process freshness story as FavoritesStore: the two
//  processes (app / plugin) share the suite, `refresh()` re-reads it when a
//  surface appears, and `@Observable` keeps a single process live. Values are
//  the effect's normalized 0...1 parameter values in slot order — In/Out
//  levels are deliberately not part of the snapshot (same scope as Reset and
//  Randomize).
//

import Foundation
import Observation

/// Observable per-effect saved parameter snapshots, backed by an App Group suite.
@Observable
public final class SavedSettingsStore {
    private static let storageKey = "airwindows.savedSettings"

    private let defaults: UserDefaults

    /// Saved snapshots keyed by effect name. Name, not registry index, because
    /// the index can shift between upstream syncs (same rule as favorites).
    public private(set) var settingsByEffect: [String: [Double]]

    /// - Parameter suiteName: App Group suite to persist into. Falls back to
    ///   `.standard` when the suite can't be opened (previews) so the UI still
    ///   works in-memory.
    public init(suiteName: String? = FavoritesStore.appGroupSuite) {
        let resolved = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        self.defaults = resolved
        self.settingsByEffect = Self.read(from: resolved)
    }

    public func hasSaved(_ name: String) -> Bool {
        settingsByEffect[name] != nil
    }

    public func savedValues(for name: String) -> [Double]? {
        settingsByEffect[name]
    }

    /// Saves a snapshot for the effect, replacing any previous one.
    public func save(_ values: [Double], for name: String) {
        guard !name.isEmpty else { return }
        settingsByEffect[name] = values
        persist()
    }

    /// Removes the effect's snapshot (the long-press-clear path).
    public func clear(_ name: String) {
        guard settingsByEffect[name] != nil else { return }
        settingsByEffect.removeValue(forKey: name)
        persist()
    }

    /// Re-read the container to pick up changes made by the other process.
    /// Call when the workspace (re)appears.
    public func refresh() {
        let updated = Self.read(from: defaults)
        if updated != settingsByEffect {
            settingsByEffect = updated
        }
    }

    private func persist() {
        defaults.set(settingsByEffect, forKey: Self.storageKey)
    }

    private static func read(from defaults: UserDefaults) -> [String: [Double]] {
        defaults.dictionary(forKey: storageKey) as? [String: [Double]] ?? [:]
    }
}
