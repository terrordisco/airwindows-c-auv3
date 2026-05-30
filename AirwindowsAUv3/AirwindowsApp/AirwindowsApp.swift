//
//  AirwindowsApp.swift
//  AirwindowsApp target — the standalone host-shell app
//
//  Two targets ship in this project:
//    1. AirwindowsApp           — this target. A simple host that loads
//                                 the AU in-process, lets users audition
//                                 effects through the microphone, and
//                                 acts as a place for the AUv3 extension
//                                 to live (required by iOS).
//    2. AirwindowsAUExtension   — the actual AUv3 plugin that other apps
//                                 (AUM, Logic, Cubasis, …) load.
//
//  Both targets present the same SwiftUI UI, sourced from the local
//  AirwindowsUI package in Packages/AirwindowsUI/.
//

import SwiftUI

@main
struct AirwindowsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
