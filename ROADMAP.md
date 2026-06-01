# Roadmap

## Now

(empty — beta is live, awaiting tester feedback)

## Next

- [ ] Performance test on iPad after first TestFlight — effects are very lean DSP-wise, expected CPU draw is low. Look for ways to measure: AUM's per-plugin CPU readout, Instruments Time Profiler attached to the host, or Logic's CPU meter when loaded as AUv3. Goal: confirm the plugin doesn't tank performance even with effect-switching and large state. #feature
- [ ] Talk to baconpaul (airwin2rack consolidated author) — courtesy heads-up, not a dealbreaker per Chris #chore
- [ ] Verify the 6 best-guess category assignments in `category_overrides.json` (BitDualPan→Stereo, CStrip→Effects, PearLiteEQ→Filter, PunchyDeluxe→Dynamics, PunchyGuitar→Dynamics, WoodenBox→Ambience, X2Buss→Consoles) — these effects had no whatText, no awpdoc, and no predecessor in the registry, so the category was inferred from the name. Open the airwindows.com blog post for each and confirm. #polish
- [ ] Full effect descriptions — for the 12 remaining effects with no blog post match, scrape long-form description from airwindows.com (or write manual fallback). Target: every effect has a real description, no empty states. **TestFlight 2.** Note: 10 missing descriptions already filled this session via fetch_missing_descriptions.py. #feature
- [ ] Personalisation features off by default — favorites, per-effect saved settings, personal notes, fader↔pot swap all live behind opt-in toggles in the settings screen. Default Airwindows experience stays sparse; users who want the toolkit turn it on. #feature
- [ ] Favorites — star toggle in EffectDetailView, persist, surface as a "Favorites" filter tab alongside Recommended/Basic/Latest (not a category). Also rises to top of lists. Off by default per the personalisation toggle above. #feature
- [ ] Per-effect saved settings — when a specific effect is reopened, it remembers the user's preferred parameter values (the last-touched ones, OR an explicit "save my defaults for this effect" action). Persists across plugin instances, sessions, and app launches. Distinct from AU fullState/preset (which is global plugin state); this is per-effect-name memory. Likely needs a small UserDefaults-backed dictionary keyed by effect name. Off by default. #feature
- [ ] Personal notes per effect — free-text field attached to each effect, visible in the EffectDetailView and/or browser preview. Persists locally. Helps users record context like "this is great on snare bus" or "Sven's vocal chain step 3". Reuses the same UserDefaults-style store as favorites + per-effect settings. Off by default. #feature
- [ ] Polish to "Apple built this" — haptics, context menus, animations on state changes #polish
- [ ] Open source packaging — CI workflow, build instructions, contributor guide (after repo is public) #chore
- [ ] Accessibility pass — labels, VoiceOver, keyboard support #polish

## Later

