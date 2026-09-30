//
//  BrowserControls.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Pieces shared by the browser drawer and the workspace, collected here when
//  the original full-size layout (three-column BrowserView + SidebarView +
//  EffectDetailView) was retired on 2026-09-30 and the compact layout became
//  the only layout:
//
//    - BrowserContext      the user's place in the browser, owned by
//                          AirwindowsAUView so it outlives the drawer
//    - CollectionTabStrip  Recommended / Basic / Latest filter chips
//    - SearchField         the browser's search box
//    - LinkChip            blog-post / video chip that opens a URL
//    - ScrollHatchGutter   the scrollpad's hatch pattern
//

import SwiftUI

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

// MARK: - Collection tab strip

struct CollectionTabStrip: View {
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
                    ActionButton(
                        text: item.rawValue,
                        role: .toggle(isOn: selection == item),
                        accessibility: item.rawValue,
                        action: { selection = (selection == item) ? .all : item }
                    )
                }
            }
        }
    }
}

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

// MARK: - Search field

struct SearchField: View {
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

// MARK: - Link chip

struct LinkChip: View {
    let url: URL
    let systemName: String
    let text: String?
    let accessibility: String

    @Environment(\.openURL) private var openURL

    init(url: URL, systemName: String, text: String? = nil, accessibility: String) {
        self.url = url
        self.systemName = systemName
        self.text = text
        self.accessibility = accessibility
    }

    var body: some View {
        ActionButton(
            systemName: systemName,
            text: text,
            role: .outlined,
            accessibility: accessibility,
            action: { openURL(url) }
        )
    }
}

// MARK: - Scrollpad hatch

struct ScrollHatchGutter: View {
    private static let lineSpacing: CGFloat = 5
    private static let lineThickness: CGFloat = 2
    /// Center-to-center distance between hatch lines; also the amount the
    /// caller insets to drop exactly one line off an edge.
    static let lineStep: CGFloat = lineSpacing + lineThickness

    var body: some View {
        Canvas { context, size in
            let step = Self.lineStep
            var y: CGFloat = 0
            while y <= size.height {
                let line = Path(CGRect(x: 0, y: y, width: size.width, height: Self.lineThickness))
                context.fill(line, with: .color(Color(uiColor: .separator)))
                y += step
            }
        }
        .opacity(0.4)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Horizontal swipe

enum HorizontalSwipe { case left, right }

extension View {
    /// Reports a decisive horizontal swipe — mostly sideways, at least 60pt —
    /// without stealing vertical scrolling from lists underneath (a vertical
    /// ScrollView claims vertical drags; this only fires when the drag is
    /// clearly horizontal). Used for "swipe back" and "swipe to close" on the
    /// drawers, mirroring the system's edge-swipe navigation.
    func onHorizontalSwipe(_ handler: @escaping (HorizontalSwipe) -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 24, coordinateSpace: .local)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) >= 60, abs(dx) > abs(dy) * 1.5 else { return }
                    handler(dx > 0 ? .right : .left)
                }
        )
    }
}
