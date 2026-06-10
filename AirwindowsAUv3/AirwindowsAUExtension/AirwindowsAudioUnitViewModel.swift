//
//  AirwindowsAudioUnitViewModel.swift
//  AirwindowsAUExtension target — observable bridge between AU and UI
//
//  Sits between the ObjC AirwindowsAudioUnit (in the framework) and the
//  pure-Swift views in the AirwindowsUI package. Two directions of data
//  flow:
//
//    UI → AU      Calls like selectEffect / setParameterValue / setInputLevel
//                 write straight through to the AU's parameter tree, so the
//                 audio thread picks them up on the next render.
//
//    AU → UI      A parameter-tree observer fires for every external value
//                 change (host automation, preset restore, etc.) and walks
//                 the cached @Observable state to mirror it. handleParameter-
//                 Change is the entry point for that path.
//
//  The `ignoreParameterEcho` flag breaks the obvious cycle: when WE write
//  into the parameter tree, the AU dutifully calls the observer back. We
//  set the flag around our own writes so we don't process our own echo.
//
//  PARAMETER ADDRESS MIRRORING
//  ---------------------------
//  Matches AirwindowsAudioUnit.mm's layout one-for-one:
//    0..36   per-effect params (parameterValues[i])
//    37      effectIndex
//    38      inputLevel
//    39      outputLevel
//  Magic numbers are repeated here on purpose — these are the AU's wire
//  protocol; treating them as a shared "37 means effect-index" contract
//  is clearer than reaching across the Swift/ObjC boundary for a constant.
//
//  The `EffectBrowseModel`s exposed to the AirwindowsUI package are pure
//  Swift value types; the browser/detail views never touch the ObjC
//  AirwindowsEffectInfo objects directly.
//

import Foundation
import AudioToolbox
import Observation
import AirwindowsUI

@Observable
final class AirwindowsAudioUnitViewModel {
    private(set) var effectName: String = ""
    private(set) var effectCategory: String = ""
    private(set) var effectDescription: String = ""
    private(set) var effectWhatText: String = ""
    private(set) var effectIsMono: Bool = false
    private(set) var parameterCount: Int = 0
    private(set) var parameterNames: [String] = []
    var parameterValues: [Double] = Array(repeating: 0.5, count: 37)
    private(set) var parameterDisplays: [String] = []
    private(set) var parameterLabels: [String] = []
    private(set) var parameterDefaults: [Double] = Array(repeating: 0.5, count: 37)
    /// Step count for each parameter. 0 = continuous; N>=2 = popup/stepped
    /// with N discrete cases. Detected by sampling `getParameterDisplay`
    /// across the range — see `AirwindowsAudioUnit parameterStepCount(at:)`.
    private(set) var parameterStepCounts: [Int] = Array(repeating: 0, count: 37)
    private(set) var effectIndex: Int = -1

    var inputLevel: Double = 1.0
    var outputLevel: Double = 1.0

    private(set) var allEffects: [AirwindowsEffectInfo] = []
    private(set) var allCategories: [String] = []

    /// Pure Swift mirror of `allEffects` for the UI layer in `AirwindowsUI`.
    private(set) var browseModels: [EffectBrowseModel] = []
    private(set) var countsByCategory: [String: Int] = [:]

    private weak var audioUnit: AirwindowsAudioUnit?
    private var parameterObserverToken: AUParameterObserverToken?
    private var stateRestoreObserver: NSObjectProtocol?
    private var ignoreParameterEcho: Bool = false

    // MARK: - Undo / Redo
    //
    // A single global history of full state snapshots — effect index plus all
    // parameter values and the two level controls. Every *user-initiated*
    // change (fader/pot move, Randomize, Reset, switching effects) records the
    // pre-change state so it can be walked back, and across effect boundaries:
    // undoing past a "switch effect" returns you to the previous effect with
    // its exact values. Host automation and preset restore (the AU→UI path in
    // handleParameterChange) are deliberately NOT recorded — the host owns that
    // timeline, not us.
    //
    // Continuous drags would otherwise flood the stack with one entry per
    // render tick, so consecutive edits to the *same* control within a short
    // window coalesce into one undo step (one step per gesture, roughly).
    private struct StateSnapshot {
        let effectIndex: Int
        let parameterValues: [Double]
        let inputLevel: Double
        let outputLevel: Double
    }

