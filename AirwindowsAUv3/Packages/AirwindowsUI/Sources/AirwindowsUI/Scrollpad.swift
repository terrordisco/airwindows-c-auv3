//
//  Scrollpad.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  The "scrollpad": a faint hatched strip along one edge of the parameter
//  field that is a dedicated scroll grab area. A touch on a fader or pot
//  drives that control and never scrolls (see ParameterScrollView), so a
//  dense field needs somewhere guaranteed-empty to scroll from. The full
//  layout's sliders view has one at a fixed inset; the compact layout runs it
//  flush against the container edge, on the left or right — a thumb reaches
//  the near edge of a phone — or off.
//

import SwiftUI

public enum ScrollpadPlacement: String, CaseIterable, Sendable {
    case left, right, off

    /// UserDefaults key (App-Group-shared, like the other layout choices).
    public static let storageKey = "airwindows.scrollpad"

    /// Tap-to-cycle order for the menu row: Left → Right → Off → Left.
    public var next: ScrollpadPlacement {
        switch self {
        case .left: return .right
        case .right: return .off
        case .off: return .left
        }
    }

    public var label: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .off: return "Off"
        }
    }
}
