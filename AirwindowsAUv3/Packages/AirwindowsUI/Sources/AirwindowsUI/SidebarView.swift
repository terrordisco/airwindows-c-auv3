//
//  SidebarView.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Left column inside BrowserView. Owns the collection tab + search +
//  category selection state; emits the chosen category back up to
//  BrowserView, which filters the middle list accordingly.
//

import SwiftUI

/// Sidebar: curated collection tabs, search field, categories list.
///
/// Styled to match the Figma browser design:
/// - Top: 3 filter collection tabs (Recommended / Basic / Latest)
/// - Search field
/// - "Categories" section header
/// - Category rows: dot + name + count + chevron
/// - Selection accent: cyan
public struct SidebarView: View {
    @Binding public var collection: EffectCollection
    @Binding public var searchText: String
    @Binding public var selectedCategory: String?

    public let categories: [String]
    public let countsByCategory: [String: Int]
    public let totalCount: Int
    public let onClose: (() -> Void)?
    public let onAboutTap: (() -> Void)?
    public let onRandomTap: (() -> Void)?
    public let onSettingsTap: (() -> Void)?
    /// Favorites pseudo-category. The row is pinned above "All categories" and
    /// only appears once at least one effect is favorited (count > 0).
    public let favoritesCount: Int
    public let isFavoritesSelected: Bool
    public let onSelectFavorites: (() -> Void)?

    @Environment(\.colorScheme) private var scheme
    @Environment(\.uiScale) private var uiScale

    public init(
        collection: Binding<EffectCollection>,
        searchText: Binding<String>,
        selectedCategory: Binding<String?>,
        categories: [String],
        countsByCategory: [String: Int],
        totalCount: Int,
        onClose: (() -> Void)? = nil,
        onAboutTap: (() -> Void)? = nil,
        onRandomTap: (() -> Void)? = nil,
        onSettingsTap: (() -> Void)? = nil,
        favoritesCount: Int = 0,
        isFavoritesSelected: Bool = false,
        onSelectFavorites: (() -> Void)? = nil
    ) {
        self._collection = collection
        self._searchText = searchText
        self._selectedCategory = selectedCategory
        self.categories = categories
        self.countsByCategory = countsByCategory
        self.totalCount = totalCount
        self.onClose = onClose
        self.onAboutTap = onAboutTap
        self.onRandomTap = onRandomTap
        self.onSettingsTap = onSettingsTap
        self.favoritesCount = favoritesCount
        self.isFavoritesSelected = isFavoritesSelected
        self.onSelectFavorites = onSelectFavorites
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Close button top-right (only if caller provides onClose)
            if let onClose {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17 * uiScale, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32 * uiScale, height: 32 * uiScale)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close browser")
                }
                .hEdgePadding(12)
                .padding(.top, 12 * uiScale)
            }

            // Starred collection tabs
            CollectionTabStrip(selection: $collection)
                .hEdgePadding(18)
                .padding(.top, (onClose == nil ? 18 : 4) * uiScale)
                .padding(.bottom, 14 * uiScale)

            // Search field
            SearchField(text: $searchText)
                .hEdgePadding(18)
                .padding(.bottom, 16 * uiScale)

            // Categories header
            Text("Categories")
                .font(.system(size: 20 * uiScale, weight: .semibold))
                .foregroundStyle(.secondary)
                .hEdgePadding(18)
                .padding(.bottom, 6 * uiScale)

            // Category list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Favorites pinned above "All categories" — only once the
                    // user has starred something, so it never reads as an empty
                    // dead end. A star icon stands in for the category dot.
                    if favoritesCount > 0, let onSelectFavorites {
                        FavoritesSidebarRow(
                            count: favoritesCount,
                            isSelected: isFavoritesSelected,
                            action: onSelectFavorites
                        )
                    }
                    CategoryRow(
                        title: "All categories",
                        count: totalCount,
                        isSelected: selectedCategory == "",
                        dotColor: .secondary
                    ) {
                        // Empty-string sentinel for "All categories" so the
                        // parent can distinguish it from the initial nil state.
                        selectedCategory = ""
                    }
                    ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                        CategoryRow(
                            title: category,
                            count: countsByCategory[category] ?? 0,
                            isSelected: selectedCategory == category,
                            dotColor: dotColor(for: index)
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.bottom, 12)
            }

            // Pinned bottom rows: Random + About + Settings
            if onRandomTap != nil || onAboutTap != nil || onSettingsTap != nil {
                Divider().opacity(0.4)
            }

            if let onRandomTap {
                SidebarActionButton(
                    systemName: "shuffle",
                    label: "Random effect",
                    action: onRandomTap
                )
            }

            if let onAboutTap {
                SidebarActionButton(
                    systemName: "info.circle",
                    label: "About Airwindows",
                    action: onAboutTap
                )
            }

            // Settings sits directly below About — its bottom-left position
            // here is mirrored by the Settings box in the workspace's bottom
            // bar, so the entry point reads as "the same place" in both views.
            if let onSettingsTap {
                SidebarActionButton(
                    systemName: "gearshape",
                    label: "Settings",
                    action: onSettingsTap
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AirwindowsPalette.subtleSurface(scheme))
    }

    /// Subtle per-category dot color cycle. Not meaningful — just visual rhythm
    /// so categories feel distinct without needing per-category iconography.
    private func dotColor(for index: Int) -> Color {
        AirwindowsPalette.categoryDot(at: index)
    }
}

