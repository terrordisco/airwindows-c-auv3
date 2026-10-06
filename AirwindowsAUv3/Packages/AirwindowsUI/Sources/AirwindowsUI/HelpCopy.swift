//
//  HelpCopy.swift
//  AirwindowsUI package — shared by AirwindowsApp + AirwindowsAUExtension
//
//  EVERY help-mode tooltip lives in this one file. Turn Help on from the
//  menu, tap anything, and the text that appears comes from here. Edit the
//  strings freely — nothing else needs to change. Sentence case, plain
//  words, two sentences at most (the bubble is 240pt wide).
//
//  The two `parameter…` functions build the text for a fader / pot from its
//  name and state; edit the sentences inside them the same way.
//

import Foundation

public enum HelpCopy {

    // MARK: Help mode itself

    /// The strip under the header while Help is on.
    public static let banner = "Help is on. Tap anything to see what it does."
    public static let bannerDone = "Done"

    // MARK: Workspace header

    public static let browserButton = "Opens the effect browser: every effect by category, search, favorites and new arrivals."
    public static let previousEffect = "Goes to the previous effect in the list you're browsing."
    public static let nextEffect = "Goes to the next effect in the list you're browsing."
    public static let effectTitle = "The current effect and its category. Use the arrows either side to step through the list."
    public static let favoriteStar = "Adds this effect to your favorites, or removes it. Favorites have their own category in the browser."
    public static let menuButton = "Opens the menu: undo and redo, randomize and reset, remembered settings, view options and help."

    // MARK: Levels row

    public static let inputLevel = "Level into the effect. Drag up or down to change it; double-tap to return to 0 dB."
    public static let outputLevel = "Level out of the effect. Drag up or down to change it; double-tap to return to 0 dB."
    public static let stereoChip = "This effect processes left and right together as one stereo signal. Effects without this mark treat each channel on its own."

    // MARK: Parameters

    /// A fader or pot that can be moved.
    /// - name: the parameter's name ("Cutoff")
    /// - stepCount: 0 for a continuous control, otherwise how many settings it has
    /// - lockingEnabled: true when "Long Press to Lock Parameter" is on
    public static func parameter(name: String, stepCount: Int, lockingEnabled: Bool) -> String {
        var text = "\(name): drag to change it. Double-tap to return it to its factory default."
        if stepCount >= 2 {
            text += " It has \(stepCount) settings and snaps to the nearest one."
        }
        if lockingEnabled {
            text += " Long press to lock it so Randomize and Reset leave it alone."
        }
        return text
    }

    /// A fader or pot that is locked.
    public static func lockedParameter(name: String) -> String {
        "\(name) is locked: Randomize and Reset leave it alone, and it can't be dragged. Long press to unlock it."
    }

    public static let scrollpad = "The scrollpad. Drag here to scroll the controls without touching any of them."

    // MARK: Below the parameters

    public static let tagline = "Chris Johnson's one-line description of the effect."
    public static let description = "Chris Johnson's full write-up of the effect, from airwindows.com."
    public static let randomEffect = "Loads a random effect from the whole catalogue."

    // MARK: Menu drawer rows

    public static let undo = "Takes back the last change to this effect's settings."
    public static let redo = "Restores the change Undo took back."
    public static let addFavorite = "Adds this effect to your favorites. Favorites have their own category in the browser."
    public static let removeFavorite = "Removes this effect from your favorites."
    public static let makeDefaultEffect = "Makes this the effect that loads when Airwindows opens, instead of the browser."
    public static let removeDefaultEffect = "Airwindows will open with the browser again instead of this effect."
    public static let tempoSync = "Sets this effect's tempo from the host's tempo and keeps it in step."
    public static let randomize = "Sets every control to a random value, except locked ones and the In/Out levels. One Undo takes it all back."
    public static let limiter = "A safety limiter after the effect, clamping the output at 0 dB — for the wild settings Randomize can land on. Off by default."
    public static let longPressLock = "When on, a long press on a control locks it so Randomize and Reset leave it alone."
    public static let reset = "Returns every control to the effect's factory defaults, except locked ones and the In/Out levels."
    public static let rememberSettings = "Saves this effect's current settings. The effect still opens with factory defaults; Recall brings yours back."
    public static let recallSettings = "Applies the settings you remembered for this effect, as one undoable step."
    public static let forgetSettings = "Deletes the remembered settings for this effect."
    public static let persistentRandomButton = "Keeps the Random Effect button in a bar at the bottom of the screen instead of at the end of the page."
    public static let potsSliders = "Shows the parameters as a grid of pots or a column of sliders."
    public static let nightMode = "Auto follows the host app's look; Night and Day force dark or light."
    public static let scrollpadSetting = "Which edge the scrollpad sits on, left or right — or off."
    public static let interfaceScale = "Makes everything in the plugin bigger or smaller."
    public static let inputMonitoring = "Sends the microphone through the effect to the speaker, so you can hear it in the app."
    public static let about = "Version, credits, licence, and where the sound comes from."
}
