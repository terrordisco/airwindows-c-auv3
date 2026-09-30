//
//  ParameterLockStore.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Per-effect parameter locks. A locked parameter keeps its value through
//  Randomize Settings and Reset Settings (you can still move it by hand —
//  the lock protects the value you chose, it doesn't disable the control).
//  Toggled by a long press on the fader/pot when the "Long Press to Lock"
//  setting is on; locked controls draw dimmed with a small padlock.
//
//  Keyed by effect NAME (like favorites) so locks survive upstream registry
//  index shifts, and App-Group-backed so app and plugin instances agree.
//

import Foundation
import Observation

@Observable
public final class ParameterLockStore {
    private static let storageKey = "airwindows.parameterLocks"

    private let defaults: UserDefaults

    /// effect name → locked parameter indices
    public private(set) var locks: [String: Set<Int>]

    public init(suiteName: String? = FavoritesStore.appGroupSuite) {
        let resolved = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        self.defaults = resolved
        self.locks = Self.load(from: resolved)
    }

    public func locked(for effectName: String) -> Set<Int> {
        locks[effectName] ?? []
    }

    public func isLocked(_ effectName: String, index: Int) -> Bool {
        locks[effectName]?.contains(index) ?? false
    }

    public func toggle(_ effectName: String, index: Int) {
        guard !effectName.isEmpty else { return }
        var set = locks[effectName] ?? []
        if set.contains(index) { set.remove(index) } else { set.insert(index) }
        if set.isEmpty { locks.removeValue(forKey: effectName) } else { locks[effectName] = set }
        persist()
    }

    public func refresh() {
        let updated = Self.load(from: defaults)
        if updated != locks { locks = updated }
    }

    private static func load(from defaults: UserDefaults) -> [String: Set<Int>] {
        let raw = defaults.dictionary(forKey: storageKey) as? [String: [Int]] ?? [:]
        return raw.mapValues { Set($0) }
    }

    private func persist() {
        defaults.set(locks.mapValues { Array($0).sorted() }, forKey: Self.storageKey)
    }
}
