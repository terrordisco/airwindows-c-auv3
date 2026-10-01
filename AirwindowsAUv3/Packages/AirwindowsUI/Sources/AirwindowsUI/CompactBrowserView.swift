//
//  CompactBrowserView.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The `.compact` layout-mode effect browser: a drawer that slides in from
//  the LEFT over a dimmed workspace (its counterpart, the menu drawer, comes
//  from the right). The full browser's three columns become a drill-down:
//
//      Categories  ─›  Effects in a category  ─›  (inline preview card)  ─›  Description
//
//  Page 1, categories: close button, search field, collection chips, then
//  ★ Favorites (when any), New, All, a hairline, and the real categories
//  with their counts. "Random effect" is pinned at the bottom.
//
//  Page 2, effects: "‹ Categories" back button + sort button, the list title
//  with its count, the numbered list. Tapping a row highlights it and raises
//  the preview CARD at the bottom of the drawer (name, ★, pin, tagline,
//  Mono/Stereo + year chips, Select). Tapping the highlighted row again opens
//  its description page (page 3); only the Select buttons select.
//
//  Page 3, description: tapping the card's name pushes the effect's full
//  awpdoc description with the blog/video link chips, and a Select button.
//
//  Shares `BrowserContext` (and therefore category / filter / search / sort)
//  and all model logic (`BrowserCatalog`) with the full BrowserView, so
//  switching layout modes never loses the user's place.
//

import SwiftUI

public struct CompactBrowserView: View {
    public let allEffects: [EffectBrowseModel]
    public let categories: [String]
    public let countsByCategory: [String: Int]
    public let initialHighlight: EffectBrowseModel?
    public let descriptionProvider: (EffectBrowseModel) -> String
    public let favorites: FavoritesStore?
    public let onSelect: (EffectBrowseModel, [EffectBrowseModel]) -> Void
    public let onClose: () -> Void

    @Binding var context: BrowserContext

    @Environment(\.colorScheme) private var scheme
    @Environment(\.uiScale) private var uiScale
    @Environment(\.containerSize) private var containerSize

    /// Header top inset: clears Stage Manager's window controls on iPad when
    /// the container is tall enough (see CompactChrome).
    private var headerTopInset: CGFloat {
        CompactChrome.headerTopInset(containerHeight: containerSize.height, base: 14)
    }

    /// Which drill-down page is showing. The effects page is implied by a
    /// non-nil `context.selectedCategory`; `showCategories` forces page 1 on
    /// top of that so the back button works without clearing the user's
    /// category (reopening the browser still lands on their list).
    @State private var showCategories: Bool
    @State private var highlighted: EffectBrowseModel?
    /// Page 3 — the effect whose full description is open.
    @State private var describing: EffectBrowseModel?

    public init(
        allEffects: [EffectBrowseModel],
        categories: [String],
        countsByCategory: [String: Int],
        context: Binding<BrowserContext>,
        initialHighlight: EffectBrowseModel? = nil,
        descriptionProvider: @escaping (EffectBrowseModel) -> String = { $0.whatText },
        favorites: FavoritesStore? = nil,
        onSelect: @escaping (EffectBrowseModel, [EffectBrowseModel]) -> Void,
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
        self._context = context
        self._highlighted = State(initialValue: initialHighlight)
        self._showCategories = State(initialValue: context.wrappedValue.selectedCategory == nil)
    }

    private var catalog: BrowserCatalog {
        BrowserCatalog(
            allEffects: allEffects,
            categories: categories,
            countsByCategory: countsByCategory,
            context: context,
            favorites: favorites
        )
    }

    // Fixed chrome metrics (drawer chrome doesn't scale; list text does).
    private static let hInset: CGFloat = 20
    private static let rowHeight: CGFloat = 44

