//
//  PreferencesView.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The plugin's settings sheet. Reached from the Settings row at the bottom
//  of the browser sidebar and from the Settings box in the workspace's bottom
//  bar. Self-contained: it reads and writes the shared @AppStorage scale key
//  directly, so changing the slider rescales the live workspace immediately
//  (AirwindowsAUView reads the same key and re-injects \.uiScale).
//
//  Sections, top to bottom:
//    - Interface scale — a global size slider (100% = the sizing tuned on a
//      13" iPad; sliding down fits more on smaller iPads). Two aligned label
//      rows ground the abstract percentage in real device sizes.
//    - Personalisation — a master switch, ON by default: favorites, the
//      default-effect pin, Save/Recall settings, and the pots/sliders swap.
//      Turning it off strips back to just the effect + controls. The
//      default-effect controls live under it (shown only when enabled).
//    - Plugin window — a live container-size readout (research instrument for
//      the responsive-layout work); hidden when nothing injects the size.
//

import SwiftUI

public struct PreferencesView: View {
    public let onClose: () -> Void

    /// Shared with AirwindowsAUView (which injects it as \.uiScale) and with
    /// every sized view. Writing here rescales the workspace live. Backed by the
    /// App Group store so the scale is shared across the app and every plugin
    /// instance (see UserDefaults.airwindowsShared).
    @AppStorage("airwindows.uiScale", store: UserDefaults.airwindowsShared) private var uiScale: Double = 1.0

    /// Master switch for the personalisation toolkit (favorites, default-effect
    /// pin, Save/Recall settings, pots/sliders swap). ON by default; mirrors the
    /// key AirwindowsAUView reads to gate the on-screen affordances. The default
    /// MUST match AirwindowsAUView's (both read this App-Group-shared key).
    @AppStorage("airwindows.personalisation", store: UserDefaults.airwindowsShared) private var personalisationEnabled: Bool = true

    /// The effect that loads on a fresh launch instead of the browser
    /// ("" = none). Set via the pin button in the browser preview pane;
    /// this sheet shows the current pick and offers the only remove-from-
    /// afar affordance. Same App Group store as the scale and favorites.
    @AppStorage("airwindows.defaultEffect", store: UserDefaults.airwindowsShared) private var defaultEffectName: String = ""

    @Environment(\.colorScheme) private var scheme
    /// Live size of the box the host gave the plugin — research instrument
    /// for the responsive (rack-height / thin-strip) layout work. Injected by
    /// AirwindowsAUView; .zero in bare previews, which hides the section.
    @Environment(\.containerSize) private var containerSize

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().opacity(0.4)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Interface scale")
                        .font(.system(size: 22, weight: .semibold))

