//
//  BrowserView.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Full-screen effect picker. Launched by AirwindowsAUView at startup
//  and any time the user taps the title pill in HeaderStripView. On
//  select, hands a registry index back to the viewModel which then
//  swaps the active effect on the AU.
//

import SwiftUI

/// Three-column effect browser:
/// - left: SidebarView (collections, search, categories)
/// - middle: "Category (count)" header + "newest first" caption + numbered effect list
/// - right: large effect name + Select button top-right + tagline + metadata pills + description
public struct BrowserView: View {
    public let allEffects: [EffectBrowseModel]
    public let categories: [String]
    public let countsByCategory: [String: Int]
    public let initialHighlight: EffectBrowseModel?
    public let descriptionProvider: (EffectBrowseModel) -> String
    public let onSelect: (EffectBrowseModel) -> Void
    public let onClose: () -> Void
    /// Optional — drives the pinned "Favorites" pseudo-category in the sidebar
    /// and the star toggle in the preview pane.
    public let favorites: FavoritesStore?

    @Environment(\.colorScheme) private var scheme
    @State private var collection: EffectCollection = .all
    @State private var searchText: String = ""
    @State private var selectedCategory: String?
    @State private var highlighted: EffectBrowseModel?
    @State private var showAbout: Bool = false
    @State private var sortMode: EffectSortMode = .chrisOrdering

    /// Pseudo-category that shows the N most recently committed effects
    /// across the currently filtered pool. Lives only in the BrowserView —
    /// no upstream registry / override-layer change. Effects still appear in
    /// their natural category alongside their appearance in "New".
    private static let newCategoryName = "New"
    private static let newCategoryLimit = 8

    /// Sentinel `selectedCategory` value for the favorites pseudo-category.
    /// Chosen to never collide with a real category name or the "" all-sentinel.
    private static let favoritesCategoryName = "\u{2605} Favorites"

    public init(
        allEffects: [EffectBrowseModel],
        categories: [String],
        countsByCategory: [String: Int],
        initialCategory: String? = nil,
        initialHighlight: EffectBrowseModel? = nil,
        descriptionProvider: @escaping (EffectBrowseModel) -> String = { $0.whatText },
        favorites: FavoritesStore? = nil,
        onSelect: @escaping (EffectBrowseModel) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.allEffects = allEffects
        self.categories = categories
        self.countsByCategory = countsByCategory
        self.initialHighlight = initialHighlight
        self.descriptionProvider = descriptionProvider
        self.favorites = favorites
        self.onSelect = onSelect
        self.onClose = onClose
        // Treat empty string the same as nil — no category preselected.
        let cat = (initialCategory?.isEmpty == true) ? nil : initialCategory
        self._selectedCategory = State(initialValue: cat)
        self._highlighted = State(initialValue: initialHighlight)
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Left: sidebar
            SidebarView(
                collection: $collection,
                searchText: $searchText,
                selectedCategory: $selectedCategory,
                categories: visibleCategories,
                countsByCategory: effectiveCountsByCategory,
                totalCount: filteredAll.count,
                onClose: onClose,
                onAboutTap: { showAbout = true },
                onRandomTap: pickRandom,
                favoritesCount: favoriteEffects.count,
                isFavoritesSelected: selectedCategory == Self.favoritesCategoryName,
                onSelectFavorites: favorites == nil ? nil : {
                    selectedCategory = Self.favoritesCategoryName
                }
            )
            .frame(width: 280)

            Divider().opacity(0.4)

            // Middle: effect list — only shown once the user has made a pick
            // in the sidebar. "All categories" sets sentinel "", a specific
            // category sets its name, initial state is nil = nothing picked.
            if let cat = selectedCategory {
                EffectListColumn(
                    categoryLabel: middleColumnLabel(for: cat),
                    sortLabel: sortMode.rawValue,
                    effects: effectsInCurrentCategory,
                    groupedByCategory: isAllCategories && sortMode == .byCategory
                        ? groupedEffects : nil,
                    highlighted: $highlighted,
                    onPick: { effect in
                        onSelect(effect)
                        onClose()
                    },
                    onSortTap: {
                        sortMode = sortMode.next(allCategories: isAllCategories)
                    }
                )
                .frame(minWidth: 260, idealWidth: 310, maxWidth: 340)

                Divider().opacity(0.4)
            }

            // Right: preview pane — only show an effect once the user has
            // picked a category (selectedCategory != nil).
            EffectPreviewColumn(
                effect: selectedCategory != nil
                    ? (highlighted ?? effectsInCurrentCategory.first)
                    : nil,
                description: highlighted.flatMap { descriptionProvider($0) } ?? "",
                favorites: favorites,
                onSelect: { effect in
                    onSelect(effect)
                    onClose()
                }
            )
            .frame(maxWidth: .infinity)
        }
        .background(AirwindowsPalette.surface(scheme))
        .onAppear {
            // Pick up favorites changed by the other process (app ↔ plugin).
            favorites?.refresh()
        }
        .onChange(of: favoriteEffects.count) { _, newCount in
            // If the user un-stars their last favorite while viewing the
            // Favorites pseudo-category, fall back to "All categories" so the
            // middle column isn't an orphaned empty list.
            if newCount == 0, selectedCategory == Self.favoritesCategoryName {
                selectedCategory = ""
            }
        }
        .onChange(of: selectedCategory) { _, newCat in
            // "By category" sort only makes sense for "All categories"
            if newCat != "" && sortMode == .byCategory {
                sortMode = .chrisOrdering
            }
            // "New" pseudo-category defaults to newest-first; user can still
            // toggle the sort to re-order those 8 effects alphabetically etc.
            if newCat == Self.newCategoryName {
                sortMode = .newestFirst
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView(onClose: { showAbout = false })
                .environment(\.colorScheme, scheme)
        }
    }

