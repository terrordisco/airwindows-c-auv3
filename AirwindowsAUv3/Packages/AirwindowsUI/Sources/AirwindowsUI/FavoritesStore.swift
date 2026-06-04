//
//  FavoritesStore.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Persists the user's favorited effects (by effect name) in an App Group
//  container, so a star set in the standalone app shows up inside the AUv3
//  plugin running in a host — and vice versa.
//
//  WHY APP GROUP, NOT PLAIN UserDefaults
//  -------------------------------------
//  The app and the extension are two separate processes with two separate
//  `UserDefaults.standard` domains. An App Group gives them one shared suite
//  (`group.com.terrordisco.airwindows.consolidated`) that both can read and
//  write. The matching entitlement is on both targets in project.yml.
//
//  CROSS-PROCESS FRESHNESS
//  -----------------------
//  Each process caches its view of the suite, and modern iOS no longer
//  delivers live KVO across processes. That's fine for this use: the two
//  surfaces are rarely both on-screen at once, and `refresh()` re-reads the
//  container (call it when a browsing surface appears) so the other process's
//  changes are picked up the next time you look. Within a single process the
//  `@Observable` state updates the UI immediately.
//

import Foundation
import Observation

/// Observable set of favorited effect names, backed by an App Group suite.
@Observable
public final class FavoritesStore {
    /// Shared App Group suite. Must match the `com.apple.security.application-groups`
    /// entitlement on both the app and the extension.
    public static let appGroupSuite = "group.com.terrordisco.airwindows.consolidated"

    private static let storageKey = "airwindows.favorites"

    private let defaults: UserDefaults

    /// Favorited effect names. Effects are keyed by name (not registry index)
    /// because the index can shift between upstream syncs, but the name is the
    /// stable identity users recognize.
    public private(set) var names: Set<String>

    /// - Parameter suiteName: App Group suite to persist into. Falls back to
    ///   `.standard` when the suite can't be opened (e.g. previews, or a macOS
    ///   build with no group container) so the UI still works in-memory.
    public init(suiteName: String? = FavoritesStore.appGroupSuite) {
        let resolved = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        self.defaults = resolved
        let stored = resolved.array(forKey: Self.storageKey) as? [String] ?? []
        self.names = Set(stored)
    }

    public func isFavorite(_ name: String) -> Bool {
        names.contains(name)
    }

    /// Adds or removes a favorite and writes through to the container.
    public func toggle(_ name: String) {
        guard !name.isEmpty else { return }
        if names.contains(name) {
            names.remove(name)
        } else {
            names.insert(name)
        }
        persist()
    }

    /// Re-read the container to pick up changes made by the other process.
    /// Call when a browsing surface appears.
    public func refresh() {
        let stored = defaults.array(forKey: Self.storageKey) as? [String] ?? []
        let updated = Set(stored)
        if updated != names {
            names = updated
        }
    }

    private func persist() {
        defaults.set(Array(names), forKey: Self.storageKey)
    }
}
