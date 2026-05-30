//
//  EffectBrowseModel.swift
//  AirwindowsUI package
//
//  Data layer for the browser. Three things live here:
//
//    EffectBrowseModel    Value-type mirror of the bridge's
//                         AirwindowsEffectInfo. Pure Swift so the UI
//                         package can build, test, and SwiftUI-preview
//                         without depending on AirwindowsDSP / ObjC.
//
//    Array filters + sorts   The "filter by collection", "filter by
//                         search query", and various sort modes used by
//                         BrowserView + SidebarView.
//
//    Sample data         Hand-curated effects + categories used by
//                         #Preview blocks. Lives in the same file so it
//                         stays close to the model definition.
//

import Foundation

/// Pure-Swift, dependency-free mirror of the bridge's `AirwindowsEffectInfo`.
///
/// Lives in `AirwindowsUI` so previewable views can take real data without
/// pulling in the heavy `AirwindowsDSP` framework. The extension target maps
/// `AirwindowsEffectInfo` (Obj-C) → `EffectBrowseModel` at the boundary.
public struct EffectBrowseModel: Identifiable, Hashable, Sendable {
    public let registryIndex: Int
    public let name: String
    public let category: String
    public let whatText: String
    public let nParams: Int
    public let isMono: Bool
    public let catChrisOrdering: Int
    public let firstCommitDate: String
    public let collections: [String]
    public let postURL: URL?
    public let videoURL: URL?

    public var id: Int { registryIndex }

    public init(
        registryIndex: Int,
        name: String,
        category: String,
        whatText: String,
        nParams: Int,
        isMono: Bool,
        catChrisOrdering: Int,
        firstCommitDate: String,
        collections: [String],
        postURL: URL? = nil,
        videoURL: URL? = nil
    ) {
        self.registryIndex = registryIndex
        self.name = name
        self.category = category
        self.whatText = whatText
        self.nParams = nParams
        self.isMono = isMono
        self.catChrisOrdering = catChrisOrdering
        self.firstCommitDate = firstCommitDate
        self.collections = collections
        self.postURL = postURL
        self.videoURL = videoURL
    }
}

// MARK: - Collections / Sorting

public enum EffectCollection: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case recommended = "Recommended"
    case basic = "Basic"
    case latest = "Latest"

    public var id: String { rawValue }
}

extension Array where Element == EffectBrowseModel {
    /// Filter by collection. `.all` returns the array unchanged.
    public func filtered(by collection: EffectCollection) -> [EffectBrowseModel] {
        switch collection {
        case .all:
            return self
        default:
            return filter { $0.collections.contains(collection.rawValue) }
        }
    }

    /// Filter by case-insensitive substring across name, category, and whatText.
    public func matching(query: String) -> [EffectBrowseModel] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return self }
        let q = trimmed.lowercased()
        return filter {
            $0.name.lowercased().contains(q)
                || $0.category.lowercased().contains(q)
                || $0.whatText.lowercased().contains(q)
        }
    }

    /// Sort by Chris ordering (lower = newer/preferred), name as tiebreaker.
    public func sortedByChrisOrdering() -> [EffectBrowseModel] {
        sorted { lhs, rhs in
            if lhs.catChrisOrdering != rhs.catChrisOrdering {
                return lhs.catChrisOrdering < rhs.catChrisOrdering
            }
            return lhs.name < rhs.name
        }
    }

    /// Sort by the chosen mode.
    public func sorted(by mode: EffectSortMode) -> [EffectBrowseModel] {
        switch mode {
        case .chrisOrdering:
            return sortedByChrisOrdering()
        case .newestFirst:
            return sorted { lhs, rhs in
                // Descending date (newest first), name as tiebreaker
                if lhs.firstCommitDate != rhs.firstCommitDate {
                    return lhs.firstCommitDate > rhs.firstCommitDate
                }
                return lhs.name < rhs.name
            }
        case .alphabetical:
            return sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .byCategory:
            // When used as a flat list fallback, sort by category then Chris ordering
            return sorted { lhs, rhs in
                if lhs.category != rhs.category {
                    return lhs.category < rhs.category
                }
                if lhs.catChrisOrdering != rhs.catChrisOrdering {
                    return lhs.catChrisOrdering < rhs.catChrisOrdering
                }
                return lhs.name < rhs.name
            }
        }
    }
}

/// Sort modes for the effect list column.
public enum EffectSortMode: String, CaseIterable, Sendable {
    case chrisOrdering = "recommended"
    case newestFirst = "newest first"
    case alphabetical = "alphabetical"
    case byCategory = "by category"

    /// The next mode when tapping the header to cycle.
    /// `allCategories`: if true, includes the "by category" mode.
    public func next(allCategories: Bool) -> EffectSortMode {
        switch self {
        case .chrisOrdering: return .newestFirst
        case .newestFirst: return .alphabetical
        case .alphabetical: return allCategories ? .byCategory : .chrisOrdering
        case .byCategory: return .chrisOrdering
        }
    }
}

// MARK: - Sample data for previews

extension EffectBrowseModel {
    public static let sampleHighpass = EffectBrowseModel(
        registryIndex: 0,
        name: "Highpass",
        category: "Filter",
        whatText: "an analog-feel highpass filter that doesn't kill the lows",
        nParams: 4,
        isMono: false,
        catChrisOrdering: 12,
        firstCommitDate: "2018-04-12",
        collections: ["Recommended", "Basic"]
    )

    public static let sampleEffects: [EffectBrowseModel] = [
        sampleHighpass,
        EffectBrowseModel(
            registryIndex: 1,
            name: "Galactic3",
            category: "Reverb",
            whatText: "wide, lush plate-like reverb tuned for vocals and pads",
            nParams: 6,
            isMono: false,
            catChrisOrdering: 1,
            firstCommitDate: "2024-08-12",
            collections: ["Recommended", "Latest"]
        ),
        EffectBrowseModel(
            registryIndex: 2,
            name: "Console7Channel",
            category: "Consoles",
            whatText: "the channel side of the Console7 mixing system",
            nParams: 1,
            isMono: false,
            catChrisOrdering: 7,
            firstCommitDate: "2020-02-03",
            collections: ["Recommended"]
        ),
        EffectBrowseModel(
            registryIndex: 3,
            name: "ToTape6",
            category: "Tape",
            whatText: "warm, musical tape saturation with bias and flutter",
            nParams: 5,
            isMono: false,
            catChrisOrdering: 3,
            firstCommitDate: "2023-11-04",
            collections: ["Recommended", "Latest"]
        )
    ]

    public static let sampleCategories: [String] = [
        "Filter", "Consoles", "Reverb", "Utility", "Dynamics", "Effects",
        "Brightness", "Ambience", "Tape", "Saturation"
    ]
}
