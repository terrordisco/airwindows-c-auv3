//
//  TransientTooltip.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  A touch-triggered tooltip for icon-only buttons. iPadOS has no hover
//  tooltips for touch, so a button whose icon isn't self-explanatory (the
//  "make this the startup effect" pin) shows a short dark callout above
//  itself for a couple of seconds after it is tapped, then fades.
//
//  Usage:
//      Button { pin(); showTip = true } label: { … }
//          .transientTooltip("Make this effect default…", isPresented: $showTip)
//

import SwiftUI

public extension View {
    /// Shows `text` in a callout above this view while `isPresented` is true,
    /// and clears `isPresented` after `duration` seconds. Re-tapping while
    /// shown restarts the timer.
    func transientTooltip(
        _ text: String,
        isPresented: Binding<Bool>,
        duration: TimeInterval = 2.5
    ) -> some View {
        modifier(TransientTooltipModifier(text: text, isPresented: isPresented, duration: duration))
    }
}

private struct TransientTooltipModifier: ViewModifier {
    let text: String
    @Binding var isPresented: Bool
    let duration: TimeInterval

    @Environment(\.colorScheme) private var scheme
    /// Bumped on every presentation so `.task(id:)` restarts the timer when
    /// the tooltip is re-triggered while already visible.
    @State private var generation: Int = 0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isPresented {
                    bubble
                        // Hang the bubble above the anchor: its bottom edge
                        // sits 8pt above the anchor's top.
                        .alignmentGuide(.top) { d in d[.bottom] + 8 }
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
                        .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.18), value: isPresented)
            .onChange(of: isPresented) { _, shown in
                if shown { generation += 1 }
            }
            .task(id: generation) {
                guard isPresented else { return }
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                isPresented = false
            }
    }

    private var bubble: some View {
        TooltipBubble(text: text)
    }
}

// MARK: - The bubble

/// The callout itself: dark rounded box with a pointer on one edge. Shared
/// by the transient tooltip (pointer below, centered) and help mode's
/// overlay (pointer on whichever edge faces the control, slid sideways to
/// keep aiming at it when the bubble has been nudged inward).
struct TooltipBubble: View {
    let text: String
    var pointerEdge: VerticalEdge = .bottom
    /// Horizontal offset of the pointer from the bubble's center.
    var pointerOffset: CGFloat = 0

    @Environment(\.colorScheme) private var scheme

    private static let pointerSize: CGFloat = 12
    private static let pointerRise: CGFloat = 6

    var body: some View {
        VStack(spacing: 0) {
            if pointerEdge == .top { pointer }
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: 240)
                .background(RoundedRectangle(cornerRadius: 9).fill(fill))
            if pointerEdge == .bottom { pointer }
        }
        .fixedSize()
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // Inverted surface so the callout reads on both schemes: near-black on
    // white in Day, near-white on dark in Night.
    private var fill: Color { scheme == .dark ? Color(white: 0.93) : Color(red: 0.11, green: 0.11, blue: 0.12) }
    private var ink: Color { scheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : Color.white }

    /// A rotated square, half tucked under the box so only a triangle shows.
    private var pointer: some View {
        Rectangle()
            .fill(fill)
            .frame(width: Self.pointerSize, height: Self.pointerSize)
            .rotationEffect(.degrees(45))
            .offset(x: pointerOffset, y: pointerEdge == .bottom ? -Self.pointerRise : Self.pointerRise)
            .frame(height: Self.pointerRise)
    }
}
