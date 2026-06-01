//
//  EffectDescriptionText.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Renders an Airwindows awpdoc description, promoting a leading Markdown-style
//  `# ` line into a real heading instead of printing the literal `#`.
//

import SwiftUI

/// Displays a longform effect description with its leading `# ` line styled as
/// a heading.
///
/// awpdoc files conventionally open with a one-line summary prefixed by `# `
/// (511 of 521 effects), then a blank line, then the body paragraphs. SwiftUI's
/// built-in Markdown support is inline-only — it renders `**bold**` and links
/// but ignores block-level `#` headings, leaving the raw `#` visible. So we
/// split the heading off ourselves and give it its own type treatment, falling
/// back to plain body text for the handful of effects with no `# ` line.
public struct EffectDescriptionText: View {
    private let heading: String?
    private let bodyText: String

    public init(_ text: String) {
        let parts = Self.split(text)
        self.heading = parts.heading
        self.bodyText = parts.body
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let heading {
                Text(heading)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            if !bodyText.isEmpty {
                Text(bodyText)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Splits a leading `# ` heading line off the body. Returns `(nil, text)`
    /// when the first non-empty line isn't a `# ` heading, so non-conforming
    /// docs and short taglines render unchanged.
    static func split(_ text: String) -> (heading: String?, body: String) {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("# ") else { return (nil, trimmed) }

        guard let newlineIndex = trimmed.firstIndex(of: "\n") else {
            // Heading-only doc, no body.
            return (String(trimmed.dropFirst(2)), "")
        }
        let headingLine = String(trimmed[..<newlineIndex]).dropFirst(2)
        let rest = String(trimmed[trimmed.index(after: newlineIndex)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (String(headingLine), rest)
    }
}

// MARK: - Preview

#Preview("With heading") {
    ScrollView {
        EffectDescriptionText(
            """
            # Galactic is a super-reverb designed specially for pads and space ambient.

            Been working on this for a while on Monday coding-streams! Galactic is an \
            extension of my Verbity reverb, designed for ultimate deep space ambient music.

            It takes in audio and uses the Replace control to determine how much of the \
            new sound coming in should replace the space that's currently there.
            """
        )
        .padding(28)
    }
}

#Preview("No heading (tagline)") {
    EffectDescriptionText("an analog-feel highpass filter that doesn't kill the lows")
        .padding(28)
}