    /// Identifies what changed, so same-control edits can coalesce while a
    /// different control (or a discrete action) always starts a fresh step.
    private enum ChangeKind: Equatable {
        case parameter(Int)
        case inputLevel
        case outputLevel
        case randomize
        case reset
        case effect
    }

    private var undoStack: [StateSnapshot] = []
    private var redoStack: [StateSnapshot] = []
    private var lastChangeKind: ChangeKind?
    private var lastChangeTime: TimeInterval = 0
    /// Set while we replay a snapshot so the writes we make don't themselves
    /// get recorded as new history.
    private var suppressUndoRecording: Bool = false

    /// Consecutive edits to the same control within this window fold into one
    /// undo step. Long enough to absorb a continuous drag, short enough that
    /// two deliberate nudges stay separate.
    private static let undoCoalesceWindow: TimeInterval = 0.6
    /// Cap so a marathon session can't grow history without bound. Snapshots
    /// are tiny (≈40 doubles) so this is generous.
    private static let maxUndoDepth = 100

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init() {}

    deinit {
        if let stateRestoreObserver {
            NotificationCenter.default.removeObserver(stateRestoreObserver)
        }
    }

    func configure(with audioUnit: AirwindowsAudioUnit) {
        self.audioUnit = audioUnit
        allEffects = AirwindowsEngine.allEffects()
        allCategories = AirwindowsEngine.allCategories()
        browseModels = allEffects.map { Self.makeBrowseModel(from: $0) }
        countsByCategory = Dictionary(grouping: browseModels, by: \.category)
            .mapValues(\.count)

        // Observe parameter changes from the host
        parameterObserverToken = audioUnit.parameterTree?.token(byAddingParameterObserver: { [weak self] address, value in
            DispatchQueue.main.async {
                self?.handleParameterChange(address: address, value: value)
            }
        })

        // Re-read the AU whenever it restores host/document state. Some hosts
        // (Cubasis) restore the project AFTER this configure() runs, so the
        // refreshEffectInfo() below sees "no effect"; the AU posts this once it
        // has actually restored, and we re-sync. See
        // AirwindowsAudioUnitDidRestoreStateNotification.
        if let stateRestoreObserver {
            NotificationCenter.default.removeObserver(stateRestoreObserver)
        }
        // The ObjC `…Notification` constant is imported as a Notification.Name.
        stateRestoreObserver = NotificationCenter.default.addObserver(
            forName: .AirwindowsAudioUnitDidRestoreState,
            object: audioUnit,
            queue: .main
        ) { [weak self] _ in
            self?.refreshEffectInfo()
        }

        refreshEffectInfo()
    }

    private static func makeBrowseModel(from info: AirwindowsEffectInfo) -> EffectBrowseModel {
        EffectBrowseModel(
            registryIndex: info.registryIndex,
            name: info.name,
            category: info.category,
            whatText: info.whatText,
            nParams: info.nParams,
            isMono: info.isMono,
            catChrisOrdering: info.catChrisOrdering,
            firstCommitDate: info.firstCommitDate,
            collections: info.collections,
            postURL: info.postURL.flatMap(URL.init(string:)),
            videoURL: info.videoURL.flatMap(URL.init(string:))
        )
    }

    /// Lookup table the UI uses to render the current effect through `EffectBrowseModel`.
    var currentBrowseModel: EffectBrowseModel? {
        guard effectIndex >= 0, browseModels.indices.contains(effectIndex) else { return nil }
        return browseModels[effectIndex]
    }

    /// True when an effect has been picked. Before first selection the AU is
    /// in passthrough mode and the UI should show the browser.
    var hasSelection: Bool {
        effectIndex >= 0
    }

    /// Effects in the same category as the current effect, in Chris order.
    /// Fallback pool for ← Prev | Effect | Next → header navigation when the
    /// browse pool (below) doesn't apply.
    var siblingsInCurrentCategory: [EffectBrowseModel] {
        let cat = effectCategory
        guard !cat.isEmpty else { return [] }
        return browseModels
            .filter { $0.category == cat }
            .sortedByChrisOrdering()
    }

