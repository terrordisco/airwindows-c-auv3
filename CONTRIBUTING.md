# Contributing

Thanks for considering it. This is a community-first project and contributions of any size are welcome — bug reports, UI polish, docs, accessibility, host-compat testing, anything.

A few ground rules first.

## The DSP is untouchable

The audio code lives in `AirwindowsAUv3/AirwindowsDSP/Airwin/`. It is Chris Johnson's work, synced from [baconpaul/airwin2rack](https://github.com/baconpaul/airwin2rack) which itself wraps the upstream Airwindows source.

We do not modify it. Not for "small fixes", not for "cleanups", not for warnings. If a behaviour seems wrong, that's a conversation to have upstream with Chris, not a PR here. This project is a **window into Airwindows**, not a fork of it.

## The override-JSON layer

A handful of upstream files (`ModuleAdd.h`, the per-effect `awpdoc/*.txt` descriptions, etc.) are regenerated whenever we sync the DSP. Direct edits there would be lost on the next sync.

When you need to correct or extend metadata — category assignment, missing descriptions, blog/video links — put the change in a JSON sidecar under `AirwindowsAUv3/AirwindowsDSP/Resources/` and let the bridge read it at runtime. Existing examples:

- `category_overrides.json` — reassigns "Unclassified" effects to better categories.
- `effect_links.json` — blog post + YouTube URL per effect.

The lookups live in `AirwindowsBridge.mm`. See its file header for the full pattern.

## Code accessibility

This is a public OSS project and a deliberate goal is for the codebase to be readable by developers who aren't necessarily senior or familiar with Core Audio / AUv3 internals.

If you're adding a new entry-point source file (anything in `AirwindowsApp/`, `AirwindowsAUExtension/`, or `AirwindowsDSP/Bridge/`), give it a real file-level header explaining:

- What it is.
- Where it sits in the architecture (which target, which layer).
- The non-obvious wiring — threading model, cross-language hops, why it exists where it does.
- Pointers to related files.

The existing headers in `AirwindowsAudioUnit.mm`, `AirwindowsBridge.mm`, and `AUv3ViewController.swift` are good templates.

For SwiftUI components in the `AirwindowsUI` package, a short architectural header is enough — type-level docstrings carry the rest.

## Building

See the README's build section. The short version:

```bash
cd AirwindowsAUv3
brew install xcodegen
xcodegen generate
open AirwindowsAUv3.xcodeproj
```

`project.yml` is the source of truth for the Xcode project. Don't edit the `.xcodeproj` by hand — it's regenerated.

## Testing

There's no formal test suite yet. Effective testing right now is:

1. Build and run on an iPad.
2. Open the standalone app — pick a few effects, confirm audio passes through the mic monitor.
3. Open AUM (or Logic Pro, Cubasis, GarageBand, Loopy Pro) on the same iPad and load the plugin. Confirm it renders, picks an effect, processes audio.
4. **State persistence:** save an AUM session and a `.aupreset` preset; close and reopen; confirm the effect and parameter values are restored.

When in doubt, also re-test in at least one other AUv3 host — they implement state restoration with surprisingly different assumptions.

## AI-assisted development

This project is developed with substantial assistance from [Claude Code](https://claude.com/claude-code). The `CLAUDE.md` file at the project root contains the instructions the AI uses; `NOTES.md` is the running development journal. This is disclosed openly, not hidden.

You are welcome to use AI tools too. The bar for accepting a PR is the same either way: does it solve the problem, does it match the project's conventions, and does it not touch the DSP.

## Reporting bugs

GitHub issues. Please include:

- iPadOS version.
- Host app (AUM, Logic, etc.) and its version.
- Specific effect (if reproducible with one).
- What you did and what happened.

A screenshot or short screen recording is worth a thousand words for UI bugs.

## License

By contributing, you agree your contribution will be licensed under the same MIT license as the rest of the wrapper code. See [`LICENSE`](LICENSE).
