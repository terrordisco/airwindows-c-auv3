//
//  ChannelMark.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The quiet ((s)) glyph at the right of an effect list row, marking the
//  effects whose two channels genuinely interact — wideners, mid/side tools,
//  stereo reverbs. Everything else is left unmarked: upstream's "mono" flag
//  does NOT mean the effect sums to mono (only LeftoMono / RightoMono do); it
//  means each channel is processed on its own, so a stereo signal stays
//  stereo. Marking those "M" read as "this effect is mono", which is wrong,
//  so only the rarer, meaningful case carries a mark.
//
//  The glyph is built from type, not an image, so it scales with `uiScale`,
//  takes the row's ink colour, and stays crisp: an s flanked by two pairs of
//  parentheses, the inner pair smaller than the outer — a little radiating
//  "stereo" mark. Fixed width keeps rows aligned whether or not they show it.
//

import SwiftUI

struct ChannelMark: View {
    let isMono: Bool

    @Environment(\.uiScale) private var uiScale

    var body: some View {
        Group {
            if isMono {
                Color.clear
            } else {
                StereoGlyph()
            }
        }
        .frame(width: 30 * uiScale, height: 14 * uiScale)
        .accessibilityHidden(true)
    }
}

/// `((s))` — outer parentheses at full size, inner pair smaller, lowercase s
/// in the middle. Everything is vertically centered on the s so the nested
/// pairs read as one symbol rather than three characters.
struct StereoGlyph: View {
    @Environment(\.uiScale) private var uiScale

    var body: some View {
        let outer = 13 * uiScale
        let inner = 9 * uiScale
        let core = 11 * uiScale
        HStack(alignment: .center, spacing: -0.5 * uiScale) {
            Text("(").font(.system(size: outer, weight: .regular, design: .rounded))
            Text("(").font(.system(size: inner, weight: .medium, design: .rounded))
            Text("s")
                .font(.system(size: core, weight: .medium, design: .rounded))
                .padding(.horizontal, 0.5 * uiScale)
            Text(")").font(.system(size: inner, weight: .medium, design: .rounded))
            Text(")").font(.system(size: outer, weight: .regular, design: .rounded))
        }
        .foregroundStyle(.secondary)
        .fixedSize()
    }
}

#Preview("Stereo glyph") {
    VStack(alignment: .leading, spacing: 12) {
        HStack { Text("Galactic"); Spacer(); ChannelMark(isMono: false) }
        HStack { Text("Slew"); Spacer(); ChannelMark(isMono: true) }
        HStack { Text("Wider"); Spacer(); ChannelMark(isMono: false) }
    }
    .padding(24)
    .frame(width: 260)
}