    /// Ordered registry indexes of the list the user last picked from in the
    /// browser — a category, Favorites, "New", or a filtered/search result.
    /// Captured by `setBrowsePool` at selection time so ← Prev | Next → walk
    /// the list the user was actually browsing. Session-only: after a host
    /// restore it's empty and navigation falls back to the effect's category.
    private var browsePoolIndexes: [Int] = []

    /// Snapshot the browser's visible effect list as the prev/next pool.
    func setBrowsePool(_ effects: [EffectBrowseModel]) {
        browsePoolIndexes = effects.map(\.registryIndex)
    }

    /// The list ← Prev | Next → walk: the browse pool when it contains the
    /// current effect, otherwise the current effect's category. The fallback
    /// covers host-restored sessions (no pool yet) and Random picks that
    /// landed outside the browsed list.
    private var navigationSiblings: [EffectBrowseModel] {
        if browsePoolIndexes.contains(effectIndex) {
            return browsePoolIndexes.compactMap { index in
                browseModels.indices.contains(index) ? browseModels[index] : nil
            }
        }
        return siblingsInCurrentCategory
    }

    var previousEffect: EffectBrowseModel? {
        let siblings = navigationSiblings
        guard let idx = siblings.firstIndex(where: { $0.registryIndex == effectIndex }),
              idx > 0 else { return nil }
        return siblings[idx - 1]
    }

    var nextEffect: EffectBrowseModel? {
        let siblings = navigationSiblings
        guard let idx = siblings.firstIndex(where: { $0.registryIndex == effectIndex }),
              idx < siblings.count - 1 else { return nil }
        return siblings[idx + 1]
    }

    /// Loads the awpdoc documentation text for an arbitrary effect (not just
    /// the currently selected one). Falls back to `whatText`.
    ///
    /// Note: the `awpdoc/` directory ships in the framework bundle as a flat
    /// list of `.txt` files (xcodegen adds it as a group, not a folder
    /// reference, so the files land at the bundle root). The lookup must
    /// therefore NOT pass `subdirectory:` — that argument requires a real
    /// folder reference and silently returns nil otherwise.
    func description(for effect: EffectBrowseModel) -> String {
        let bundle = Bundle(for: AirwindowsAudioUnit.self)
        if let docURL = bundle.url(forResource: effect.name, withExtension: "txt"),
           let text = try? String(contentsOf: docURL, encoding: .utf8) {
            return text
        }
        return effect.whatText
    }

    var inputLevelDisplay: String {
        Self.formatLevelAsDb(inputLevel)
    }

    var outputLevelDisplay: String {
        Self.formatLevelAsDb(outputLevel)
    }

    private static func formatLevelAsDb(_ value: Double) -> String {
        if value <= 0.00001 { return "−∞ dB" }
        let db = 20.0 * log10(value)
        return String(format: "%.1f dB", db)
    }

    private func handleParameterChange(address: AUParameterAddress, value: AUValue) {
        guard !ignoreParameterEcho else { return }
        if address < 37 {
            let idx = Int(address)
            if idx < parameterValues.count {
                parameterValues[idx] = Double(value)
                refreshParameterDisplay(at: idx)
            }
        } else if address == 37 {
            let newIndex = Int(value)
            if newIndex != effectIndex {
                effectIndex = newIndex
                audioUnit?.selectEffect(at: newIndex)
                refreshEffectInfo()
            }
        } else if address == 38 {
            inputLevel = Double(value)
        } else if address == 39 {
            outputLevel = Double(value)
        }
    }

    func selectEffect(at index: Int) {
        guard let au = audioUnit else { return }
        // Re-selecting the effect that's already active must NOT reseed
        // defaults. This is the common case after a host (Cubasis, AUM, …)
        // restores a project: the plugin opens to the browser with the
        // restored effect highlighted, and tapping it to return to its
        // parameter page would otherwise wipe the restored values back to
        // defaults. The browser closes via its own onClose, so a no-op here
        // still navigates correctly. (The Reset chip calls the AU directly,
        // so it still reloads defaults on demand.)
        guard index != effectIndex else { return }
        recordChange(.effect)
        au.selectEffect(at: index)
        effectIndex = index
        refreshEffectInfo()
    }