    // MARK: - Filtering

    private var filteredAll: [EffectBrowseModel] {
        allEffects
            .filtered(by: collection)
            .matching(query: searchText)
    }

    private var visibleCategories: [String] {
        // Only show categories that have effects after the current filters,
        // preserving the canonical order from `categories`. The synthetic
        // "New" pseudo-category is pinned to the top whenever there's at
        // least one effect to draw from.
        let cats = Set(filteredAll.map(\.category))
        let real = categories.filter { cats.contains($0) }
        return filteredAll.isEmpty ? real : [Self.newCategoryName] + real
    }

    /// 8 newest effects (by firstCommitDate descending) within the current
    /// collection/search filter. Computed lazily; sort by date is a stable
    /// tie-break via `EffectSortMode.newestFirst`.
    private var newCategoryEffects: [EffectBrowseModel] {
        Array(filteredAll.sorted(by: .newestFirst).prefix(Self.newCategoryLimit))
    }

    /// Effects in the current filter pool that the user has favorited.
    /// Empty when there's no store. Drives both the sidebar row count and the
    /// favorites pseudo-category listing.
    private var favoriteEffects: [EffectBrowseModel] {
        guard let favorites else { return [] }
        return filteredAll.filter { favorites.isFavorite($0.name) }
    }

    private var effectsInCurrentCategory: [EffectBrowseModel] {
        let pool: [EffectBrowseModel]
        if selectedCategory == Self.favoritesCategoryName {
            pool = favoriteEffects
        } else if selectedCategory == Self.newCategoryName {
            // Pseudo-category: 8 newest. Re-applies the user-chosen sortMode
            // afterward so toggling alphabetical etc. still re-orders them.
            pool = newCategoryEffects
        } else if let cat = selectedCategory, !cat.isEmpty {
            // Specific category picked
            pool = filteredAll.filter { $0.category == cat }
        } else {
            // Empty string ("All categories") or nil → full pool
            pool = filteredAll
        }
        return pool.sorted(by: sortMode)
    }

    /// Counts table augmented with the synthetic "New" entry so the sidebar
    /// can render its row. Real-category counts come straight from the host.
    private var effectiveCountsByCategory: [String: Int] {
        var counts = countsByCategory
        counts[Self.newCategoryName] = min(Self.newCategoryLimit, filteredAll.count)
        return counts
    }

    private var isAllCategories: Bool {
        selectedCategory == ""
    }

    /// Effects grouped by category, each group sorted by Chris ordering.
    /// Only computed when "by category" sort is active on "All categories".
    private var groupedEffects: [(category: String, effects: [EffectBrowseModel])] {
        let grouped = Dictionary(grouping: filteredAll, by: \.category)
        return categories
            .filter { grouped[$0] != nil }
            .map { cat in
                (category: cat, effects: grouped[cat]!.sortedByChrisOrdering())
            }
    }

    private func middleColumnLabel(for selection: String) -> String {
        if selection.isEmpty {
            return "All effects (\(effectsInCurrentCategory.count))"
        }
        if selection == Self.favoritesCategoryName {
            return "Favorites (\(effectsInCurrentCategory.count))"
        }
        return "\(selection) (\(effectsInCurrentCategory.count))"
    }

    /// Pick a random effect from the current filtered pool (collection + search).
    /// Category selection is intentionally ignored so random stays surprising.
    private func pickRandom() {
        guard let picked = filteredAll.randomElement() else { return }
        onSelect(picked)
        onClose()
    }
}

// MARK: - Middle column: effect list

