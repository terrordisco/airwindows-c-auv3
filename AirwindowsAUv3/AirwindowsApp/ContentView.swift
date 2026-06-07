//
//  ContentView.swift
//  AirwindowsApp target — root SwiftUI view of the host-shell app
//
//  Owns one AudioEngine (which wraps the AU) and lays out the shared
//  AirwindowsAUView from the AirwindowsUI package. The mic→effect→speaker
//  passthrough is surfaced as the bottom-bar "Live / Muted" chip (app only).
//
//  The shared AirwindowsAUView is the same view used by the AUv3
//  extension — UI parity between standalone and plugin is the point.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var audioEngine = AudioEngine()

    var body: some View {
        Group {
            if audioEngine.isLoaded {
                // Mic → effect → speaker passthrough is exposed as the
                // "Live / Muted" chip in the bottom bar (app only — the AUv3
                // plugin omits it, since the host owns audio routing). This
                // replaces the old floating round button, which overlapped the
                // new bottom bar.
                AirwindowsAUView(
                    viewModel: audioEngine.viewModel,
                    isMonitoring: audioEngine.isRunning,
                    onToggleMonitoring: { audioEngine.isRunning.toggle() }
                )
            } else {
                ProgressView("Loading effects...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            audioEngine.setup()
        }
    }
}