    func selectNextEffect() {
        if let next = nextEffect {
            selectEffect(at: next.registryIndex)
            return
        }
        // Fall back to global wrap-around if not in a category list.
        let count = allEffects.count
        guard count > 0 else { return }
        selectEffect(at: (effectIndex + 1) % count)
    }

    func selectPreviousEffect() {
        if let prev = previousEffect {
            selectEffect(at: prev.registryIndex)
            return
        }
        let count = allEffects.count
        guard count > 0 else { return }
        selectEffect(at: (effectIndex - 1 + count) % count)
    }

    func setParameterValue(_ value: Double, at index: Int) {
        guard let au = audioUnit, index < 37 else { return }
        recordChange(.parameter(index))
        parameterValues[index] = value

        ignoreParameterEcho = true
        defer { ignoreParameterEcho = false }
        if let param = au.parameterTree?.parameter(withAddress: AUParameterAddress(index)) {
            param.value = AUValue(value)
        }
        refreshParameterDisplay(at: index)
    }

    func setInputLevel(_ value: Double) {
        guard let au = audioUnit else { return }
        recordChange(.inputLevel)
        inputLevel = value
        ignoreParameterEcho = true
        defer { ignoreParameterEcho = false }
        if let param = au.parameterTree?.parameter(withAddress: AUParameterAddress(38)) {
            param.value = AUValue(value)
        }
    }

    func setOutputLevel(_ value: Double) {
        guard let au = audioUnit else { return }
        recordChange(.outputLevel)
        outputLevel = value
        ignoreParameterEcho = true
        defer { ignoreParameterEcho = false }
        if let param = au.parameterTree?.parameter(withAddress: AUParameterAddress(39)) {
            param.value = AUValue(value)
        }
    }

    /// Randomize all of the current effect's parameters. Continuous parameters
    /// get a uniform value in 0...1; stepped/popup parameters snap to a random
    /// valid case center so they always land on a real setting rather than
    /// between two. In/Out levels are deliberately left alone — randomizing gain
    /// is rarely useful and risks a sudden volume jump.
    func randomizeParameters() {
        guard audioUnit != nil else { return }
        // One undo step for the whole randomize, not one per parameter.
        recordChange(.randomize)
        suppressUndoRecording = true
        defer { suppressUndoRecording = false }
        for i in 0..<parameterCount {
            let stepCount = i < parameterStepCounts.count ? parameterStepCounts[i] : 0
            let value: Double
            if stepCount >= 2 {
                // Bin center for a randomly chosen case k of N — matches the
                // snap targets used by the stepped fader/pot.
                let k = Int.random(in: 0..<stepCount)
                value = (Double(k) + 0.5) / Double(stepCount)
            } else {
                value = Double.random(in: 0...1)
            }
            setParameterValue(value, at: i)
        }
    }

    /// Reset all of the current effect's parameters to the values the registry
    /// generator provides on a fresh instance.
    func resetParameters() {
        guard let au = audioUnit else { return }
        // Snapshot the pre-reset values so the reset is undoable.
        recordChange(.reset)
        // Re-selecting the current effect re-loads its default parameter values
        // via the registry generator, which is the simplest correct path.
        au.selectEffect(at: effectIndex)
        refreshEffectInfo()
    }

    // MARK: - Undo / Redo engine

    private func captureSnapshot() -> StateSnapshot {
        StateSnapshot(
            effectIndex: effectIndex,
            parameterValues: parameterValues,
            inputLevel: inputLevel,
            outputLevel: outputLevel
        )
    }

    /// Records the current state as an undo point *before* a mutating action is
    /// applied. Call at the top of every user-initiated mutator. Consecutive
    /// edits to the same control within `undoCoalesceWindow` are folded into the
    /// step already on the stack rather than pushing a new one.
    private func recordChange(_ kind: ChangeKind) {
        guard !suppressUndoRecording else { return }

        let now = Date().timeIntervalSinceReferenceDate
        let coalesces: Bool
        switch kind {
        case .parameter, .inputLevel, .outputLevel:
            coalesces = kind == lastChangeKind
                && (now - lastChangeTime) < Self.undoCoalesceWindow
        case .randomize, .reset, .effect:
            // Discrete actions are always their own undo step.
            coalesces = false
        }
        lastChangeKind = kind
        lastChangeTime = now

        guard !coalesces else { return }

        undoStack.append(captureSnapshot())
        if undoStack.count > Self.maxUndoDepth {
            undoStack.removeFirst(undoStack.count - Self.maxUndoDepth)
        }
        // Any fresh change invalidates the redo timeline.
        redoStack.removeAll()
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        redoStack.append(captureSnapshot())
        applySnapshot(snapshot)
    }