// MARK: - Collection tab strip

/// Three filter tabs (Recommended / Basic / Latest). Tapping the selected
/// tab deselects it, reverting to `.all` (no filter).
private struct CollectionTabStrip: View {
    @Binding var selection: EffectCollection

    private let items: [EffectCollection] = [.recommended, .basic, .latest]

    @Environment(\.uiScale) private var uiScale

    var body: some View {
        // The three tabs must share one line in the fixed-width sidebar, but the
        // longest label ("Recommended" — 100pt of text alone) makes them overflow
        // the left-aligned 18pt inset (which can't shrink: it matches the search
        // field below). The inset is half-fixed, so small UI scales make it worse.
        // FitToWidth shrinks all three uniformly by only the factor needed to fit
        // (≈0.98 at 100% — imperceptible), keeping them on one line at any scale
        // while staying the regular chip size, matching the rest of the system.
        FitToWidth {
            HStack(spacing: 6 * uiScale) {
                ForEach(items) { item in
                    Chip(
                        text: item.rawValue,
                        role: .toggle(isOn: selection == item),
                        accessibility: item.rawValue
                    ) {
                        selection = (selection == item) ? .all : item
                    }
                }
            }
        }
    }
}

// MARK: - Search field

private struct SearchField: View {
    @Binding var text: String

    @Environment(\.uiScale) private var uiScale

    var body: some View {
        HStack(spacing: 8 * uiScale) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 17 * uiScale))
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 17 * uiScale))
                .autocorrectionDisabled()
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 17 * uiScale))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14 * uiScale)
        .padding(.vertical, 10 * uiScale)
        .background(
            RoundedRectangle(cornerRadius: 999)
                .fill(Color.secondary.opacity(0.12))
        )
    }
}

// MARK: - Category row

/// Reusable pinned-bottom button row for the sidebar (Random, About, etc.).
private struct SidebarActionButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    @Environment(\.uiScale) private var uiScale

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10 * uiScale) {
                Image(systemName: systemName)
                    .font(.system(size: 20 * uiScale, weight: .regular))
                Text(label)
                    .font(.system(size: 17 * uiScale, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.primary)
            .hEdgePadding(18)
            .padding(.vertical, 14 * uiScale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.secondary.opacity(0.08))
    }
}

/// Favorites row — same metrics as `CategoryRow` but with a star glyph in
/// place of the colored category dot, so it reads as special and pinned.
private struct FavoritesSidebarRow: View {
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    private static let accent = AirwindowsPalette.accent

