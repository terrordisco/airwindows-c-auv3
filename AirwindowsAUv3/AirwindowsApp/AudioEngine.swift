//
//  AudioEngine.swift
//  AirwindowsApp target (host-shell only — NOT used by the AUv3 extension)
//
//  Wires AirwindowsAudioUnit into an AVAudioEngine graph so the
//  standalone host app can do live monitoring: microphone in → AU →
//  speaker. Off by default (the `isRunning` toggle on ContentView's
//  speaker button drives startEngine / stopEngine).
//
//  The component identifier ('AWal' / 'AWin') has to match the values
//  declared in the AirwindowsAUExtension's Info.plist so other AUv3 hosts
//  can find the plugin by the same description.
//
//  Why we register the AU subclass in-process: AVAudioUnit.instantiate
//  goes through the AU component manager. For our own host shell we want
//  the AU loaded directly (no XPC, no extension boundary), so we register
//  the class with `AUAudioUnit.registerSubclass` and then ask the
//  component manager to instantiate it. The extension target ships
//  separately and registers via its Info.plist.
//

import AVFoundation
import AudioToolbox
import Observation

@Observable
final class AudioEngine {
    private var engine: AVAudioEngine?
    private var auNode: AVAudioUnit?
    private var audioUnit: AirwindowsAudioUnit?
    private(set) var viewModel = AirwindowsAudioUnitViewModel()
    private(set) var isLoaded = false

    var isRunning: Bool = false {
        didSet {
            if isRunning {
                startEngine()
            } else {
                stopEngine()
            }
        }
    }

    func setup() {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: fourCharCode("AWal"),
            componentManufacturer: fourCharCode("AWin"),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        // Register the AU class for in-process use
        AUAudioUnit.registerSubclass(
            AirwindowsAudioUnit.self,
            as: desc,
            name: "Airwindows Consolidated AUv3",
            version: 1
        )

        // Create the audio unit directly for the host app
        do {
            let au = try AirwindowsAudioUnit(componentDescription: desc, options: [])
            self.audioUnit = au
            viewModel.configure(with: au)
            isLoaded = true
        } catch {
            print("Failed to create audio unit: \(error)")
        }
    }

    private func startEngine() {
        guard let audioUnit else { return }

        let engine = AVAudioEngine()
        self.engine = engine

        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: fourCharCode("AWal"),
            componentManufacturer: fourCharCode("AWin"),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        // Instantiate AVAudioUnit async
        AVAudioUnit.instantiate(with: desc, options: []) { [weak self] avAudioUnit, error in
            guard let self, let avAudioUnit else {
                print("Failed to instantiate AVAudioUnit: \(error?.localizedDescription ?? "unknown")")
                DispatchQueue.main.async { self?.isRunning = false }
                return
            }

            DispatchQueue.main.async {
                self.auNode = avAudioUnit

                let inputNode = engine.inputNode
                let outputNode = engine.outputNode
                let format = inputNode.outputFormat(forBus: 0)

                engine.attach(avAudioUnit)
                engine.connect(inputNode, to: avAudioUnit, format: format)
                engine.connect(avAudioUnit, to: outputNode, format: format)

                // Update our reference to the new AU instance
                if let au = avAudioUnit.auAudioUnit as? AirwindowsAudioUnit {
                    self.audioUnit = au
                    self.viewModel.configure(with: au)
                }

                do {
                    try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
                    try AVAudioSession.sharedInstance().setActive(true)
                    try engine.start()
                } catch {
                    print("Failed to start audio engine: \(error)")
                    self.isRunning = false
                }
            }
        }
    }

    private func stopEngine() {
        engine?.stop()
        if let node = auNode {
            engine?.detach(node)
        }
        auNode = nil
        engine = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func fourCharCode(_ string: String) -> FourCharCode {
        var result: FourCharCode = 0
        for char in string.utf8.prefix(4) {
            result = (result << 8) | FourCharCode(char)
        }
        return result
    }
}
