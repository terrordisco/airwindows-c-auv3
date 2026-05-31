# Airwindows Consolidated AUv3

Native iOS AUv3 plugin wrapping all 350+ Airwindows effects. Swift/SwiftUI + C++ DSP, zero external dependencies. iPad-first, free, open source (MIT).

## Design Philosophy

- **"Part of the OS"** — the UI should feel like a default Apple component. Deeply designed to appear barely designed.
- **Never touch the DSP** — the sound is Chris Johnson's domain. This project is a window into his work, not a fork.
- **Open source, community-first** — MIT licensed, welcoming to contributors, transparent about AI-assisted development.

## Architecture

- **3 Xcode targets**: AirwindowsApp (host shell), AirwindowsAUExtension (AUv3 plugin), AirwindowsDSP (shared framework)
- **AirwindowsUI** local Swift package in `Packages/AirwindowsUI/` — all SwiftUI views and Theme
- **C++ DSP** in `AirwindowsDSP/Airwin/autogen_airwin/` — 350+ effects from upstream baconpaul/airwin2rack
- **Bridge** in `AirwindowsDSP/Bridge/` — ObjC++ interop between Swift and C++
- **AUAudioUnit subclass lives in the framework** (not the extension) so the C++ static registry populates once

## Key Files

- `NOTES.md` — development journal, architecture decisions, UI specs
- `ROADMAP.md` — standardized todo/roadmap (see below)
- `NOTES/views.html` — UI terminology reference with diagrams
- `project.yml` — XcodeGen config (generates .xcodeproj)

## Roadmap

This project uses `ROADMAP.md` in the project root to track work. The format is standardized across all projects.

- **On session start**: Read `ROADMAP.md` for context on what's in progress and what's next.
- **When you complete work**: If it matches a roadmap item, check it off (`- [x]`) and move it to `## Done` with today's date.
- **When you discover a bug or issue while working**: Tell the user and offer to add it via `/todo bug <description>`.
- **When the user uses `/todo`**: Follow the todo skill instructions to add/update items.
- **Never silently add items** — always confirm with the user.

## PRD

Full product requirements document at `.claude/PRPs/prds/airwindows-auv3-consolidated.prd.md`.
