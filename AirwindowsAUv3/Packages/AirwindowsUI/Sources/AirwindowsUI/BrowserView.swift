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

/// The user's place in the browser — which category they're viewing, plus the
/// collection filter, search text and sort order. Owned by the workspace view
/// (AirwindowsAUView) and passed into BrowserView as a binding, so the state
/// survives the browser being dismissed and re-presented: returning to the
/// browser lands exactly where the user left off instead of being reset to
/// the active effect's category.
public struct BrowserContext: Equatable, Sendable {
    public var collection: EffectCollection
    public var searchText: String
    /// `nil` = nothing picked yet (clean launch), `""` = "All categories",
    /// otherwise a category name or a pseudo-category sentinel ("New",
    /// "★ Favorites").
    public var selectedCategory: String?
    public var sortMode: EffectSortMode

    public init(
        collection: EffectCollection = .all,
        searchText: String = "",
        selectedCategory: String? = nil,
        sortMode: EffectSortMode = .chrisOrdering
    ) {
        self.collection = collection
        self.searchText = searchText
        self.selectedCategory = selectedCategory
        self.sortMode = sortMode
    }
}

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
    /// Called with the picked effect plus the ordered list it was picked from
    /// (the middle column as currently displayed). The workspace hands that
    /// list to the view model so ← Prev / Next → on the effect page walk the
    /// same list the user was browsing — Favorites, "New", a search result —
    /// not just the effect's literal category.
    public let onSelect: (EffectBrowseModel, [EffectBrowseModel]) -> Void
    public let onClose: () -> Void
    /// Optional — drives the pinned "Favorites" pseudo-category in the sidebar
    /// and the star toggle in the preview pane.
    public let favorites: FavoritesStore?
    /// Whether the "make this the default effect" pin appears in the preview
    /// pane. Gated by the personalisation master toggle (see AirwindowsAUView).
    public let showDefaultEffectPin: Bool

    @Environment(\.colorScheme) private var scheme
    /// Matches the workspace's Settings box so the two line up across the
    /// browse ↔ effect transition. Scaled by the same factor as the box.
    @Environment(\.uiScale) private var uiScale
    /// Re-passed into the Preferences sheet (sheets don't reliably inherit
    /// custom environment values) so its "Plugin window" readout works when
    /// Preferences is opened from the browser sidebar too.
    @Environment(\.containerSize) private var containerSize
    /// Category / filter / search / sort, owned by the caller so it outlives
    /// this view — see `BrowserContext`.
    @Binding var context: BrowserContext
    @State private var highlighted: EffectBrowseModel?
    @State private var showAbout: Bool = false
    @State private var showPreferences: Bool = false

    /// Pseudo-category that shows the N most recently committed effects
    /// across the currently filtered pool. Lives only in the BrowserView —
    /// no upstream registry / override-layer change. Effects still appear in
    /// their natural category alongside their appearance in "New".
    private static let newCategoryName = "New"
    private static let newCategoryLimit = 30

    /// Sentinel `selectedCategory` value for the favorites pseudo-category.
    /// Chosen to never collide with a real category name or the "" all-sentinel.
    private static let favoritesCategoryName = "\u{2605} Favorites"

    public init(
        allEffects: [EffectBrowseModel],
        categories: [String],
        countsByCategory: [String: Int],
        context: Binding<BrowserContext>,
        initialHighlight: EffectBrowseModel? = nil,
        descriptionProvider: @escaping (EffectBrowseModel) -> String = { $0.whatText },
        favorites: FavoritesStore? = nil,
        showDefaultEffectPin: Bool = true,
        onSelect: @escaping (EffectBrowseModel, [EffectBrowseModel]) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.allEffects = allEffects
        self.categories = categories
        self.countsByCategory = countsByCategory
        self.initialHighlight = initialHighlight
        self.descriptionProvider = descriptionProvider
        self.favorites = favorites
        self.showDefaultEffectPin = showDefaultEffectPin
        self.onSelect = onSelect
        self.onClose = onClose
        self._context = context
        self._highlighted = State(initialValue: initialHighlight)
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Left: sidebar
            SidebarView(
                collection: $context.collection,
                searchText: $context.searchText,
                selectedCategory: $context.selectedCategory,
                categories: visibleCategories,
                countsByCategory: effectiveCountsByCategory,
                totalCount: filteredAll.count,
                onClose: onClose,
                onAboutTap: { showAbout = true },
                onRandomTap: pickRandom,
                onSettingsTap: { showPreferences = true },
                favoritesCount: favoriteEffects.count,
                isFavoritesSelected: context.selectedCategory == Self.favoritesCategoryName,
                onSelectFavorites: favorites == nil ? nil : {
                    context.selectedCategory = Self.favoritesCategoryName
                }
            )
            .frame(width: AirwindowsLayout.sidebarWidth * uiScale)

            Divider().opacity(0.4)

            // Middle: effect list — only shown once the user has made a pick
            // in the sidebar. "All categories" sets sentinel "", a specific
            // category sets its name, initial state is nil = nothing picked.
            if let cat = context.selectedCategory {
                EffectListColumn(
                    categoryLabel: middleColumnLabel(for: cat),
                    sortLabel: context.sortMode.rawValue,
                    effects: effectsInCurrentCategory,
                    groupedByCategory: isAllCategories && context.sortMode == .byCategory
                        ? groupedEffects : nil,
                    highlighted: $highlighted,
                    onPick: { effect in
                        onSelect(effect, navigationPool)
                        onClose()
                    },
                    onSortTap: {
                        context.sortMode = context.sortMode.next(allCategories: isAllCategories)
                    }
                )
                .frame(minWidth: 260 * uiScale, idealWidth: 310 * uiScale, maxWidth: 340 * uiScale)

                Divider().opacity(0.4)
            }

            // Right: preview pane — only show an effect once the user has
            // picked a category (selectedCategory != nil).
            EffectPreviewColumn(
                effect: context.selectedCategory != nil
                    ? (highlighted ?? effectsInCurrentCategory.first)
                    : nil,
                description: highlighted.flatMap { descriptionProvider($0) } ?? "",
                favorites: favorites,
                showDefaultEffectPin: showDefaultEffectPin,
                onSelect: { effect in
                    onSelect(effect, navigationPool)
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
            if newCount == 0, context.selectedCategory == Self.favoritesCategoryName {
                context.selectedCategory = ""
            }
        }
        .onChange(of: context.selectedCategory) { _, newCat in
            // "By category" sort only makes sense for "All categories"
            if newCat != "" && context.sortMode == .byCategory {
                context.sortMode = .chrisOrdering
            }
            // "New" pseudo-category defaults to newest-first; user can still
            // toggle the sort to re-order that short list alphabetically etc.
            if newCat == Self.newCategoryName {
                context.sortMode = .newestFirst
            }
        }
        .sheet(isPresented: $showAbout) {
            AboutView(onClose: { showAbout = false })
                .environment(\.colorScheme, scheme)
                .environment(\.uiScale, uiScale)
        }
        .sheet(isPresented: $showPreferences) {
            PreferencesView(onClose: { showPreferences = false })
                .environment(\.colorScheme, scheme)
                .environment(\.containerSize, containerSize)
        }
    }

    // MARK: - Filtering

    private var filteredAll: [EffectBrowseModel] {
        allEffects
            .filtered(by: context.collection)
            .matching(query: context.searchText)
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

    /// The `newCategoryLimit` newest effects (by firstCommitDate descending) within the current
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
        if context.selectedCategory == Self.favoritesCategoryName {
            pool = favoriteEffects
        } else if context.selectedCategory == Self.newCategoryName {
            // Pseudo-category: newest N. Re-applies the user-chosen sortMode
            // afterward so toggling alphabetical etc. still re-orders them.
            pool = newCategoryEffects
        } else if let cat = context.selectedCategory, !cat.isEmpty {
            // Specific category picked
            pool = filteredAll.filter { $0.category == cat }
        } else {
            // Empty string ("All categories") or nil → full pool
            pool = filteredAll
        }
        return pool.sorted(by: context.sortMode)
    }

    /// The ordered list of effects the middle column is currently showing —
    /// handed to `onSelect` so prev/next on the effect page can walk the same
    /// list the user picked from. In "by category" grouping the flat sort
    /// order differs from the visual order, so flatten the groups instead.
    private var navigationPool: [EffectBrowseModel] {
        if isAllCategories && context.sortMode == .byCategory {
            return groupedEffects.flatMap(\.effects)
        }
        return effectsInCurrentCategory
    }

    /// Counts table augmented with the synthetic "New" entry so the sidebar
    /// can render its row. Real-category counts come straight from the host.
    private var effectiveCountsByCategory: [String: Int] {
        var counts = countsByCategory
        counts[Self.newCategoryName] = min(Self.newCategoryLimit, filteredAll.count)
        return counts
    }

    private var isAllCategories: Bool {
        context.selectedCategory == ""
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
    /// The pool still reflects the current category — if the random pick lands
    /// outside it, the view model falls back to the pick's own category for
    /// prev/next navigation.
    private func pickRandom() {
        guard let picked = filteredAll.randomElement() else { return }
        onSelect(picked, navigationPool)
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
    @Environment(\.uiScale) private var uiScale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2 * uiScale) {
                Text(categoryLabel)
                    .font(.system(size: 28 * uiScale, weight: .semibold))
                    .foregroundStyle(.primary)
                Button(action: onSortTap) {
                    HStack(spacing: 4 * uiScale) {
                        Text(sortLabel)
                            .font(.system(size: 15 * uiScale))
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .hEdgePadding(22)
            .padding(.top, 22 * uiScale)
            .padding(.bottom, 12 * uiScale)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let groups = groupedByCategory {
                        ForEach(groups, id: \.category) { group in
                            // Category subheader
                            Text(group.category)
                                .font(.system(size: 13 * uiScale, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .hEdgePadding(22)
                                .padding(.top, 16 * uiScale)
                                .padding(.bottom, 6 * uiScale)

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

    @Environment(\.uiScale) private var uiScale

    var body: some View {
        HStack(spacing: 12 * uiScale) {
            Text("\(number).")
                .font(.system(size: 20 * uiScale, weight: .regular).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 46 * uiScale, alignment: .trailing)

            Text(effect.name)
                .font(.system(size: 20 * uiScale, weight: isHighlighted ? .semibold : .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()
        }
        .hEdgePadding(22)
        .padding(.vertical, 7 * uiScale)
        .background(isHighlighted ? Color.primary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Right column: preview pane

private struct EffectPreviewColumn: View {
    let effect: EffectBrowseModel?
    let description: String
    let favorites: FavoritesStore?
    /// Gates the "make default" pin (personalisation master toggle).
    let showDefaultEffectPin: Bool
    let onSelect: (EffectBrowseModel) -> Void

    @Environment(\.uiScale) private var uiScale
    /// Name of the effect that loads on a fresh launch instead of the
    /// browser ("" = none — fresh launches open the browser as always).
    /// Set by the pin button below; shown and clearable in Preferences.
    /// App-Group-backed so the choice is shared across the standalone app
    /// and every plugin instance, same as favorites and the UI scale.
    @AppStorage("airwindows.defaultEffect", store: .airwindowsShared)
    private var defaultEffectName: String = ""

    var body: some View {
        if let effect {
            VStack(alignment: .leading, spacing: 0) {
                // Header row: name + favorite star + Select button
                HStack(alignment: .firstTextBaseline) {
                    Text(effect.name)
                        .font(.system(size: 40 * uiScale, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Spacer()

                    // Pin: marks this effect as the default that loads on a
                    // fresh launch (instead of the browser). One pin at a
                    // time — pinning replaces any previous default; tapping
                    // the pinned effect again clears it. Hidden unless the
                    // personalisation toolkit is enabled.
                    if showDefaultEffectPin {
                        let isDefault = defaultEffectName == effect.name
                        Button {
                            defaultEffectName = isDefault ? "" : effect.name
                        } label: {
                            Image(systemName: isDefault ? "pin.fill" : "pin")
                                .font(.system(size: 20 * uiScale, weight: .medium))
                                .foregroundStyle(isDefault ? Color.primary : Color.secondary)
                                .frame(width: 40 * uiScale, height: 40 * uiScale)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isDefault
                            ? "Remove \(effect.name) as the default effect"
                            : "Make \(effect.name) the default effect")
                    }

                    if let favorites {
                        let isFav = favorites.isFavorite(effect.name)
                        Button {
                            favorites.toggle(effect.name)
                        } label: {
                            Image(systemName: isFav ? "star.fill" : "star")
                                .font(.system(size: 20 * uiScale, weight: .medium))
                                .foregroundStyle(isFav ? Color.primary : Color.secondary)
                                .frame(width: 40 * uiScale, height: 40 * uiScale)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isFav ? "Remove \(effect.name) from favorites" : "Add \(effect.name) to favorites")
                    }

                    Chip(
                        text: "Select",
                        role: .primary,
                        size: .large,
                        accessibility: "Select \(effect.name)",
                        action: { onSelect(effect) }
                    )
                }
                .padding(.top, 28 * uiScale)
                .hEdgePadding(28)

                if !effect.whatText.isEmpty {
                    Text("\u{201C}\(effect.whatText)\u{201D}")
                        .font(.system(size: 20 * uiScale))
                        .foregroundStyle(.secondary)
                        .hEdgePadding(28)
                        .padding(.top, 14 * uiScale)
                }

                // Metadata pills — always shows at least Mono/Stereo.
                FlowMetaRow(effect: effect)
                    .hEdgePadding(28)
                    .padding(.top, 19 * uiScale)

                // Full description. Scroll indicator forced visible so users
                // realize there's more content below the fold (the default
                // SwiftUI behavior only flashes the indicator on scroll).
                ScrollView {
                    // Leading `# ` line renders as a heading; see EffectDescriptionText.
                    EffectDescriptionText(description.isEmpty ? effect.whatText : description)
                        .hEdgePadding(28)
                        .padding(.vertical, 20 * uiScale)
                }
                .scrollIndicators(.visible)

                // External link chips — sit just below the description text.
                // Only render when the effect has a matching airwindows.com post
                // or YouTube video (13 effects have neither and show no chips).
                if effect.postURL != nil || effect.videoURL != nil {
                    HStack(spacing: 8 * uiScale) {
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
                    .hEdgePadding(28)
                    .padding(.top, 10 * uiScale)
                    .padding(.bottom, 20 * uiScale)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack {
                Spacer()
                Text("No effect selected")
                    .font(.system(size: 17 * uiScale))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct FlowMetaRow: View {
    let effect: EffectBrowseModel

    @Environment(\.uiScale) private var uiScale

    var body: some View {
        // Category and parameter-count pills removed: the category is already
        // visible in the sidebar and the middle-column header, and the raw
        // parameter count isn't useful info for most users (may be revisited
        // as a more visual indicator later). Mono/Stereo always shows one or
        // the other — every effect is one of those two, so neither is a
        // meaningful "default" to leave unmarked.
        HStack(spacing: 8 * uiScale) {
            Chip(text: effect.isMono ? "Mono" : "Stereo", role: .inert)
            if !effect.firstCommitDate.isEmpty {
                Chip(text: effect.firstCommitDate, role: .inert)
            }
        }
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
        context: .constant(BrowserContext(selectedCategory: "Filter")),
        onSelect: { _, _ in },
        onClose: {}
    )
    .frame(width: 1100, height: 700)
}
