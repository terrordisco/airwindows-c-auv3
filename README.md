# Airwindows Consolidated AUv3

A native iPadOS AUv3 plugin that wraps the entire Airwindows effects library — all 350+ of Chris Johnson's free, open-source audio effects — in a single Apple-feeling Audio Unit.

<p align="center">
  <img src="airwindows_logo.jpg" alt="Airwindows" width="220" />
</p>

> Status: **pre-release, heading into TestFlight beta.** Builds and runs on iPad in AUM, Cubasis, Logic Pro, GarageBand, and Loopy Pro. Not yet on the App Store.

---

## What this is

Airwindows is a legendary library of audio effects, lovingly hand-rolled by Chris Johnson and offered free to the world. It has lived on macOS, Windows, Linux, and inside VCV Rack — but until now, not on iPad.

This project is an iPadOS AUv3 plugin that loads **every Airwindows effect in a single Audio Unit**, with a browser-style picker for selecting which one is active. The audio path is Chris's DSP, untouched. The UI is a thin, Apple-feeling shell on top — deeply designed to appear barely designed.

What you get on iPad:

- All 350+ Airwindows effects, in any AUv3 host.
- A category browser, search, and "Recommended / Basic / Latest" curated collections.
- Sliders or pots, your choice. Light and dark theme.
- Effect descriptions, blog-post and YouTube links from airwindows.com.
- AU state persistence — sessions and presets restore properly.

It is free, MIT-licensed for the wrapper, and welcomes contributions.

---

## Credits

- **[Chris Johnson](https://www.airwindows.com/)** — Airwindows. All the DSP, all the sound, the entire reason this project exists. Shipping under the Airwindows name with his blessing.
- **[Paul Walker (baconpaul)](https://github.com/baconpaul/airwin2rack)** — `airwin2rack`, the consolidated C++ build of Airwindows that made the iOS port tractable.
- **[Sveinbjörn Pálsson](https://github.com/sveinbjornpalsson)** — iOS port and UI.

Built with substantial assistance from Claude Code (Anthropic). See `CLAUDE.md` for the project's working notes and `NOTES.md` for the development journal.

---

## Building from source

You'll need:

- macOS with **Xcode 16+**
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** (project file is generated from `project.yml`)
- An iPad on iPadOS 17+ for on-device testing (Simulator works for UI only)
- An Apple Developer account for signing

```bash
# Clone
git clone https://github.com/terrordisco/airwindows-c-auv3.git
cd airwindows-c-auv3/AirwindowsAUv3

# Install XcodeGen
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open AirwindowsAUv3.xcodeproj
```

In Xcode:

1. Select the **AirwindowsAUv3** target → **Signing & Capabilities** → set your team.
2. Repeat for **AirwindowsAUExtension**.
3. Pick your iPad as the run destination.
4. Build & run.

Once the host app has been launched on the iPad once, the AUv3 plugin will be available to AUM, Cubasis, GarageBand, Logic Pro, Loopy Pro, and any other AUv3 host on the same device.

---

## How the code is laid out

Three Xcode targets:

| Target | Role |
|---|---|
| **AirwindowsApp** | Standalone iPad host shell. Loads the AU in-process; lets you audition effects through the microphone. Also the container app the AUv3 extension ships inside (required by iOS). |
| **AirwindowsAUExtension** | The actual AUv3 plugin loaded by other apps. |
| **AirwindowsDSP** (framework) | Owned by both targets. Contains Chris's C++ effects, an ObjC++ bridge, and the `AUAudioUnit` subclass. |

Plus a local Swift package, **`Packages/AirwindowsUI/`**, containing the SwiftUI views used by both targets.

The three-language stack:

```
Swift  ──▶  Objective-C  ──▶  Objective-C++  ──▶  C++
(UI)        (public API)      (.mm bridge)        (Chris's effects)
```

Each entry-point source file opens with a header explaining its role and where it sits — start with `AirwindowsAUv3/AirwindowsDSP/Bridge/AirwindowsAudioUnit.mm` for the architecture story.

For a longer narrative: see [`NOTES.md`](NOTES.md) (development journal) and [`ROADMAP.md`](ROADMAP.md) (live roadmap).

---

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The short version:

- The DSP is untouchable — it's Chris's work and the entire point of the project.
- Anything upstream (the C++ effect classes, the registry generator) is regenerated when the upstream syncs. Don't edit those files directly. Use the override-JSON layer in `AirwindowsAUv3/AirwindowsDSP/Resources/` instead.
- Code accessibility for first-time readers is a goal. If you're adding a new entry-point file, give it a real header comment.

---

## License

MIT for the wrapper code. The bundled Airwindows DSP keeps Chris Johnson's original licensing intact. See [`LICENSE`](LICENSE) for the full text.
