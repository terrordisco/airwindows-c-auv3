//
//  AirwindowsAUView.swift
//  AirwindowsAUExtension target — root SwiftUI view for the AUv3 plugin
//
//  Same plugin UI used by both targets. The host-shell app reaches this
//  same view via ContentView; the AUv3 extension reaches it via
//  AUv3ViewController → UIHostingController → AirwindowsAUView.
//
//  Owns the two top-level UI states:
//
//    - showBrowser:   fullScreenCover that lists every effect by
//                     category. Forced open at launch so the user must
//                     pick something — opening "into" an effect would
//                     hide the breadth of the plugin.
//    - currentBrowseModel (via viewModel): which effect (if any) is
//                     selected. Until something is picked, audio passes
//                     through unchanged and NoSelectionView is shown.
//
//  Everything else — parameter bindings, prev/next nav, theme, level
//  controls — fans out from the viewModel through to EffectDetailView,
//  which lives in the shared AirwindowsUI Swift package.
//

import SwiftUI
import AirwindowsUI

struct AirwindowsAUView: View {
    @Bindable var viewModel: AirwindowsAudioUnitViewModel

    @State private var showBrowser: Bool = false
    @AppStorage("airwindows.darkMode") private var isDarkMode: Bool = false

    /// Tri-state control-style preference, persisted globally:
    /// - `"auto"` (default): pots for effects with `autoPotsThreshold` or more
    ///   parameters, sliders otherwise. Sliders are the friendlier default for
    ///   typical 2–8 parameter effects, and pots pack better when there are
    ///   many parameters.
    /// - `"sliders"` / `"pots"`: explicit user choice that overrides the auto
    ///   rule for every effect until toggled again.
    /// The chip in the header strip flips this between explicit sliders/pots;
    /// "auto" only persists until the first toggle.
    @AppStorage("airwindows.controlStyle") private var controlStylePreference: String = "auto"

    /// Number of parameters at or above which "auto" mode renders pots
    /// instead of sliders. Effects this dense (e.g. ConsoleX, Recurve, EQ
    /// matrices) get hard to scan as a stack of sliders, but read fine as a
    /// grid of small pots.
    private let autoPotsThreshold = 24

    private var effectiveUseRotaryPots: Bool {
        switch controlStylePreference {
        case "pots": return true
        case "sliders": return false
        default: return viewModel.parameterCount >= autoPotsThreshold
        }
    }

    private func toggleControlStyle() {
        // Flip to the opposite of whatever's currently rendered. This works
        // whether the previous state was explicit or coming from the auto
        // rule — once the user touches the chip, "auto" is replaced by an
        // explicit choice.
        controlStylePreference = effectiveUseRotaryPots ? "sliders" : "pots"
    }

    var body: some View {
        detailContent
            // Explicitly override colorScheme so the plugin's theme follows the
            // user's AppStorage preference, not the host's theme (AUM is dark,
            // GarageBand is light, etc.).
            .environment(\.colorScheme, isDarkMode ? .dark : .light)
            .fullScreenCover(isPresented: $showBrowser) {
                // Preserve user context across browser opens: when there's a
                // current effect, preselect its category + highlight it so the
                // preview pane reads as "where you were". On the first launch
                // currentBrowseModel is nil and both args fall through as nil,
                // which keeps the "open clean, no preselection" launch behavior.
                BrowserView(
                    allEffects: viewModel.browseModels,
                    categories: viewModel.allCategories,
                    countsByCategory: viewModel.countsByCategory,
                    initialCategory: viewModel.currentBrowseModel?.category,
                    initialHighlight: viewModel.currentBrowseModel,
                    descriptionProvider: { effect in
                        viewModel.description(for: effect)
                    },
                    onSelect: { effect in
                        viewModel.selectEffect(at: effect.registryIndex)
                    },
                    onClose: { showBrowser = false }
                )
                .environment(\.colorScheme, isDarkMode ? .dark : .light)
            }
            .task {
                // Always open the browser on launch — the user must pick an
                // effect. Uses .task (not onAppear) so the view is fully in the
                // hierarchy before the fullScreenCover transition fires.
                showBrowser = true
            }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let effect = viewModel.currentBrowseModel {
            EffectDetailView(
                effect: effect,
                parameterCount: viewModel.parameterCount,
                parameterNames: viewModel.parameterNames,
                parameterDisplays: viewModel.parameterDisplays,
                parameterLabels: viewModel.parameterLabels,
                parameterStepCounts: viewModel.parameterStepCounts,
                description: viewModel.effectDescription,
                previousName: viewModel.previousEffectInCategory?.name,
                nextName: viewModel.nextEffectInCategory?.name,
                inputDisplay: viewModel.inputLevelDisplay,
                outputDisplay: viewModel.outputLevelDisplay,
                parameterValues: Binding(
                    get: { viewModel.parameterValues },
                    set: { newValues in
                        for (i, v) in newValues.enumerated() where i < viewModel.parameterCount {
                            if v != viewModel.parameterValues[i] {
                                viewModel.setParameterValue(v, at: i)
                            }
                        }
                    }
                ),
                inputLevel: Binding(
                    get: { viewModel.inputLevel },
                    set: { viewModel.setInputLevel($0) }
                ),
                outputLevel: Binding(
                    get: { viewModel.outputLevel },
                    set: { viewModel.setOutputLevel($0) }
                ),
                onPrevious: { viewModel.selectPreviousEffect() },
                onNext: { viewModel.selectNextEffect() },
                onTitleTap: { showBrowser = true },
                onReset: { viewModel.resetParameters() },
                isDarkMode: isDarkMode,
                onToggleTheme: { isDarkMode.toggle() },
                useRotaryPots: effectiveUseRotaryPots,
                onToggleControlStyle: { toggleControlStyle() }
            )
        } else {
            NoSelectionView(onBrowse: { showBrowser = true })
                .environment(\.colorScheme, isDarkMode ? .dark : .light)
        }
    }
}

/// Placeholder shown before the user picks an effect. Audio passes through
/// unchanged until a selection is made.
private struct NoSelectionView: View {
    let onBrowse: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.secondary)

            Text("Pick an effect to begin")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Audio is passing through unchanged.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Button(action: onBrowse) {
                Text("Browse effects")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(AirwindowsPalette.actionButton)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AirwindowsPalette.surface(scheme))
    }
}
