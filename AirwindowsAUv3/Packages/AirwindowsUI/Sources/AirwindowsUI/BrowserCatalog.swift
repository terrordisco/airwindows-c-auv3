//
//  BrowserCatalog.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The effect browser's model logic, pulled out of BrowserView so the full
//  three-column browser and the compact drill-down (CompactBrowserView)
//  answer every question the same way: which categories are visible under
//  the current filters, what the "New" and "★ Favorites" pseudo-categories
//  contain, what the current list is, and what navigation pool a pick hands
//  back to the workspace for prev/next.
//
//  Both views share one `BrowserContext` (owned by AirwindowsAUView), and the
//  pseudo-category sentinels stored in `context.selectedCategory` live here
//  so neither view can drift from the other.
//
//  Pure value type: build it from the inputs, ask it questions. No state.
//

import Foundation

struct BrowserCatalog {
    let allEffects: [EffectBrowseModel]
    /// Canonical category order (alphabetical, from the bridge).
    let categories: [String]
    let countsByCategory: [String: Int]
    let context: BrowserContext
    let favorites: FavoritesStore?

    // MARK: Sentinels

    /// Pseudo-category showing the N most recently committed effects across
    /// the currently filtered pool. Lives only in the browser — no upstream
    /// registry / override-layer change. Effects still appear in their
    /// natural category alongside their appearance in "New".
    static let newCategoryName = "New"
    static let newCategoryLimit = 30

    /// Sentinel `selectedCategory` value for the favorites pseudo-category.
    /// Chosen to never collide with a real category name or the "" all-sentinel.
    static let favoritesCategoryName = "\u{2605} Favorites"

    /// `selectedCategory == ""` means "All categories".
    static let allCategoriesName = ""

    // MARK: Pools

    /// Everything that survives the collection filter and the search text.
    var filteredAll: [EffectBrowseModel] {
        allEffects
            .filtered(by: context.collection)
            .matching(query: context.searchText)
    }

    /// Categories that still have effects under the current filters, in
    /// canonical order, with the synthetic "New" pinned on top whenever there
    /// is at least one effect to draw from.
    var visibleCategories: [String] {
        let cats = Set(filteredAll.map(\.category))
        let real = categories.filter { cats.contains($0) }
        return filteredAll.isEmpty ? real : [Self.newCategoryName] + real
    }

    /// The `newCategoryLimit` newest effects (by firstCommitDate descending)
    /// within the current filter.
    var newCategoryEffects: [EffectBrowseModel] {
        Array(filteredAll.sorted(by: .newestFirst).prefix(Self.newCategoryLimit))
    }

    /// Effects in the current filter pool the user has starred. Empty when
    /// there is no store.
    var favoriteEffects: [EffectBrowseModel] {
        guard let favorites else { return [] }
        return filteredAll.filter { favorites.isFavorite($0.name) }
    }

    /// The list for the selected category (real or pseudo), in the current
    /// sort order. nil / "" selection → the whole filtered pool.
    var effectsInCurrentCategory: [EffectBrowseModel] {
        let pool: [EffectBrowseModel]
        switch context.selectedCategory {
        case Self.favoritesCategoryName?:
            pool = favoriteEffects
        case Self.newCategoryName?:
            pool = newCategoryEffects
        case let cat? where !cat.isEmpty:
            pool = filteredAll.filter { $0.category == cat }
        default:
            pool = filteredAll
        }
        return pool.sorted(by: context.sortMode)
    }

    /// The ordered list the browser is currently showing — handed to
    /// `onSelect` so prev/next on the effect page walk the same list the user
    /// picked from. In "by category" grouping the flat sort order differs
    /// from the visual order, so flatten the groups instead.
    var navigationPool: [EffectBrowseModel] {
        if isAllCategories && context.sortMode == .byCategory {
            return groupedEffects.flatMap(\.effects)
        }
        return effectsInCurrentCategory
    }

    /// Counts table augmented with the synthetic "New" entry.
    var effectiveCountsByCategory: [String: Int] {
        var counts = countsByCategory
        counts[Self.newCategoryName] = min(Self.newCategoryLimit, filteredAll.count)
        return counts
    }

    var isAllCategories: Bool {
        context.selectedCategory == Self.allCategoriesName
    }

    /// Effects grouped by category, each group in Chris ordering. Only
    /// meaningful for "by category" sort on "All categories".
    var groupedEffects: [(category: String, effects: [EffectBrowseModel])] {
        let grouped = Dictionary(grouping: filteredAll, by: \.category)
        return categories
            .filter { grouped[$0] != nil }
            .map { cat in
                (category: cat, effects: grouped[cat]!.sortedByChrisOrdering())
            }
    }

    /// Human label for a selection: "All effects", "Favorites", or the
    /// category name. Count is appended by the caller as it sees fit.
    func title(for selection: String) -> String {
        if selection.isEmpty { return "All Effects" }
        if selection == Self.favoritesCategoryName { return "Favorites" }
        return selection
    }

    /// A random effect from the current filtered pool (collection + search).
    /// Category selection is intentionally ignored so random stays surprising.
    func randomEffect() -> EffectBrowseModel? {
        filteredAll.randomElement()
    }
}
