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
    /// Favorites pseudo-category. The row is pinned above "All categories" and
    /// only appears once at least one effect is favorited (count > 0).
    public let favoritesCount: Int
    public let isFavoritesSelected: Bool
    public let onSelectFavorites: (() -> Void)?

    @Environment(\.colorScheme) private var scheme

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
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close browser")
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }

            // Starred collection tabs
            CollectionTabStrip(selection: $collection)
                .padding(.horizontal, 18)
                .padding(.top, onClose == nil ? 18 : 4)
                .padding(.bottom, 14)

            // Search field
            SearchField(text: $searchText)
                .padding(.horizontal, 18)
                .padding(.bottom, 16)

            // Categories header
            Text("Categories")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.bottom, 6)

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

            // Pinned bottom rows: Random + About
            if onRandomTap != nil || onAboutTap != nil {
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

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                CollectionTab(
                    collection: item,
                    isSelected: selection == item
                ) {
                    if selection == item {
                        selection = .all
                    } else {
                        selection = item
                    }
                }
            }
        }
    }
}

private struct CollectionTab: View {
    let collection: EffectCollection
    let isSelected: Bool
    let action: () -> Void

    private var fillColor: Color {
        isSelected ? Color.secondary.opacity(0.14) : Color.clear
    }

    private var strokeColor: Color {
        isSelected ? Color.secondary.opacity(0.25) : Color.clear
    }

    private var labelColor: Color {
        isSelected ? Color.primary : Color.secondary
    }

    var body: some View {
        Button(action: action) {
            tabContent
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(background)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var tabContent: some View {
        VStack(spacing: 4) {
            Image(systemName: isSelected ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 20, weight: .regular))
            Text(collection.rawValue)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(labelColor)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(strokeColor, lineWidth: 1)
            )
    }
}

// MARK: - Search field

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 17))
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
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
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .regular))
                Text(label)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Self.accent : Color.primary)
                    .frame(width: 8)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Favorites")
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Self.accent : Color.primary)
                        .lineLimit(1)
                    Text("(\(count))")
                        .font(.system(size: 17).monospacedDigit())
                        .foregroundStyle(isSelected ? Self.accent.opacity(0.85) : Color.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Self.accent : Color.secondary.opacity(0.5))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(isSelected ? Self.accent : dotColor.opacity(0.55))
                    .frame(width: 8, height: 8)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Self.accent : Color.primary)
                        .lineLimit(1)
                    Text("(\(count))")
                        .font(.system(size: 17).monospacedDigit())
                        .foregroundStyle(isSelected ? Self.accent.opacity(0.85) : Color.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Self.accent : Color.secondary.opacity(0.5))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
