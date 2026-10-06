//
//  HelpMode.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  "Help": a mode, entered from the menu drawer, in which tapping anything in
//  the workspace or the drawer shows a short bubble explaining what it does
//  instead of doing it. A strip under the header says Help is on and has the
//  Done button that leaves it. Not persisted — it's a moment, not a setting.
//
//  Apple has no touch equivalent of a hover tooltip; the closest native
//  patterns are TipKit's feature tips (proactive, not tap-to-ask) and the
//  Shortcuts app's "?" mode. This follows the latter (Sveinbjörn, 2026-10-06).
//
//  How it fits together
//  --------------------
//  - `HelpMode` is the coordinator: on/off, and the one tip currently shown
//    (its text and where its control is). Owned by CompactWorkspaceView,
//    handed down through the environment.
//  - `.helpTip(text)` marks a control. While Help is on it lays a clear
//    tap-catcher over the control — the control itself never sees the touch —
//    and a tap reports the control's frame in the workspace's coordinate
//    space, so the bubble can be drawn over it.
//  - `HelpTipOverlay` sits once, on the workspace root, and draws the bubble
//    for the active tip: above the control when there is room, below it
//    otherwise, nudged inward so it never leaves the container. Drawing it at
//    the root (not inside each control) keeps it clear of scroll-view
//    clipping and sibling z-order.
//  - The words all live in HelpCopy.swift.
//

import SwiftUI

// MARK: - Coordinator

@MainActor
@Observable
public final class HelpMode {
    /// One shown tip: what to say and where the control is (workspace space).
    public struct ActiveTip: Identifiable, Equatable {
        public let id = UUID()
        public let text: String
        public let anchor: CGRect
    }

    public var isOn: Bool = false {
        didSet { if !isOn { hide() } }
    }
    public private(set) var active: ActiveTip?

    /// How long a bubble stays up after a tap. Re-tapping restarts it.
    public static let duration: TimeInterval = 5
    /// Named coordinate space the anchors are measured in; set on the root.
    public static let coordinateSpace = "airwindows.help"

    @ObservationIgnored private var dismissal: Task<Void, Never>?

    public init() {}

    public func show(_ text: String, anchor: CGRect) {
        dismissal?.cancel()
        active = ActiveTip(text: text, anchor: anchor)
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.duration))
            guard !Task.isCancelled else { return }
            self?.active = nil
        }
    }

    public func hide() {
        dismissal?.cancel()
        active = nil
    }
}

// MARK: - Environment

private struct HelpModeKey: EnvironmentKey {
    static let defaultValue: HelpMode? = nil
}

public extension EnvironmentValues {
    /// The workspace's help coordinator; nil outside a workspace, where
    /// `.helpTip` is inert.
    var helpMode: HelpMode? {
        get { self[HelpModeKey.self] }
        set { self[HelpModeKey.self] = newValue }
    }
}

// MARK: - Marking a control

public extension View {
    /// Marks this view as something Help can explain. While Help is on, a tap
    /// here shows `text` in a bubble instead of reaching the view. nil text
    /// leaves the view untouched.
    ///
    /// `passthrough` lets the tap reach the view as well — for the Menu
    /// button, which must still open the drawer in help mode or the drawer's
    /// own tips could never be reached. The bubble then floats over whatever
    /// the tap opened.
    func helpTip(_ text: String?, passthrough: Bool = false) -> some View {
        modifier(HelpTipModifier(text: text, passthrough: passthrough))
    }
}

private struct HelpTipModifier: ViewModifier {
    let text: String?
    let passthrough: Bool
    @Environment(\.helpMode) private var helpMode
    /// The view's frame in the workspace space, kept current for the
    /// passthrough case (which has no tap-catcher to measure from).
    @State private var frame: CGRect = .zero

    private var isActive: Bool { text != nil && helpMode?.isOn == true }

    func body(content: Content) -> some View {
        content
            .accessibilityHint(isActive ? (text ?? "") : "")
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(HelpMode.coordinateSpace)) } action: { frame = $0 }
            .simultaneousGesture(
                TapGesture().onEnded {
                    if isActive, passthrough, let text { helpMode?.show(text, anchor: frame) }
                },
                including: isActive && passthrough ? .all : .none
            )
            .overlay {
                if isActive, !passthrough, let text {
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                helpMode?.show(text, anchor: geo.frame(in: .named(HelpMode.coordinateSpace)))
                            }
                    }
                    .accessibilityHidden(true)
                }
            }
    }
}

// MARK: - The bubble overlay (one per workspace)

/// Draws the active tip's bubble. Put it in an `.overlay` on the same view
/// that carries `.coordinateSpace(name: HelpMode.coordinateSpace)`.
public struct HelpTipOverlay: View {
    @Environment(\.helpMode) private var helpMode
    @State private var bubbleSize: CGSize = .zero

    private static let margin: CGFloat = 8
    private static let gap: CGFloat = 6

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            if let tip = helpMode?.active {
                let placement = Self.place(anchor: tip.anchor, bubble: bubbleSize, in: geo.size)
                TooltipBubble(
                    text: tip.text,
                    pointerEdge: placement.above ? .bottom : .top,
                    pointerOffset: placement.pointerOffset
                )
                .onGeometryChange(for: CGSize.self) { $0.size } action: { bubbleSize = $0 }
                .offset(x: placement.origin.x, y: placement.origin.y)
                // Invisible until measured, so it never flashes at the corner.
                .opacity(bubbleSize == .zero ? 0 : 1)
                .id(tip.id)
                .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.18), value: helpMode?.active?.id)
    }

    /// Above the control when it fits, else below; slid sideways to stay
    /// inside the container, with the pointer still aimed at the control.
    static func place(anchor: CGRect, bubble: CGSize, in container: CGSize) -> (origin: CGPoint, above: Bool, pointerOffset: CGFloat) {
        let above = anchor.minY - gap - bubble.height >= margin
        let y = above ? anchor.minY - gap - bubble.height : anchor.maxY + gap
        let maxX = max(margin, container.width - bubble.width - margin)
        let x = min(max(anchor.midX - bubble.width / 2, margin), maxX)
        let pointerOffset = anchor.midX - (x + bubble.width / 2)
        return (CGPoint(x: x, y: y), above, pointerOffset)
    }
}

// MARK: - Banner

/// The strip under the workspace header while Help is on.
public struct HelpBanner: View {
    public let onDone: () -> Void
    @Environment(\.colorScheme) private var scheme

    public init(onDone: @escaping () -> Void) {
        self.onDone = onDone
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.secondary)
            Text(HelpCopy.banner)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button(action: onDone) {
                Text(HelpCopy.bannerDone)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AirwindowsPalette.actionButton)
                    .padding(.vertical, 6)
                    .padding(.leading, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Turn help off")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(AirwindowsPalette.subtleSurface(scheme))
        .accessibilityElement(children: .contain)
    }
}
