//
//  ChannelMark.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The quiet M / S column at the right of every effect list row: M for a
//  mono effect, S for stereo. Deliberately understated — small, secondary
//  ink, fixed width so the letters line up down the list — because it is a
//  signifier, not a label. Every effect is one or the other, so neither is
//  left unmarked.
//

import SwiftUI

struct ChannelMark: View {
    let isMono: Bool

    @Environment(\.uiScale) private var uiScale

    var body: some View {
        Text(isMono ? "M" : "S")
            .font(.system(size: 11 * uiScale, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.secondary.opacity(isMono ? 0.9 : 0.55))
            .frame(width: 14 * uiScale)
            .accessibilityHidden(true)
    }
}
