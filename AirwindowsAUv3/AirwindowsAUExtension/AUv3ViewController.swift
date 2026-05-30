//
//  AUv3ViewController.swift
//  AirwindowsAUExtension target
//
//  The AUv3 extension's entry point. AUv3 hosts (AUM, Logic, Cubasis, …)
//  load this class as the principal view controller of the audio
//  component. The host then calls createAudioUnit(with:) to instantiate
//  the AUAudioUnit it'll talk to for audio processing.
//
//  Two things happen here:
//
//    1. createAudioUnit(with:)  — Called by the host, possibly off the
//       main thread, possibly BEFORE viewDidLoad runs. Creates an
//       AirwindowsAudioUnit (which lives in the AirwindowsDSP framework,
//       not in this extension — see AirwindowsAudioUnit.mm for why) and
//       returns it. The framework hop is what keeps the C++ static
//       registry from initialising twice.
//
//    2. viewDidLoad → configureSwiftUIView  — Mounts the SwiftUI UI
//       (AirwindowsAUView) inside this UIViewController via a
//       UIHostingController. We bind it to the AU through the
//       viewModel, which is what the SwiftUI views observe.
//
//  Order isn't guaranteed: the host may call createAudioUnit before
//  viewDidLoad or after. configureSwiftUIView is therefore called from
//  both sites, and is idempotent (it tears down any existing hosting
//  controller before mounting a new one).
//

import CoreAudioKit
import SwiftUI
import AudioToolbox
import os

private let log = Logger(subsystem: "com.airwindows.consolidated", category: "AUv3")

@MainActor
public class AUv3ViewController: AUViewController, AUAudioUnitFactory {
    var audioUnit: AirwindowsAudioUnit?
    private let viewModel = AirwindowsAudioUnitViewModel()
    private var hostingController: UIHostingController<AirwindowsAUView>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        log.info("viewDidLoad")

        // Suggest a comfortable initial window size to the host. AUv3 hosts
        // use preferredContentSize as the starting frame; users can usually
        // resize after that. Without this, AUM (and others) default to a
        // small wide-short rectangle that crowds the parameter grid.
        preferredContentSize = CGSize(width: 1024, height: 720)

        guard let audioUnit else { return }
        configureSwiftUIView(audioUnit: audioUnit)
    }

    nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        log.info("createAudioUnit called")
        return try DispatchQueue.main.sync {
            let au = try AirwindowsAudioUnit(componentDescription: componentDescription, options: [])
            self.audioUnit = au
            log.info("Audio unit created, params: \(au.currentParameterCount)")

            defer {
                DispatchQueue.main.async {
                    self.configureSwiftUIView(audioUnit: au)
                }
            }

            return au
        }
    }

    private func configureSwiftUIView(audioUnit: AirwindowsAudioUnit) {
        if let host = hostingController {
            host.removeFromParent()
            host.view.removeFromSuperview()
        }

        viewModel.configure(with: audioUnit)

        let content = AirwindowsAUView(viewModel: viewModel)
        let host = UIHostingController(rootView: content)
        self.addChild(host)
        host.view.frame = self.view.bounds
        self.view.addSubview(host.view)
        hostingController = host

        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        self.view.bringSubviewToFront(host.view)
    }
}
