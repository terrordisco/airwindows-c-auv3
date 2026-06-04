//
//  ParameterScrollView.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Vertical scroll container for the effect workspace, tuned so scrolling never
//  fights the faders and pots inside it.
//
//  The problem
//  -----------
//  The workspace packs draggable faders/pots and a longform description into one
//  tall column. With a normal scroll view, a single-finger drag on a control is
//  ambiguous — it might scroll the page instead of moving the control. We can't
//  reserve scrolling for two fingers either: grabbing two controls at once (a
//  pot in each hand) is a core mixing gesture, and a two-finger scroll would
//  hijack it.
//
//  The model
//  ---------
//  - **Empty space scrolls with one finger** — the gutters between controls, the
//    name/value rows, the description text.
//  - **A touch that STARTS on a control disables scrolling for that gesture**, so
//    the control's own drag handles it. Because scrolling is fully off (not just
//    "needs more fingers"), a second finger landing on a second control adjusts
//    it too — both controls move, nothing scrolls.
//
//  Implemented over a stock SwiftUI `ScrollView` (native momentum, bounce,
//  indicators, dynamic sizing). A zero-size probe locates the backing
//  `UIScrollView`; a touch-down observer raises its pan's `minimumNumberOfTouches`
//  out of reach the instant a touch lands on a registered control region, and
//  drops it back to 1 for empty space. Only this container is affected — the
//  browser/sidebar lists elsewhere keep ordinary scrolling.
//

import SwiftUI

#if canImport(UIKit)
import UIKit

/// Vertical scroll view where empty space scrolls with one finger and controls
/// marked `.scrollDragControl()` keep their drags to themselves.
public struct ParameterScrollView<Content: View>: View {
    @State private var coordinator = ScrollGestureCoordinator()
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ScrollView(.vertical) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                // Zero-size probe; only there to reach the backing UIScrollView.
                .background(
                    ScrollViewAttacher(coordinator: coordinator)
                        .frame(width: 0, height: 0)
                )
        }
        .environment(\.scrollGestureCoordinator, coordinator)
    }
}

public extension View {
    /// Marks this subtree as an interactive drag control inside a
    /// `ParameterScrollView`: a touch starting here won't begin a scroll, so the
    /// control's own drag gesture handles it (and a second finger can grab a
    /// second control without the scroll hijacking either). Empty space around
    /// the control still scrolls with one finger. No-op outside the container.
    func scrollDragControl() -> some View {
        modifier(ScrollDragControlModifier())
    }
}

// MARK: - Coordinator

/// Shared state linking the scroll view, its touch-down observer, and the
/// registered control regions.
final class ScrollGestureCoordinator: NSObject {
    private weak var scrollView: UIScrollView?
    /// Weak so control regions belonging to torn-down effect views drop out on
    /// their own as the user navigates between effects.
    private let controlRegions = NSHashTable<UIView>.weakObjects()
    private let touchObserver = TouchDownObserver()

    /// One finger scrolls empty space.
    private static let scrollTouches = 1
    /// A touch starting on a control sets the requirement out of reach, which
    /// disables scrolling for that whole gesture — so the control (and any
    /// second control grabbed alongside it) is free to move. No realistic touch
    /// count on an iPad plugin reaches this.
    private static let scrollDisabledTouches = 6

    func attach(to scrollView: UIScrollView) {
        guard self.scrollView !== scrollView else { return }
        self.scrollView = scrollView
        scrollView.panGestureRecognizer.minimumNumberOfTouches = Self.scrollTouches

        touchObserver.onTouchDown = { [weak self] location in
            self?.handleTouchDown(at: location)
        }
        if touchObserver.view !== scrollView {
            touchObserver.view?.removeGestureRecognizer(touchObserver)
            scrollView.addGestureRecognizer(touchObserver)
        }
    }

    /// Register a control's view so touches starting on it don't scroll.
    func register(controlRegion view: UIView) {
        controlRegions.add(view)
    }

    /// The instant a touch lands, decide whether this gesture may scroll: no if
    /// it started on a control, yes otherwise. Runs before the pan has moved
    /// enough to begin, so the requirement is correct by the time a scroll could
    /// start. Only the first touch of a sequence is sampled (the observer fails
    /// immediately and re-arms next sequence), so once a drag begins on a
    /// control it stays non-scrolling until every finger lifts.
    private func handleTouchDown(at location: CGPoint) {
        guard let scrollView else { return }
        let onControl = controlRegions.allObjects.contains { region in
            region.window != nil
                && region.convert(region.bounds, to: scrollView).contains(location)
        }
        scrollView.panGestureRecognizer.minimumNumberOfTouches =
            onControl ? Self.scrollDisabledTouches : Self.scrollTouches
    }
}

/// A recognizer that never recognizes — it only reports where the first finger
/// of a sequence touched down, then fails immediately so it can't delay, cancel,
/// or compete with the scroll pan or the SwiftUI control gestures underneath.
private final class TouchDownObserver: UIGestureRecognizer {
    var onTouchDown: ((CGPoint) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if let touch = touches.first, let view {
            onTouchDown?(touch.location(in: view))
        }
        state = .failed
    }
}

// MARK: - Bridging views

/// Zero-size probe placed in the scroll content; walks up to the backing
/// UIScrollView and hands it to the coordinator.
private struct ScrollViewAttacher: UIViewRepresentable {
    let coordinator: ScrollGestureCoordinator

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // The UIScrollView may not be in the hierarchy yet on the first pass;
        // defer so the superview chain is wired up before we walk it.
        DispatchQueue.main.async {
            if let scrollView = uiView.enclosingScrollView {
                coordinator.attach(to: scrollView)
            }
        }
    }
}

private struct ScrollDragControlModifier: ViewModifier {
    @Environment(\.scrollGestureCoordinator) private var coordinator

    func body(content: Content) -> some View {
        content.background(ControlRegionProbe(coordinator: coordinator))
    }
}

/// Transparent probe covering a control; registers its own view (which mirrors
/// the control's frame) with the coordinator.
private struct ControlRegionProbe: UIViewRepresentable {
    let coordinator: ScrollGestureCoordinator?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        coordinator?.register(controlRegion: uiView)
    }
}

private extension UIView {
    /// Nearest ancestor scroll view, or nil if this view isn't inside one.
    var enclosingScrollView: UIScrollView? {
        var candidate: UIView? = superview
        while let current = candidate {
            if let scrollView = current as? UIScrollView { return scrollView }
            candidate = current.superview
        }
        return nil
    }
}

// MARK: - Environment

private struct ScrollGestureCoordinatorKey: EnvironmentKey {
    static let defaultValue: ScrollGestureCoordinator? = nil
}

private extension EnvironmentValues {
    var scrollGestureCoordinator: ScrollGestureCoordinator? {
        get { self[ScrollGestureCoordinatorKey.self] }
        set { self[ScrollGestureCoordinatorKey.self] = newValue }
    }
}

#else

// macOS / non-UIKit fallback: the gesture gating is a touch concept, so this
// degrades to an ordinary vertical scroll view and a no-op control marker.
public struct ParameterScrollView<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ScrollView(.vertical) { content }
    }
}

public extension View {
    func scrollDragControl() -> some View { self }
}

#endif