    @Environment(\.uiScale) private var uiScale

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12 * uiScale) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12 * uiScale))
                    .foregroundStyle(isSelected ? Self.accent : Color.primary)
                    .frame(width: 8 * uiScale)

                HStack(alignment: .firstTextBaseline, spacing: 6 * uiScale) {
                    Text("Favorites")
                        .font(.system(size: 20 * uiScale, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Self.accent : Color.primary)
                        .lineLimit(1)
                    Text("(\(count))")
                        .font(.system(size: 17 * uiScale).monospacedDigit())
                        .foregroundStyle(isSelected ? Self.accent.opacity(0.85) : Color.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 15 * uiScale, weight: .semibold))
                    .foregroundStyle(isSelected ? Self.accent : Color.secondary.opacity(0.5))
            }
            .hEdgePadding(18)
            .padding(.vertical, 11 * uiScale)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CategoryRow: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let dotColor: Color
    let action: () -> Void

    private static let accent = AirwindowsPalette.accent

    @Environment(\.uiScale) private var uiScale

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12 * uiScale) {
                Circle()
                    .fill(isSelected ? Self.accent : dotColor.opacity(0.55))
                    .frame(width: 8 * uiScale, height: 8 * uiScale)

                HStack(alignment: .firstTextBaseline, spacing: 6 * uiScale) {
                    Text(title)
                        .font(.system(size: 20 * uiScale, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Self.accent : Color.primary)
                        .lineLimit(1)
                    Text("(\(count))")
                        .font(.system(size: 17 * uiScale).monospacedDigit())
                        .foregroundStyle(isSelected ? Self.accent.opacity(0.85) : Color.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 15 * uiScale, weight: .semibold))
                    .foregroundStyle(isSelected ? Self.accent : Color.secondary.opacity(0.5))
            }
            .hEdgePadding(18)
            .padding(.vertical, 11 * uiScale)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow layout

/// Scales its content down uniformly so it fits the available width on a single
/// line — never scales up. The layout footprint is capped to the available
/// width (height tracks the content's natural height), so the shrunk content
/// can't push its neighbors. Used by the collection filter strip, whose longest
/// label can't otherwise share a line with the other two in the narrow sidebar.
private struct FitToWidth<Content: View>: View {
    @ViewBuilder var content: Content

    @State private var contentSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let factor: CGFloat = (contentSize.width > geo.size.width && contentSize.width > 0)
                ? geo.size.width / contentSize.width
                : 1
            content
                .fixedSize()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: FitSizeKey.self, value: proxy.size)
                    }
                )
                .scaleEffect(factor, anchor: .leading)
                .onPreferenceChange(FitSizeKey.self) { contentSize = $0 }
        }
        // Reserve the content's natural height so the GeometryReader (which is
        // otherwise greedy) doesn't collapse the row.
        .frame(height: contentSize.height)
    }
}

private struct FitSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Minimal wrapping layout: places children left-to-right and wraps to a new
/// line when the next child would overflow the proposed width. Retained as a
/// general-purpose utility (the filter strip now uses `FitToWidth` instead).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + spacing + size.width > maxWidth {
                widest = max(widest, x)
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            if x > 0 { x += spacing }
            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
        widest = max(widest, x)
        let width = maxWidth.isFinite ? maxWidth : widest
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + spacing + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            if x > bounds.minX { x += spacing }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview("Sidebar") {
    SidebarPreviewWrapper()
        .frame(width: 300, height: 700)
}

private struct SidebarPreviewWrapper: View {
    @State private var collection: EffectCollection = .recommended
    @State private var search: String = ""
    @State private var category: String? = "Filter"

    var body: some View {
        SidebarView(
            collection: $collection,
            searchText: $search,
            selectedCategory: $category,
            categories: EffectBrowseModel.sampleCategories,
            countsByCategory: [
                "Filter": 47,
                "Consoles": 45,
                "Reverb": 36,
                "Utility": 35,
                "Dynamics": 33,
                "Effects": 28,
                "Brightness": 26,
                "Ambience": 25,
                "Tape": 12,
                "Saturation": 17
            ],
            totalCount: 461,
            onClose: {}
        )
    }
}
