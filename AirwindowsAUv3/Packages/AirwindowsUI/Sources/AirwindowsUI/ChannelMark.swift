//
//  ChannelMark.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The quiet S column at the right of every effect list row, marking the
//  effects whose two channels genuinely interact — wideners, mid/side tools,
//  stereo reverbs. Everything else is left unmarked: upstream's "mono" flag
//  does NOT mean the effect sums to mono (only LeftoMono / RightoMono do); it
//  means each channel is processed on its own, so a stereo signal stays
//  stereo. Marking those "M" read as "this effect is mono", which is wrong,
//  so only the rarer, meaningful case carries a mark. Fixed width keeps the
//  rows aligned whether or not a row shows the letter.
//

import SwiftUI

struct ChannelMark: View {
    let isMono: Bool

    @Environment(\.uiScale) private var uiScale

    var body: some View {
        Text(isMono ? "" : "S")
            .font(.system(size: 11 * uiScale, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(width: 14 * uiScale)
            .accessibilityHidden(true)
    }
}