private struct EffectListColumn: View {
    let categoryLabel: String
    let sortLabel: String
    let effects: [EffectBrowseModel]
    let groupedByCategory: [(category: String, effects: [EffectBrowseModel])]?
    @Binding var highlighted: EffectBrowseModel?
    let onPick: (EffectBrowseModel) -> Void
    let onSortTap: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(categoryLabel)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)
                Button(action: onSortTap) {
                    HStack(spacing: 4) {
                        Text(sortLabel)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let groups = groupedByCategory {
                        ForEach(groups, id: \.category) { group in
                            // Category subheader
                            Text(group.category)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 22)
                                .padding(.top, 16)
                                .padding(.bottom, 6)

                            ForEach(Array(group.effects.enumerated()), id: \.element.registryIndex) { index, effect in
                                NumberedEffectRow(
                                    number: index + 1,
                                    effect: effect,
                                    isHighlighted: effect == highlighted
                                )
                                .onTapGesture {
                                    if highlighted == effect {
                                        onPick(effect)
                                    } else {
                                        highlighted = effect
                                    }
                                }
                            }
                        }
                    } else {
                        ForEach(Array(effects.enumerated()), id: \.element.registryIndex) { index, effect in
                            NumberedEffectRow(
                                number: index + 1,
                                effect: effect,
                                isHighlighted: effect == highlighted
                            )
                            .onTapGesture {
                                if highlighted == effect {
                                    onPick(effect)
                                } else {
                                    highlighted = effect
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 18)
            }
        }
        .background(AirwindowsPalette.surface(scheme))
        .onAppear {
            if highlighted == nil {
                highlighted = effects.first
            }
        }
        .onChange(of: effects) { _, newValue in
            if let h = highlighted, !newValue.contains(h) {
                highlighted = newValue.first
            } else if highlighted == nil {
                highlighted = newValue.first
            }
        }
    }
}

private struct NumberedEffectRow: View {
    let number: Int
    let effect: EffectBrowseModel
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number).")
                .font(.system(size: 20, weight: .regular).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)

            Text(effect.name)
                .font(.system(size: 20, weight: isHighlighted ? .semibold : .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 7)
        .background(isHighlighted ? Color.primary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Right column: preview pane

private struct EffectPreviewColumn: View {
    let effect: EffectBrowseModel?
    let description: String
    let favorites: FavoritesStore?
    let onSelect: (EffectBrowseModel) -> Void

    var body: some View {
        if let effect {
            VStack(alignment: .leading, spacing: 0) {
                // Header row: name + favorite star + Select button
                HStack(alignment: .firstTextBaseline) {
                    Text(effect.name)
                        .font(.system(size: 40, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Spacer()

                    if let favorites {
                        let isFav = favorites.isFavorite(effect.name)
                        Button {
                            favorites.toggle(effect.name)
                        } label: {
                            Image(systemName: isFav ? "star.fill" : "star")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(isFav ? Color.primary : Color.secondary)
                                .frame(width: 40, height: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFav ? "Remove \(effect.name) from favorites" : "Add \(effect.name) to favorites")
                    }

                    Button {
                        onSelect(effect)
                    } label: {
                        Text("Select")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(AirwindowsPalette.actionButton)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 28)
                .padding(.horizontal, 28)

                if !effect.whatText.isEmpty {
                    Text("\u{201C}\(effect.whatText)\u{201D}")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 28)
                        .padding(.top, 14)
                }

                // Metadata pills — always shows at least Mono/Stereo.
                FlowMetaRow(effect: effect)
                    .padding(.horizontal, 28)
                    .padding(.top, 19)

                // Full description. Scroll indicator forced visible so users
                // realize there's more content below the fold (the default
                // SwiftUI behavior only flashes the indicator on scroll).
                ScrollView {
                    // Leading `# ` line renders as a heading; see EffectDescriptionText.
                    EffectDescriptionText(description.isEmpty ? effect.whatText : description)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 20)
                }
                .scrollIndicators(.visible)

                // External link chips — sit just below the description text.
                // Only render when the effect has a matching airwindows.com post
                // or YouTube video (13 effects have neither and show no chips).
                if effect.postURL != nil || effect.videoURL != nil {
                    HStack(spacing: 8) {
                        if let post = effect.postURL {
                            LinkChip(
                                url: post,
                                systemName: "safari",
                                text: "blog post",
                                accessibility: "Read blog post on airwindows.com"
                            )
                        }
                        if let video = effect.videoURL {
                            LinkChip(
                                url: video,
                                systemName: "play.rectangle",
                                text: "youtube video",
                                accessibility: "Watch video on YouTube"
                            )
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack {
                Spacer()
                Text("No effect selected")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct FlowMetaRow: View {
    let effect: EffectBrowseModel

    var body: some View {
        // Category and parameter-count pills removed: the category is already
        // visible in the sidebar and the middle-column header, and the raw
        // parameter count isn't useful info for most users (may be revisited
        // as a more visual indicator later). Mono/Stereo always shows one or
        // the other — every effect is one of those two, so neither is a
        // meaningful "default" to leave unmarked.
        HStack(spacing: 8) {
            MetaPill(text: effect.isMono ? "Mono" : "Stereo")
            if !effect.firstCommitDate.isEmpty {
                MetaPill(text: effect.firstCommitDate)
            }
        }
    }
}

private struct MetaPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(Color.secondary.opacity(0.1))
            )
    }
}

// MARK: - Preview

#Preview("Browser") {
    BrowserView(
        allEffects: EffectBrowseModel.sampleEffects,
        categories: EffectBrowseModel.sampleCategories,
        countsByCategory: [
            "Filter": 47,
            "Reverb": 36,
            "Consoles": 45,
            "Tape": 12
        ],
        initialCategory: "Filter",
        onSelect: { _ in },
        onClose: {}
    )
    .frame(width: 1100, height: 700)
}