    // MARK: - Responsive columns
    //
    // The drawer GROWS as you drill in (Sveinbjörn, 2026-09-28): it opens as
    // one column of categories; picking a category adds the effects column;
    // tapping an effect adds the description column — as far as the width
    // allows. When not everything fits, the deepest pages win and the earlier
    // ones slide off to the left behind a back button:
    //
    //   depth 1        [ categories ]
    //   depth 2        [ categories | effects ]                (fits 2+)
    //   depth 3        [ categories | effects | description ]  (fits 3)
    //                  [ effects | description ]               (fits 2)
    //                  [ description ]                          (fits 1)
    //
    // Each column is `columnWidth`; at least `workspaceSliver` of the
    // workspace stays visible behind a fully grown drawer so the scrim keeps
    // reading as "tap to go back". Breakpoints that fall out of that:
    //
    //   < 430 pt          one column, full width        iPhone portrait
    //   430 – 719 pt      max one column, 300 pt        Slide Over, half Split View
    //   720 – 1019 pt     max two columns, 600 pt       iPad mini / 11" portrait, iPhone landscape
    //   ≥ 1020 pt         max three columns, 900 pt     13" portrait, every iPad landscape

    static let columnWidth: CGFloat = 300
    static let workspaceSliver: CGFloat = 120
    static let fullWidthBelow: CGFloat = 430
    static let maxColumns = 3

    /// How many columns a container can fit at most.
    public static func maxColumnCount(containerWidth: CGFloat) -> Int {
        guard containerWidth > 1 else { return 1 }
        let fit = Int((containerWidth - workspaceSliver) / columnWidth)
        return min(maxColumns, max(1, fit))
    }

    private var maxFit: Int { Self.maxColumnCount(containerWidth: containerSize.width) }

    /// How deep the user is: 1 categories, 2 an effects list, 3 an effect's
    /// description. In the single-column layout the description only counts
    /// once it has been pushed (`describing`); with room for more columns a
    /// highlighted row is enough — the description column appears beside it.
    private var depth: Int {
        if showCategories || context.selectedCategory == nil { return 1 }
        if maxFit == 1 {
            return describing == nil ? 2 : 3
        }
        if let h = highlighted, catalog.effectsInCurrentCategory.contains(h) { return 3 }
        return 2
    }

    private var columnsShown: Int { min(depth, maxFit) }
    /// The visible pages are the LAST `columnsShown` of the path.
    private var categoriesVisible: Bool { depth == columnsShown }
    private var effectsVisible: Bool { depth >= 2 && depth - columnsShown <= 1 }
    private var descriptionVisible: Bool { depth == 3 }

    private var drawerWidth: CGFloat {
        if containerSize.width > 1, containerSize.width < Self.fullWidthBelow { return containerSize.width }
        return CGFloat(columnsShown) * Self.columnWidth
    }
    private var columnWidth: CGFloat { drawerWidth / CGFloat(columnsShown) }

    private var columnDivider: some View {
        Rectangle()
            .fill(AirwindowsPalette.divider(scheme))
            .frame(width: 1)
            .ignoresSafeArea()
    }