    func redo() {
        guard let snapshot = redoStack.popLast() else { return }
        undoStack.append(captureSnapshot())
        applySnapshot(snapshot)
    }

    /// Replays a captured state. Writes go through the normal setters (so the
    /// AU parameter tree and the displayed values stay in sync) but recording
    /// is suppressed so the replay doesn't spawn new history. After a replay we
    /// also drop the coalescing tracker, so the next real edit starts cleanly.
    private func applySnapshot(_ snapshot: StateSnapshot) {
        suppressUndoRecording = true
        defer {
            suppressUndoRecording = false
            lastChangeKind = nil
        }

        if snapshot.effectIndex != effectIndex, let au = audioUnit {
            au.selectEffect(at: snapshot.effectIndex)
            effectIndex = snapshot.effectIndex
            refreshEffectInfo()
        }

        for i in 0..<min(parameterCount, snapshot.parameterValues.count) {
            setParameterValue(snapshot.parameterValues[i], at: i)
        }
        setInputLevel(snapshot.inputLevel)
        setOutputLevel(snapshot.outputLevel)
    }

    func refreshEffectInfo() {
        guard let au = audioUnit else { return }

        effectName = au.currentEffectName
        effectCategory = au.currentEffectCategory
        effectIndex = au.currentEffectIndex
        parameterCount = au.currentParameterCount

        if let info = currentBrowseModel {
            effectWhatText = info.whatText
            effectIsMono = info.isMono
        } else {
            effectWhatText = ""
            effectIsMono = false
        }

        // Load the longform awpdoc documentation. The awpdoc `.txt` files ship
        // flat at the framework bundle root (xcodegen adds the folder as a
        // group, not a folder reference), so the lookup must NOT pass
        // `subdirectory:` — see `description(for:)` for the same rule. Falls
        // back to the short tagline when no awpdoc file exists.
        if let info = currentBrowseModel {
            effectDescription = description(for: info)
        } else if let docURL = Bundle(for: AirwindowsAudioUnit.self).url(
            forResource: effectName, withExtension: "txt"
        ) {
            effectDescription = (try? String(contentsOf: docURL, encoding: .utf8)) ?? effectWhatText
        } else {
            effectDescription = effectWhatText
        }

        // Refresh parameter metadata
        var names: [String] = []
        var displays: [String] = []
        var labels: [String] = []
        var values: [Double] = []
        var defaults: [Double] = []
        var stepCounts: [Int] = []

        for i in 0..<parameterCount {
            names.append(au.parameterName(at: i))
            displays.append(au.parameterDisplay(at: i))
            labels.append(au.parameterLabel(at: i))
            stepCounts.append(au.parameterStepCount(at: i))
            // The AU just refreshed defaults during selectEffectAtIndex; pull
            // current values from the parameter tree so we mirror what the AU
            // has now (which is also the default).
            let v = au.parameterTree?
                .parameter(withAddress: AUParameterAddress(i))?.value ?? 0.5
            values.append(Double(v))
            defaults.append(Double(v))
        }

        // Pad to 37
        while names.count < 37 {
            names.append("")
            displays.append("")
            labels.append("")
            values.append(0)
            defaults.append(0)
            stepCounts.append(0)
        }

        parameterNames = names
        parameterDisplays = displays
        parameterLabels = labels
        parameterValues = values
        parameterDefaults = defaults
        parameterStepCounts = stepCounts

        // Mirror level params from the parameter tree.
        if let inP = au.parameterTree?.parameter(withAddress: AUParameterAddress(38)) {
            inputLevel = Double(inP.value)
        }
        if let outP = au.parameterTree?.parameter(withAddress: AUParameterAddress(39)) {
            outputLevel = Double(outP.value)
        }
    }

    private func refreshParameterDisplay(at index: Int) {
        guard let au = audioUnit, index < parameterCount else { return }
        parameterDisplays[index] = au.parameterDisplay(at: index)
    }
}
