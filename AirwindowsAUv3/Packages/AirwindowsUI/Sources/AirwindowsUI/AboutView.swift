//
//  AboutView.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Modal sheet opened from SidebarView's About button. Pure information
//  surface — no audio side effects, not part of any navigation path.
//

import SwiftUI

/// Static credits / license view. Presented as a sheet from the sidebar's
/// About button.
public struct AboutView: View {
    public let onClose: () -> Void

    @Environment(\.colorScheme) private var scheme

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("About")
                    .font(.system(size: 20, weight: .semibold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider().opacity(0.4)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AboutSection(title: "Airwindows Consolidated") {
                        Text("350+ free, open-source audio effects by Chris Johnson, packaged as a single AUv3 plugin for iPad.")
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .lineSpacing(3)
                    }

                    AboutSection(title: "Credits") {
                        VStack(alignment: .leading, spacing: 8) {
                            AboutRow(label: "DSP", value: "Chris Johnson — airwindows.com")
                            AboutRow(label: "Registry", value: "Paul Walker — baconpaul/airwin2rack")
                            AboutRow(label: "iPad port", value: "Sveinbjörn Pálsson")
                        }
                    }

                    AboutSection(title: "License") {
                        Text("MIT License. Free to use, modify, and distribute. No warranty.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }

                    AboutSection(title: "Feedback") {
                        VStack(alignment: .leading, spacing: 8) {
                            AboutLinkRow(
                                label: "Email",
                                display: "sveinbjorn@gmail.com",
                                // swiftlint:disable:next force_unwrapping
                                url: URL(string: "mailto:sveinbjorn@gmail.com?subject=Airwindows%20AUv3%20feedback")!
                            )
                            AboutLinkRow(
                                label: "Report bug",
                                display: "github.com/terrordisco/airwindows-c-auv3",
                                // swiftlint:disable:next force_unwrapping
                                url: URL(string: "https://github.com/terrordisco/airwindows-c-auv3/issues")!
                            )
                        }
                    }

                    AboutSection(title: "Thanks") {
                        Text("Enormous thanks to Chris Johnson for decades of free, meticulously crafted DSP, and to Paul Walker for the consolidated registry that made this port possible.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AirwindowsPalette.surface(scheme))
    }
}

private struct AboutSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(.secondary)
            content()
        }
    }
}

private struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}

/// Tappable variant of AboutRow. Used by the Feedback section to launch
/// mailto: / https:// URLs through the system openURL handler.
private struct AboutLinkRow: View {
    let label: String
    let display: String
    let url: URL

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Link(destination: url) {
                HStack(spacing: 4) {
                    Text(display)
                        .font(.system(size: 13))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .accessibilityLabel("\(label): \(display)")
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("About (light)") {
    AboutView(onClose: {})
        .frame(width: 560, height: 520)
}

#Preview("About (dark)") {
    AboutView(onClose: {})
        .frame(width: 560, height: 520)
        .environment(\.colorScheme, .dark)
}
