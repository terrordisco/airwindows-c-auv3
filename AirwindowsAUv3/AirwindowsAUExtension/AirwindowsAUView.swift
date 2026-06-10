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

    /// App-only input-monitoring state + toggle. The standalone app passes
    /// these (its mic→effect→speaker passthrough); the AUv3 plugin omits them,
    /// so no monitoring chip shows in the host (the host owns routing).
    var isMonitoring: Bool = false
    var onToggleMonitoring: (() -> Void)?

    /// Shared favorites store (App Group backed). One instance per process,
    /// passed into both the browser and the detail view so the star and the
    /// pinned "Favorites" category stay in sync.
    @State private var favorites = FavoritesStore()

    @State private var showBrowser: Bool = false
    /// True when the browser was force-opened at launch because nothing was
    /// selected yet. If a host then restores an effect late (Cubasis restores
    /// AFTER launch), we use this to dismiss the browser and land on the
    /// restored effect's page instead of leaving it covering the workspace.
    @State private var browserOpenedAtLaunch: Bool = false
    /// The user's place in the browser (category, filter, search, sort).
    /// Owned here — not by BrowserView — so it survives the fullScreenCover
    /// being torn down: reopening the browser lands exactly where the user
    /// left off, instead of resetting to the active effect's category.
    @State private var browserContext = BrowserContext()
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

    /// Global UI scale, injected into the AirwindowsUI views as `\.uiScale`.
    /// 1.0 == reference (13") sizing. Owned here, edited via PreferencesView
    /// (which writes the same key), read by every sized view. Backed by the App
    /// Group store so the scale is shared across the app and all plugin
    /// instances; within one process instances update live.
    @AppStorage("airwindows.uiScale", store: UserDefaults.airwindowsShared) private var uiScale: Double = 1.0
    /// First-launch guard for the auto-match default — once we've sized the
    /// scale to the container, the stored (possibly user-adjusted) value wins.
    /// Shared too, so only the first instance anywhere auto-sets.
    @AppStorage("airwindows.uiScaleAutoSet", store: .airwindowsShared) private var uiScaleAutoSet: Bool = false

    /// Preferences sheet, opened from the workspace bottom bar's Settings box.
    @State private var showPreferences: Bool = false

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
        GeometryReader { geo in
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Explicitly override colorScheme so the plugin's theme follows
                // the user's AppStorage preference, not the host's theme (AUM is
                // dark, GarageBand is light, etc.).
                .environment(\.colorScheme, isDarkMode ? .dark : .light)
                // Global UI scale: every sized view in AirwindowsUI reads this.
                .environment(\.uiScale, CGFloat(uiScale))
                // First launch: size the scale to the container so a smaller
                // iPad starts at the same density a 13" shows at 100%. Runs on
                // size changes but no-ops after the one-time auto-set.
                .task(id: geo.size) { autoMatchScaleIfNeeded(geo.size) }
                .sheet(isPresented: $showPreferences) {
                    PreferencesView(onClose: { showPreferences = false })
                        .environment(\.colorScheme, isDarkMode ? .dark : .light)
                }
                .fullScreenCover(isPresented: $showBrowser) {
                // The browser reopens into the persistent browserContext —
                // whatever category/filter/search the user last had — with the
                // active effect highlighted so the preview pane still reads as
                // "where you were". On a clean first launch the context is
                // empty and nothing is preselected.
                BrowserView(
                    allEffects: viewModel.browseModels,
                    categories: viewModel.allCategories,
                    countsByCategory: viewModel.countsByCategory,
                    context: $browserContext,
                    initialHighlight: viewModel.currentBrowseModel,
                    descriptionProvider: { effect in
                        viewModel.description(for: effect)
                    },
                    favorites: favorites,
                    onSelect: { effect, pool in
                        // Pool first: selecting swaps the effect, and the
                        // prev/next labels should resolve against the list the
                        // user picked from right away.
                        viewModel.setBrowsePool(pool)
                        viewModel.selectEffect(at: effect.registryIndex)
                    },
                    onClose: { showBrowser = false }
                )
                .environment(\.colorScheme, isDarkMode ? .dark : .light)
                // fullScreenCover doesn't reliably inherit custom environment
                // values, so pass the scale explicitly (same reason colorScheme
                // is re-applied above). Without this the browser sidebar renders
                // at scale 1.0 while the workspace uses the real scale, so the
                // Settings box and the first column stop matching width.
                .environment(\.uiScale, CGFloat(uiScale))
            }
            .task {
                // Open the browser on launch ONLY when nothing is selected —
                // a clean first launch, where the user must pick something and
                // we want to show the breadth of the plugin. When a host has
                // already restored a session with an effect active (AUM), skip
                // the browser and land straight on that effect's page. Some
                // hosts (Cubasis) restore LATER, after this runs — that case is
                // handled by the onChange below. Uses .task (not onAppear) so
                // the view is fully in the hierarchy before the fullScreenCover
                // transition fires.
                if viewModel.hasSelection {
                    showBrowser = false
                } else {
                    showBrowser = true
                    browserOpenedAtLaunch = true
                }
            }
            .onChange(of: viewModel.effectIndex) { _, newIndex in
                // A late host restore (Cubasis) brought in an effect after we
                // auto-opened the browser at launch. Dismiss it so we land on
                // the restored effect's parameter page, "exactly as left".
                if browserOpenedAtLaunch, newIndex >= 0 {
                    browserOpenedAtLaunch = false
                    showBrowser = false
                }
            }
        }
    }

    /// Opens the browser. If the user has never browsed in this session but an
    /// effect is active (a host-restored session), seed the context with that
    /// effect's category so the browser opens "where you were". Once the user
    /// has picked any category themselves, their last context always wins —
    /// the active effect's category never overrides it.
    private func openBrowser() {
        if browserContext.selectedCategory == nil,
           let current = viewModel.currentBrowseModel {
            browserContext.selectedCategory = current.category
        }
        showBrowser = true
    }

    /// First-launch auto-match: derive the starting scale from the container's
    /// short side so a smaller iPad opens at the same density a 13" shows at
    /// 100%. One-shot — guarded by `uiScaleAutoSet` — and ignores the early
    /// zero/garbage sizes SwiftUI proposes before first real layout.
    private func autoMatchScaleIfNeeded(_ size: CGSize) {
        guard !uiScaleAutoSet else { return }
        let shortSide = min(size.width, size.height)
        guard shortSide > 100 else { return }
        uiScale = Double(UIScaleConfig.autoScale(forShortSide: shortSide))
        uiScaleAutoSet = true
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
                parameterDefaults: viewModel.parameterDefaults,
                description: viewModel.effectDescription,
                previousName: viewModel.previousEffect?.name,
                nextName: viewModel.nextEffect?.name,
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
                onTitleTap: { openBrowser() },
                onReset: { viewModel.resetParameters() },
                onRandomize: { viewModel.randomizeParameters() },
                onUndo: { viewModel.undo() },
                onRedo: { viewModel.redo() },
                canUndo: viewModel.canUndo,
                canRedo: viewModel.canRedo,
                isDarkMode: isDarkMode,
                onToggleTheme: { isDarkMode.toggle() },
                useRotaryPots: effectiveUseRotaryPots,
                onToggleControlStyle: { toggleControlStyle() },
                favorites: favorites,
                onOpenSettings: { showPreferences = true },
                isMonitoring: isMonitoring,
                onToggleMonitoring: onToggleMonitoring
            )
        } else {
            NoSelectionView(onBrowse: { openBrowser() })
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
