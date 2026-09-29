//
//  SoftHyphenation.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  Effect names are CamelCase compounds ("CrunchyGrooveWear",
//  "ConsoleMDBuss") with no spaces, so when one has to wrap — the browser's
//  description pane at 26pt in a 300pt column — the layout engine breaks
//  wherever it runs out of room: "CrunchyGrooveWea / r". Inserting a SOFT
//  HYPHEN (U+00AD, InDesign's "discretionary hyphen") before each internal
//  capital gives Core Text sanctioned break points instead: the character is
//  invisible unless a break lands on it, and then it draws as a hyphen —
//  "CrunchyGroove- / Wear".
//
//  Only for text that can wrap. Single-line, `minimumScaleFactor` labels
//  never break, so they use the plain name.
//

import Foundation

public extension String {
    /// The string with a soft hyphen (U+00AD) before every capital letter that
    /// follows a lowercase letter or a digit, so a CamelCase compound wraps at
    /// its word joins ("Console8Buss-Hype", "CrunchyGroove-Wear"). A run of
    /// capitals stays together ("ADClip7", "ConsoleMDBuss" → "Console-MDBuss").
    var camelCaseSoftHyphenated: String {
        var out = ""
        out.reserveCapacity(count + 4)
        var previous: Character?
        for ch in self {
            if ch.isUppercase, let prev = previous, prev.isLowercase || prev.isNumber {
                out.append("\u{00AD}")
            }
            out.append(ch)
            previous = ch
        }
        return out
    }
}