- [ ] Rack-sized UI experiments — evaluate after beta feedback. Tested Cubasis/AUM/Logic Pro on iPad: no single rack standard, all hosts open in some compact form. Worth seeing if users want a denser fixed-height layout. #question
- [ ] Recently used / most used collections #feature
- [ ] Auto-update mechanism for weekly upstream effects #chore
  - Detection: poll airwindows.com/feed/ (RSS — fires fastest) and
    baconpaul/airwin2rack git log (DSP — lags Chris's post by days).
    Open GitHub issue per new event.
  - Integration: bot PR runs scripts/fetch_effect_links.py (incremental
    via RSS) + upstream updateToLatest.sh. Merges only if CI build passes.
  - Release: Fastlane pipeline, TestFlight auto-upload. Submit-to-store
    trigger (weekly vs monthly vs tag-push) deferred until real user
    feedback — some users find rapid release cadence annoying.
  - **Manual-edit safeguard:** maintain a manifest of files we've edited
    by hand (awpdoc descriptions we wrote ourselves, category overrides,
    name fixups, etc.). The auto-update job MUST NOT silently overwrite
    these. If upstream removes or changes a file we've manually edited,
    the bot opens a flagged issue / fails the PR check rather than
    discarding our edit. Same rule for any awpdoc we scraped from the
    blog (`fetch_missing_descriptions.py` output) — once shipped, treat
    as protected unless the diff is reviewed.
- [ ] App Store submission #milestone
- [ ] Community launch — iPad music forums, media outreach with Chris's blessing #milestone

## Done

- [x] Cubasis state restore showed "No effect selected" — root-caused via device os_log to a UI-sync race, NOT a persistence failure. Cubasis restores the project via `setFullStateForDocument:` ~270ms AFTER the view model configures and reads a stale effectIndex (-1); Apple suppresses parameter observers during state restore, so the UI never learned the effect had loaded. Fix: AU posts `AirwindowsAudioUnitDidRestoreState` after restore; the view model observes it and re-reads. Also added matching `fullStateForDocument`/`setFullStateForDocument:` overrides (the *ForDocument variant is what Cubasis uses; AUM uses plain fullState). Verified restoring effect + params in Cubasis (2026-06-01) #feature
- [x] Reopen exactly as left — launch now opens the browser ONLY on a fresh launch (nothing selected); when a host restored an effect, lands directly on its parameter page. Late restores (Cubasis) dismiss the auto-opened browser via onChange. Reverses the earlier "always open to browser" preference, which the user retracted (2026-06-01) #feature
- [x] Double-tap fader/pot to reset to default — the gesture machinery existed but was dead: the relative-drag `DragGesture(minimumDistance: 0)` swallowed the taps (switched to `.simultaneousGesture(TapGesture(count: 2))`), the slider was never given a `defaultValue`, and the pot used a hardcoded 0.5. Now both reset to each parameter's real registry default, threaded from `viewModel.parameterDefaults` through ParameterGrid (2026-06-01) #feature
- [x] Longform effect description now shows in EffectDetailView — was silently broken: `refreshEffectInfo()` looked up awpdoc with `subdirectory: "awpdoc"` but xcodegen flattens the folder to the bundle root, so the lookup always returned nil and fell back to the short tagline. Routed through the already-correct `description(for:)` helper. Also added shared `EffectDescriptionText` that promotes the awpdoc's leading `# ` line into a styled heading instead of printing a literal `#` (used in both the detail view and browser preview) (2026-06-01) #feature
- [x] First TestFlight release — 0.1 build 1 uploaded to App Store Connect, processed, approved for external testing. Public link live at testflight.apple.com/join/NgQkcU5h. Fixed three archive-validator gotchas along the way: MARKETING_VERSION/CURRENT_PROJECT_VERSION had to be set in build settings (Info.plist literals weren't enough for Xcode 16), AirwindowsDSP needed SKIP_INSTALL=YES (embedded frameworks shouldn't be installable products), and the extension was duplicating the framework instead of linking-only against the host app's copy (`@executable_path/../../Frameworks` added to LD_RUNPATH_SEARCH_PATHS). Mac (Designed for iPad), Mac Catalyst, and Vision Pro all explicitly excluded — iPad-only (2026-05-31) #milestone
- [x] App Store Connect record — bundle IDs registered under com.terrordisco.*, app record created, metadata + categories + age rating + privacy questionnaire + Privacy Policy URL all filled. Copyright reads "2026 Chris Johnson, Paul Walker, Sveinbjörn Pálsson" — ordered by contribution weight, not legal claim. Description rewritten in user's voice (Chris's weekly cadence, Patreon, no-UI desktop convention, "trust your ears"). App Store version 1.0 stays unsubmitted; TestFlight cycle uses 0.x builds (2026-05-31) #chore
- [x] Beta signup landing page — live at terrordisco.github.io/airwindows-c-auv3/ via GitHub Pages on main /docs. Captures emails before revealing TestFlight link so we own the tester list (Apple's public link tells us nothing). Discord pill alongside, not required. Self-hosted Cloudflare Worker + KV backend at airwindows-beta-signup.svei.workers.dev because third-party form services cap at 50–100 submissions/month and we'd rather own the data. Worker code lives in signup-worker/, ~80 lines. Privacy policy at /privacy.html doubles as the ASC-required URL (2026-05-31) #feature
- [x] Beta feedback channel — added Feedback section in AboutView with mailto:sveinbjorn@gmail.com (subject pre-filled "Airwindows AUv3 feedback") and tappable link to github.com/terrordisco/airwindows-c-auv3/issues. New AboutLinkRow component mirrors AboutRow with a chevron affordance. Also named the iPad-port credit row "Sveinbjörn Pálsson" instead of the generic "AUv3 adaptation" placeholder (2026-05-30) #feature
- [x] Public GitHub repo — live at github.com/terrordisco/airwindows-c-auv3. README + LICENSE (MIT) + CONTRIBUTING + .gitignore. terrordisco is the user's GitHub org for music projects. Pushed private first, flipped public after inspection (2026-05-30) #chore
- [x] Code accessibility pass — file-level headers added to 19 entry-point + shared-UI files explaining the framework split, threading model, parameter address layout, dual-processor pattern, three-language stack (Swift → ObjC → ObjC++ → C++), override-JSON layer, and where each SwiftUI component sits in the hierarchy. Existing type-level docstrings left intact. Fixed one wrong inline comment in AirwindowsAudioUnit.mm (2026-05-30) #chore
- [x] State persistence re-verified after the 2026-05-08 setFullState ordering fix — opens, runs, audio passes through in AUM, Logic, Loopy Pro, Cubasis, GarageBand (2026-05-30) #feature
- [x] Test in other AUv3 hosts — Cubasis, GarageBand, Logic Pro, Loopy Pro, AUM all load, render UI, pass audio (2026-05-30) #feature
- [x] Stepped / popup parameters — Chris's `(VstInt32)(A * N.999)` discrete parameters now render as a real stepped control on both sliders and pots. N dots are placed at bin centers along the track (slider) or arc circumference (pot); the control still drags freely and snaps to the nearest case center on release. Step counts are detected at runtime by sampling `getParameterDisplay` (no metadata edits to upstream files). Pot dots are drawn above the value arc with the surface color so they punch through both the lit and unlit halves; the 1.0 unity magnet is suppressed when stepped so the snap doesn't fight a second detent. Examples: Cabs/CabType (6), Cans/A (5), Focus/Mode (5), Dirt/E (4), Monitoring/A (17) (2026-05-13) #feature
- [x] Empty parameter region — the 48 zero-parameter effects (dithers, Console8 fixed buses, clip-only utilities, mono/stereo helpers, etc.) now show a centered "This effect has no parameters" message in the grid slot instead of a blank gap, matching the "No effect selected" type style (2026-05-13) #polish
- [x] Fader relative-drag — replaced SwiftUI `Slider` in ParameterGrid with a custom `LinearFader` (new file in AirwindowsUI). Drag from anywhere on the track is interpreted as a delta from the value at touch-down — no teleporting the handle to the finger position. Optional double-tap reset; styled to match the iOS slider thumb so the swap is invisible visually (2026-05-09) #polish
- [x] In/Out pot range — extended AU param max for inputLevel/outputLevel from 1.0 to 2.0 (≈ +6 dB) in `AirwindowsAudioUnit.mm`. Default stays at 1.0 (unity / 0 dB). `RotaryPot` gained a `range:` parameter so the In/Out pots can use 0...2 with unity at the arc midpoint, while the per-effect pots stay 0...1. Velocity-aware detent at 1.0: magnet half-width scales with smoothed drag speed (0 at rest → 3% of span at 1500pt/s), so precise low-speed tweaks pass through unity untouched while a fast scrub latches at 0 dB. The latch holds until the underlying drag clears a 5%-of-span escape zone (2026-05-09) #feature
- [x] Pot grid layout reflow — pots no longer borrow the slider's row geometry. Adaptive flowing columns (115–140pt) replace the previous fixed 3-column grid; each cell stacks `[#] Name` (centered as a unit, name left-aligned for clean 2-line wrap on long names like "Reaction Speed"), pot, and value-under-pot. Optical-alignment nudges (-1pt circle, +2pt title) fix baseline drift between the numbered circle and the title text (2026-05-09) #polish
- [x] Auto-pots default for ≥24-parameter effects — replaced binary `useRotaryPots` AppStorage with tri-state `controlStylePreference` (`auto` | `sliders` | `pots`). Auto picks pots when `parameterCount ≥ 24` (e.g. ConsoleX, Recurve), sliders otherwise. Tapping the chip flips to an explicit choice and persists (2026-05-09) #feature
- [x] Tagline-as-title above header strip — quote/tagline moved out of the chip row to the top of the detail view, sitting at OS window-control level. Fixes chip overlap for effects with long descriptions; chip row now contains only MONO/STEREO + Day/Pots/Reset (2026-05-09) #polish
- [x] Title pill folds category in, sharper corner radius — category kicker now lives inside the stroked rounded-rect (cornerRadius 7, was Capsule) alongside the effect name + chevron. Reclaims the vertical strip the old stacked layout used, and addresses the "affordance around effect name" item by making the tap target read more clearly as a structural container (2026-05-09) #polish
- [x] Sliders↔pots toggle (basic) — third labeled chip in EffectDetailView's chip row alongside theme + reset. `@AppStorage("airwindows.useRotaryPots")` plumbed through EffectDetailView → ParameterGrid → ParameterRow, which conditionally renders Slider or RotaryPot. Chip labels follow Apple's "destination state" convention (says "Pots" when sliders are showing). Layout polish pass deferred (still uses slider's row geometry) (2026-05-09) #feature
- [x] Labeled chips in EffectDetailView header — Reset / Day-Night / Pots-Sliders. FilledIconChip extended with optional `text:` parameter (2026-05-09) #polish
- [x] "New" pseudo-category — pinned at the top of the categories list, contains the 8 most recently committed effects from the currently filtered pool, default sort = newest-first (toggle still works to re-order). UI-only addition in BrowserView; effects keep their natural category in addition to appearing in "New" (2026-05-09) #feature
- [x] Categorize the 23 "Unclassified" effects via override layer — `category_overrides.json` + `AirwindowsCategoryFor` in the bridge. Upstream-syncing ModuleAdd.h cannot wipe these. 17 assignments are confident (predecessor pattern: Density3→Distortion, Console*→Consoles, etc.); 6 are best-guess and flagged for review (2026-05-08) #feature
- [x] Add `PrivacyInfo.xcprivacy` privacy manifests to app + extension — declares no tracking, no data collection, only UserDefaults via @AppStorage (CA92.1) (2026-05-07) #chore
- [x] Add `ITSAppUsesNonExemptEncryption = false` to AirwindowsApp/Info.plist (2026-05-07) #chore
- [x] Remove `UIRequiredDeviceCapabilities` legacy `armv7` entry (2026-05-07) #chore
- [x] Chris Johnson blessing to ship under Airwindows name (2026-05-07) #milestone
- [x] Replace enclosed-numeral glyphs with a numbering scheme that works beyond 10 (2026-04-13) #polish
- [x] Effect list sort toggle — tap "newest first" header to switch to "alphabetical" and back (2026-04-13) #feature
- [x] "All categories" grouped sort — when All Categories is selected, add a "by category" sort that groups effects under category subheaders, newest within each (2026-04-13) #feature
- [x] Chip row polish — move non-button chips (STEREO/MONO) to left, invert button chips (theme/reset) to filled style (2026-04-13) #polish
- [x] Blog post + video link chips per effect — scripts/fetch_effect_links.py generates effect_links.json, bundle resource, Safari/YouTube handoff via openURL (2026-04-15) #feature
- [x] All 350+ effects compiled and processing audio (2026-04-08) #feature
- [x] Full SwiftUI UI — browser, sidebar, detail view, parameter grid (2026-04-08) #feature
- [x] Interactive rotary pots with vertical drag (2026-04-08) #feature
- [x] Effect browsing with categories and search (2026-04-08) #feature
- [x] State persistence in AU (fullState/setFullState) (2026-04-08) #feature
- [x] Dark/light mode toggle (2026-04-08) #polish
- [x] Browser opens clean — no category or effect preselected on launch (2026-04-13) #polish
