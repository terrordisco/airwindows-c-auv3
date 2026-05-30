//
//  ContentView.swift
//  AirwindowsApp target — root SwiftUI view of the host-shell app
//
//  Owns one AudioEngine (which wraps the AU) and lays out the shared
//  AirwindowsAUView from the AirwindowsUI package on top, with a small
//  floating "monitor through mic" toggle in the bottom-right corner.
//
//  The shared AirwindowsAUView is the same view used by the AUv3
//  extension — UI parity between standalone and plugin is the point.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var audioEngine = AudioEngine()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if audioEngine.isLoaded {
                AirwindowsAUView(viewModel: audioEngine.viewModel)

                // Audio passthrough toggle — microphone in, effect out, to the
                // speaker. Off by default so the app opens silently.
                Button {
                    audioEngine.isRunning.toggle()
                } label: {
                    Image(systemName: audioEngine.isRunning ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(audioEngine.isRunning ? Color.accentColor : .secondary)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(20)
                .accessibilityLabel(audioEngine.isRunning ? "Mute audio passthrough" : "Start audio passthrough")
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