    public var body: some View {
        // Drill-down pages. Deeper pages get a higher zIndex so a page
        // sliding out (back navigation) stays ON TOP of the one it reveals —
        // without it SwiftUI draws the leaving page underneath for the
        // duration of its exit transition. `.clipped()` keeps the sliding
        // pages inside the drawer instead of sweeping across the workspace.
        HStack(spacing: 0) {
            if categoriesVisible {
                categoriesPage
                    .frame(width: columnWidth)
                    .transition(.move(edge: .leading))
                    .zIndex(0)
            }
            if effectsVisible {
                if categoriesVisible { columnDivider }
                effectsPage(showBack: !categoriesVisible, showCard: maxFit == 1, showClose: !categoriesVisible && !descriptionVisible)
                    .frame(width: columnWidth)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }
            if descriptionVisible {
                if effectsVisible { columnDivider }
                descriptionPage(for: describedEffect, showBack: !effectsVisible, showClose: !categoriesVisible)
                    .frame(width: columnWidth)
                    .transition(.move(edge: .trailing))
                    .zIndex(2)
            }
        }
        .frame(width: drawerWidth, alignment: .leading)
        .clipped()
        // Swipe right = back one level (like the system back swipe); swipe
        // left = push the drawer off toward its edge, i.e. close.
        .onHorizontalSwipe { swipe in
            switch swipe {
            case .right: goBack()
            case .left: onClose()
            }
        }
        // Background and edge hairline run through the safe area (one sheet
        // top to bottom); page content stays inside it.
        .background(AirwindowsPalette.surface(scheme).ignoresSafeArea())
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AirwindowsPalette.divider(scheme))
                .frame(width: 1)
                .ignoresSafeArea()
        }
        .onAppear {
            // Pick up favorites changed by the other process (app ↔ plugin).
            favorites?.refresh()
        }
        .onChange(of: catalog.favoriteEffects.count) { _, newCount in
            // Un-starring the last favorite while viewing Favorites: fall back
            // to All so the list isn't an orphaned empty page.
            if newCount == 0, context.selectedCategory == BrowserCatalog.favoritesCategoryName {
                context.selectedCategory = BrowserCatalog.allCategoriesName
            }
        }
        .onChange(of: context.selectedCategory) { _, newCat in
            // Same sort-mode housekeeping as the full browser.
            if newCat != BrowserCatalog.allCategoriesName && context.sortMode == .byCategory {
                context.sortMode = .chrisOrdering
            }
            if newCat == BrowserCatalog.newCategoryName {
                context.sortMode = .newestFirst
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Effect browser")
    }

    /// The effect whose description column is showing (see `depth`).
    private var describedEffect: EffectBrowseModel {
        if maxFit == 1, let describing { return describing }
        return highlighted ?? describing ?? catalog.effectsInCurrentCategory.first!
    }

    // MARK: - Page 1: categories

    private var categoriesPage: some View {
        VStack(spacing: 0) {
            HStack {
                CompactChromeButton(systemName: "xmark", accessibility: "Close browser", action: onClose)
                Spacer(minLength: 8)
                Text("Effects")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.trailing, 8)
            }
            .padding(.leading, 12)
            .padding(.trailing, Self.hInset - 8)
            .padding(.top, headerTopInset)
            .padding(.bottom, 8)

            SearchField(text: $context.searchText)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            CollectionTabStrip(selection: $context.collection)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 0) {
                    let favCount = catalog.favoriteEffects.count
                    if favorites != nil, favCount > 0 {
                        categoryRow(
                            title: "Favorites",
                            systemName: "star.fill",
                            count: favCount,
                            isSelected: context.selectedCategory == BrowserCatalog.favoritesCategoryName
                        ) { open(BrowserCatalog.favoritesCategoryName) }
                    }
                    let counts = catalog.effectiveCountsByCategory
                    let visible = catalog.visibleCategories
                    if visible.contains(BrowserCatalog.newCategoryName) {
                        categoryRow(
                            title: "New",
                            count: counts[BrowserCatalog.newCategoryName] ?? 0,
                            isSelected: context.selectedCategory == BrowserCatalog.newCategoryName
                        ) { open(BrowserCatalog.newCategoryName) }
                    }
                    categoryRow(
                        title: "All",
                        count: catalog.filteredAll.count,
                        isSelected: context.selectedCategory == BrowserCatalog.allCategoriesName
                    ) { open(BrowserCatalog.allCategoriesName) }

                    Divider().opacity(0.4)
                        .padding(.horizontal, Self.hInset)
                        .padding(.vertical, 4)

                    ForEach(visible.filter { $0 != BrowserCatalog.newCategoryName }, id: \.self) { cat in
                        categoryRow(
                            title: cat,
                            count: counts[cat] ?? 0,
                            isSelected: context.selectedCategory == cat
                        ) { open(cat) }
                    }

                    if visible.isEmpty {
                        Text("No effects match")
                            .font(.system(size: 15 * uiScale))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 28)
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.automatic)

            Divider().opacity(0.4)
            Button(action: pickRandom) {
                HStack(spacing: 14) {
                    Image(systemName: "dice")
                        .font(.system(size: 16, weight: .regular))
                    Text("Random Effect")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, Self.hInset)
                .frame(height: 52)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(AirwindowsPalette.subtleSurface(scheme))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pick a random effect")
        }
    }

    private static let pageAnimation: Animation = .spring(duration: 0.28, bounce: 0)

    /// One level up the drill-down, for the swipe-back gesture: description →
    /// list (single-column layout), list → categories when the categories
    /// column isn't already showing. At the top there is nowhere to go.
    private func goBack() {
        withAnimation(Self.pageAnimation) {
            if maxFit == 1, describing != nil {
                describing = nil
            } else if !categoriesVisible {
                showCategories = true
            }
        }
    }

    private func open(_ category: String) {
        withAnimation(Self.pageAnimation) {
            context.selectedCategory = category
            showCategories = false
            describing = nil
        }
    }

    private func categoryRow(
        title: String,
        systemName: String? = nil,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 13 * uiScale, weight: .medium))
                        .foregroundStyle(.primary)
                }
                Text(title)
                    .font(.system(size: 16 * uiScale, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(count)")
                    .font(.system(size: 13 * uiScale).monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
            .padding(.horizontal, Self.hInset)
            .frame(height: Self.rowHeight * max(uiScale, 0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.primary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) effects")
    }

    // MARK: - Page 2: effects

    /// - showBack: the "‹ Categories" button (not in the 3-column layout,
    ///   where the categories are always beside the list).
    /// - showCard: the inline preview card (1-column only; wider layouts grow
    ///   a description column when a row is tapped instead).
    /// - showClose: the drawer's close button, when this is the rightmost
    ///   column and the categories page (which has its own ×) is off screen.
    private func effectsPage(showBack: Bool, showCard: Bool, showClose: Bool) -> some View {
        let effects = catalog.effectsInCurrentCategory
        let grouped = catalog.isAllCategories && context.sortMode == .byCategory ? catalog.groupedEffects : nil
        let selection = context.selectedCategory ?? BrowserCatalog.allCategoriesName

        return VStack(spacing: 0) {
            HStack {
                if showBack {
                    Button {
                        withAnimation(Self.pageAnimation) { showCategories = true }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .medium))
                            Text("Categories")
                                .font(.system(size: 15))
                        }
                        .foregroundStyle(.primary)
                        .frame(height: 40)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to categories")
                }

                Spacer(minLength: 8)

                Button {
                    context.sortMode = context.sortMode.next(allCategories: catalog.isAllCategories)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11, weight: .medium))
                        Text(context.sortMode.rawValue.uppercased())
                            .font(.system(size: 12, weight: .medium))
                            .kerning(0.5)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sort order, \(context.sortMode.rawValue). Tap to change.")

                if showClose {
                    CompactChromeButton(systemName: "xmark", accessibility: "Close browser", action: onClose)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, headerTopInset)
            .padding(.bottom, 4)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(catalog.title(for: selection))
                    .font(.system(size: 22 * uiScale, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(effects.count) effects")
                    .font(.system(size: 13 * uiScale))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Self.hInset)
            .padding(.bottom, 8)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if let grouped {
                            ForEach(grouped, id: \.category) { group in
                                Text(group.category)
                                    .font(.system(size: 12 * uiScale, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, Self.hInset)
                                    .padding(.top, 14)
                                    .padding(.bottom, 4)
                                ForEach(Array(group.effects.enumerated()), id: \.element.registryIndex) { i, effect in
                                    effectRow(number: i + 1, effect: effect)
                                }
                            }
                        } else {
                            ForEach(Array(effects.enumerated()), id: \.element.registryIndex) { i, effect in
                                effectRow(number: i + 1, effect: effect)
                            }
                        }
                        if effects.isEmpty {
                            Text("No effects match")
                                .font(.system(size: 15 * uiScale))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                        }
                    }
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.automatic)
                .onAppear {
                    if let h = highlighted, effects.contains(h) {
                        proxy.scrollTo(h.registryIndex, anchor: .center)
                    }
                }
            }
            .onChange(of: effects) { _, newValue in
                // Keep the highlight valid when filters/sort change the list.
                if let h = highlighted, !newValue.contains(h) {
                    withAnimation(Self.pageAnimation) { highlighted = nil }
                }
            }

            if showCard, let highlighted, effects.contains(highlighted) {
                effectCard(for: highlighted, linksToDescription: true)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25, bounce: 0), value: highlighted)
    }

    private func effectRow(number: Int, effect: EffectBrowseModel) -> some View {
        let isHighlighted = effect == highlighted
        return Button {
            // First tap highlights (raises the preview card); a tap on the
            // already-highlighted row opens its description page. Selecting
            // is always an explicit Select button — the card's or the
            // description page's — never a row tap (Sveinbjörn, 2026-09-28).
            if isHighlighted {
                // With room for more columns the description is already on
                // screen beside the list.
                if maxFit == 1 {
                    withAnimation(Self.pageAnimation) { describing = effect }
                }
            } else {
                // Grows the drawer by a description column when there's room.
                withAnimation(Self.pageAnimation) { highlighted = effect }
            }
        } label: {
            HStack(spacing: 12 * uiScale) {
                Text("\(number)")
                    .font(.system(size: 12 * uiScale).monospacedDigit())
                    .foregroundStyle(isHighlighted ? Color.secondary : Color.secondary.opacity(0.6))
                    .frame(width: 26 * uiScale, alignment: .trailing)
                Text(effect.name)
                    .font(.system(size: 16 * uiScale, weight: isHighlighted ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                ChannelMark(isMono: effect.isMono)
            }
            .padding(.horizontal, Self.hInset)
            .frame(height: 40 * max(uiScale, 0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHighlighted ? Color.primary.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(effect.registryIndex)
        .accessibilityIdentifier("effectRow")
        .accessibilityLabel(effect.isMono ? effect.name : "\(effect.name), stereo process")
        .accessibilityHint(isHighlighted && maxFit == 1 ? "Tap again to read about it" : "Shows a preview")
    }

    // MARK: - Effect card

    /// The effect card: name (with a › into the description when the
    /// description isn't already on screen), ★ and pin, the tagline in New
    /// York italic, the year / STEREO PROCESS chips, and SELECT. Sits at the
    /// bottom of the effects column in the single-column layout and at the
    /// bottom of the description column at every column count (Sveinbjörn,
    /// 2026-09-30), so Select is always in the same place. "Roomier" = larger
    /// type, chips and glyphs first, with padding scaled up in proportion.
    private func effectCard(for effect: EffectBrowseModel, linksToDescription: Bool) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 4) {
                if linksToDescription {
                    Button {
                        withAnimation(Self.pageAnimation) { describing = effect }
                    } label: {
                        HStack(spacing: 6) {
                            Text(effect.name)
                                .font(.system(size: 23 * uiScale, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Read about \(effect.name)")
                } else {
                    Text(effect.name.camelCaseSoftHyphenated)
                        .font(.system(size: 23 * uiScale, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .accessibilityLabel(effect.name)
                }

                Spacer(minLength: 8)

                if let favorites {
                    let isFav = favorites.isFavorite(effect.name)
                    Button { favorites.toggle(effect.name) } label: {
                        Image(systemName: isFav ? "star.fill" : "star")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(isFav ? Color.primary : Color.secondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isFav ? "Remove \(effect.name) from favorites" : "Add \(effect.name) to favorites")
                }

                DefaultEffectPinButton(effect: effect, size: 44, glyphSize: 21)
            }

            if !effect.whatText.isEmpty {
                Text("\u{201C}\(effect.whatText)\u{201D}")
                    .font(.system(size: 19 * uiScale, weight: .regular, design: .serif).italic())
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if !effect.isMono {
                    Chip(text: "Stereo process", size: .small)
                }
                if !effect.firstCommitDate.isEmpty {
                    Chip(text: String(effect.firstCommitDate.prefix(4)), size: .small)
                }
                Spacer(minLength: 8)
                ActionButton(
                    text: "Select",
                    accessibility: "Select \(effect.name)",
                    action: { select(effect) }
                )
            }
        }
        .padding(.horizontal, Self.hInset)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AirwindowsPalette.subtleSurface(scheme).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AirwindowsPalette.divider(scheme))
                .frame(height: 1)
        }
    }

    // MARK: - Page 3: description

    /// The description column/page: navigation up top (back when pushed over
    /// the list, close when this is the rightmost column), the awpdoc text
    /// scrolling in the middle with the blog / video chips after it, and the
    /// effect card pinned at the bottom.
    private func descriptionPage(for effect: EffectBrowseModel, showBack: Bool, showClose: Bool) -> some View {
        let description = descriptionProvider(effect)
        return VStack(spacing: 0) {
            // Controls sit at the top RIGHT (Sveinbjörn's call, 2026-09-28):
            // the top-left of a standalone iPad window is where Stage Manager
            // paints its window controls.
            HStack {
                Spacer(minLength: 8)
                if showBack {
                    Button {
                        withAnimation(Self.pageAnimation) { describing = nil }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .medium))
                            Text(catalog.title(for: context.selectedCategory ?? ""))
                                .font(.system(size: 15))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.primary)
                        .frame(height: 44)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to the list")
                }
                if showClose {
                    CompactChromeButton(systemName: "xmark", accessibility: "Close browser", action: onClose)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, headerTopInset)
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // The card below carries the tagline, so a heading that
                    // repeats it is dropped here.
                    EffectDescriptionText(description.isEmpty ? effect.whatText : description, omittingHeadingMatching: effect.whatText)

                    if effect.postURL != nil || effect.videoURL != nil {
                        HStack(spacing: 8) {
                            if let post = effect.postURL {
                                LinkChip(url: post, systemName: "safari", text: "Blog Post", accessibility: "Read blog post on airwindows.com")
                            }
                            if let video = effect.videoURL {
                                LinkChip(url: video, systemName: "play.rectangle", text: "YouTube Video", accessibility: "Watch video on YouTube")
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, Self.hInset)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.visible)

            effectCard(for: effect, linksToDescription: false)
        }
    }

    // MARK: - Actions

    private func select(_ effect: EffectBrowseModel) {
        onSelect(effect, catalog.navigationPool)
        onClose()
    }

    private func pickRandom() {
        guard let picked = catalog.randomEffect() else { return }
        onSelect(picked, catalog.navigationPool)
        onClose()
    }
}

// MARK: - Pin button (shared by the card and the description page)

/// The "make this the startup effect" pin with its touch tooltip. One pin at
/// a time — pinning replaces any previous default; tapping the pinned effect
/// again clears it. App-Group-backed so app and plugin instances agree.
private struct DefaultEffectPinButton: View {
    let effect: EffectBrowseModel
    let size: CGFloat
    let glyphSize: CGFloat

    @AppStorage("airwindows.defaultEffect", store: .airwindowsShared)
    private var defaultEffectName: String = ""
    @State private var showTooltip = false
    @State private var tooltipText = ""

    var body: some View {
        let isDefault = defaultEffectName == effect.name
        Button {
            defaultEffectName = isDefault ? "" : effect.name
            tooltipText = isDefault
                ? "No longer the default effect"
                : "Make this effect default when I open Airwindows Consolidated"
            showTooltip = true
        } label: {
            Image(systemName: isDefault ? "pin.fill" : "pin")
                .font(.system(size: glyphSize, weight: .medium))
                .foregroundStyle(isDefault ? Color.primary : Color.secondary)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .transientTooltip(tooltipText, isPresented: $showTooltip)
        .accessibilityLabel(isDefault
            ? "Remove \(effect.name) as the default effect"
            : "Make \(effect.name) the default effect")
    }
}

// MARK: - Preview

#Preview("Compact browser") {
    CompactBrowserPreview()
        .frame(width: 300, height: 640)
}

private struct CompactBrowserPreview: View {
    @State private var context = BrowserContext()

    var body: some View {
        CompactBrowserView(
            allEffects: EffectBrowseModel.sampleEffects,
            categories: EffectBrowseModel.sampleCategories,
            countsByCategory: ["Filter": 47, "Reverb": 36, "Consoles": 45, "Tape": 12],
            context: $context,
            onSelect: { _, _ in },
            onClose: {}
        )
    }
}