                    Text("Sizes the whole interface — controls, text, and spacing — as one piece. Lower percentages fit more on screen; 100% is tuned for a 13\u{2033} iPad. A smaller iPad set to its mark shows the same amount as a 13\u{2033}.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ScaleSlider(scale: $uiScale)
                        .padding(.top, 10)

                    Button {
                        uiScale = Double(UIScaleConfig.reference)
                    } label: {
                        Text("Reset to 100%")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AirwindowsPalette.actionButton)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    Divider()
                        .opacity(0.4)
                        .padding(.top, 18)

                    Text("Personalisation")
                        .font(.system(size: 22, weight: .semibold))
                        .padding(.top, 18)

                    Text("Favorites, a default effect, per-effect saved settings, and the pots/sliders switch. Turn this off for a sparser interface — just the effect and its controls. Anything you've already starred or saved is kept either way; this only shows or hides the controls.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle(isOn: $personalisationEnabled) {
                        Text("Personalisation features")
                            .font(.system(size: 17, weight: .medium))
                    }
                    .tint(AirwindowsPalette.actionButton)
                    .padding(.top, 6)

                    // The default-effect control only matters when the toolkit
                    // is on (the pin that sets it is gated behind the same
                    // toggle), so the whole section follows it.
                    if personalisationEnabled {
                        Divider()
                            .opacity(0.4)
                            .padding(.top, 18)

                        Text("Default effect")
                            .font(.system(size: 22, weight: .semibold))
                            .padding(.top, 18)

                        if defaultEffectName.isEmpty {
                            Text("None. A fresh launch opens the effect browser. To start on a specific effect instead, tap the pin next to its name in the browser preview.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("\(defaultEffectName) loads on a fresh launch instead of the browser. Hosts that restore a session still reopen exactly as left.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            Button {
                                defaultEffectName = ""
                            } label: {
                                Text("Remove default")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(AirwindowsPalette.actionButton)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }

                    // Live readout of the space the host gives the plugin.
                    // Research instrument for the responsive-layout work —
                    // testers can read their host's number straight off this
                    // sheet. Hidden when nothing injected the value (previews).
                    if containerSize != .zero {
                        Divider()
                            .opacity(0.4)
                            .padding(.top, 18)

                        Text("Plugin window")
                            .font(.system(size: 22, weight: .semibold))
                            .padding(.top, 18)

                        Text("\(Int(containerSize.width.rounded())) × \(Int(containerSize.height.rounded())) pt")
                            .font(.system(size: 28, weight: .semibold).monospacedDigit())

                        Text("The space this host is giving the plugin right now. If you're beta testing, this number — together with the host app's name — helps us design the compact layout for small plugin windows.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(AirwindowsPalette.surface(scheme))
    }

    private var header: some View {
        HStack {
            Text("Preferences")
                .font(.system(size: 26, weight: .bold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close preferences")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - Scale slider

/// A native slider with two aligned tick rows: the current percentage plus
/// device-size signposts sitting at the scale where each iPad matches 13"
/// density. The signposts and the live readout share the same x-axis as the
/// slider track (inset by the thumb radius so they line up with the value).
private struct ScaleSlider: View {
    @Binding var scale: Double

    /// Matches `LinearFader`, which reserves half its 22pt handle on each side;
    /// the value travels along a track inset by 11pt. Tick labels inset to match
    /// so the signposts line up with the handle position.
    private let thumbInset: CGFloat = 11

    private var range: ClosedRange<Double> {
        Double(UIScaleConfig.minimum)...Double(UIScaleConfig.maximum)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Top row: live percentage, big and centered over the thumb.
            tickRow { guide in
                Text("\(Int((guide.scale * 100).rounded()))%")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // The same custom fader the parameter rows use: relative-drag (a
            // touch doesn't teleport the handle), Color.primary fill, and a
            // double-tap that resets to 100% — mirroring the per-parameter
            // double-tap-to-default and the "Reset to 100%" button below.
            LinearFader(
                value: $scale,
                in: range,
                defaultValue: Double(UIScaleConfig.reference)
            )

            // Bottom row: iPad-size signposts.
            tickRow { guide in
                Text(guide.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            // Live readout of the user's current setting.
            HStack {
                Spacer()
                Text("\(Int((scale * 100).rounded()))%")
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.top, 6)
        }
    }

    /// Lays out one label per device guide, positioned at that guide's
    /// fractional spot along the (thumb-inset) track.
    private func tickRow<Label: View>(@ViewBuilder label: @escaping ((label: String, scale: CGFloat)) -> Label) -> some View {
        GeometryReader { geo in
            let usable = max(geo.size.width - thumbInset * 2, 1)
            ForEach(UIScaleConfig.deviceGuides, id: \.label) { guide in
                let frac = (guide.scale - UIScaleConfig.minimum)
                    / (UIScaleConfig.maximum - UIScaleConfig.minimum)
                let x = thumbInset + usable * frac
                label(guide)
                    .fixedSize()
                    .position(x: x, y: geo.size.height / 2)
            }
        }
        .frame(height: 18)
    }
}

// MARK: - Preview

#Preview("Preferences") {
    PreferencesView(onClose: {})
        .frame(width: 720, height: 520)
}
