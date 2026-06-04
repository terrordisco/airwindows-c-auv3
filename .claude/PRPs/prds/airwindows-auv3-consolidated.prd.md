# Airwindows Consolidated AUv3

## Problem Statement

Airwindows is a legendary library of 500+ free, open-source audio effects built by Chris Johnson — but they don't exist on iPad. Musicians working on iPadOS have no way to access these effects in their DAW sessions. This project brings the full Airwindows library to iOS as a native AUv3 plugin with an interface that feels like Apple built it.

## Evidence

- Airwindows has a dedicated enthusiast following across desktop platforms (macOS, Windows, Linux, VCV Rack)
- No iOS/iPadOS port exists — this is a gap, not a competitive displacement
- The developer (Sveinbjorn) wanted this for years but lacked the implementation path until Claude Code made it viable
- The upstream consolidation by Paul Walker (baconpaul/airwin2rack) provides a clean, registry-based C++ architecture that made the port feasible

## Proposed Solution

A native Swift/SwiftUI + C++ AUv3 plugin that wraps all 500+ Airwindows effects with zero external dependencies. The UI should feel like a default Apple component — deeply designed to appear barely designed. The project is free, open source (MIT), and community-oriented. It never touches the DSP; it is a window into Chris's work, not a fork.

## Key Hypothesis

We believe a beautifully native, Apple-feeling AUv3 wrapper around all Airwindows effects will make this legendary but intimidating library accessible and enjoyable on iPad for musicians who love sound exploration. We'll know we're right when Chris accepts it and people actually use it in sessions.

## What We're NOT Building

- **Anything that affects the sound** — the DSP is Chris's domain, untouchable
- **Anything contradicting the ethos** — no monetization schemes, no lock-in, no tracking, no "pro" tier
- **iPhone-first UI** — iPad is the target; iPhone may come later but is not a v1 concern
- **Custom DSP or extended processing** — no adding reverb tails, no chaining, no "enhanced" modes
- **A DAW or host app** — the standalone app is a shell; the real product is the AUv3 extension

## Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| Chris's acceptance | Explicit blessing to ship under Airwindows name | Direct communication |
| TestFlight stability | Loads and processes audio without crashes in AUM, Cubasis, GarageBand | Manual testing |
| App Store approval | Published on App Store as free app | Apple review process |
| Community reception | Positive response in iPad music communities | Forum/Reddit/Discord feedback |
| Open source health | External contributions or forks within 6 months | GitHub activity |

## Open Questions

- [ ] Has Chris been contacted? Need to compose and send a letter explaining the project, philosophy, and asking for his blessing
- [ ] Is there a space beyond what Chris does himself — additional curation, documentation, community features — that he'd welcome?
- [ ] TestFlight behavior on real iPad hardware — touch target sizes, gesture feel, performance with complex effects
- [ ] App Store review — will Apple have issues with 500+ effects in one plugin, bundle size, or the extension architecture?
- [ ] Auto-update mechanism — how to pull weekly new effects from upstream without requiring a full App Store review cycle
- [ ] How to present "vibecoded with AI" transparently — commit history tells the story, README states it plainly, CONTRIBUTING.md explains the workflow

---

## Users & Context

**Primary User**
- **Who**: Enthusiast iPad musician. Big nerd. Could be a complete pro, but always enthusiastic about sound. The kind of person who gets excited discovering a weird saturation algorithm.
- **Current behavior**: Uses iPad DAWs (AUM, Cubasis, etc.) and knows Airwindows from desktop, or discovers it through the iOS plugin ecosystem.
- **Trigger**: Making music and something needs *that quality they can't name*. Not reaching for a quick fix — reaching for alchemy.
- **Success state**: Found an effect that makes the sound come alive. Starred it. Returns to it instinctively.

**Job to Be Done**
When I'm making music and something needs a je ne sais quoi, I want to explore and experiment with Airwindows effects, so I can find the alchemy that makes the sound come alive.

**Non-Users**
Minimalists who believe one of each plugin type is enough. This is a library for explorers, not for people who want "the best compressor" and move on.

---

## Solution Detail

### Core Capabilities (MoSCoW)

| Priority | Capability | Rationale |
|----------|------------|-----------|
| Must | All 500+ effects loadable and processing audio | The whole point — complete library |
| Must | Apple-native UI feel (looks like Apple built it) | Design philosophy — invisible design |
| Must | Effect browser with categories and search | Discovery is core to the experience |
| Must | State persistence (save/restore in hosts, presets) | Basic professional reliability — AU fullState already implemented |
| Must | Open source, MIT licensed, welcoming to contributors | Core ethos of the project |
| Should | Favorites (star in detail view, rise to top of lists, favorites category) | Bridges exploration → habitual use |
| Should | Readable, well-documented source code | Community health, contributions, trust |
| Should | Transparent AI-assisted development story | Honesty, comfort, trust |
| Could | Sliders/pots display toggle in settings | User preference for control style |
| Could | Distinct control types for toggles and notched selections | Better than generic sliders for discrete params |
| Could | Recently used / most used collections | Supports repeat discovery |
| Could | Context menus, haptics, animations on state changes | Apple-native polish layer |
| Won't | Any DSP modifications | Chris's domain |
| Won't | iPhone-optimized UI (v1) | iPad first |
| Won't | Monetization or premium features | Contradicts ethos |

### MVP Scope

Get it on TestFlight on a real iPad. Feel it. Iterate until it feels right. This is a gut-check milestone, not a feature checklist. The core question: does it feel like it belongs on the platform?

### User Flow

```
Open host (AUM/Cubasis) → Add AUv3 effect → Airwindows appears →
Browse categories or search → Select effect → Hear it immediately →
Adjust parameters → Star it if it's magic → Move on
```

---

## Technical Approach

**Feasibility**: HIGH

All hard technical problems are solved: 500+ C++ effects compile, AU loads in hosts, audio processes correctly, SwiftUI UI is functional, state save/restore is implemented.

**Architecture Notes**
- Zero external dependencies — only Apple frameworks (AudioToolbox, AVFoundation, CoreAudioKit, SwiftUI)
- AUAudioUnit subclass lives in AirwindowsDSP framework (not extension) to ensure C++ static registry populates once
- 13-parameter AU tree: 10 effect params + effect index + input/output levels
- Atomic effect switching via std::atomic<> for thread safety
- Upstream effects pulled from baconpaul/airwin2rack consolidation

**Technical Risks**

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| App Store rejection (bundle size, 500+ effects) | LOW | Apple has precedent for large plugin libraries; test with TestFlight first |
| Performance on older iPads with complex effects | MEDIUM | Profile on hardware; potentially flag heavy effects |
| Auto-update from upstream breaking builds | MEDIUM | CI pipeline, pinned upstream commits, weekly build verification |
| Apple AUv3 API changes in future iOS versions | LOW | Standard Apple deprecation cycle; maintain iOS 17+ target |

---

## Implementation Phases

| # | Phase | Description | Status | Parallel | Depends | PRP Plan |
|---|-------|-------------|--------|----------|---------|----------|
| 1 | Chris's blessing | Compose letter, send, get response | pending | with 2 | - | - |
| 2 | Hardware validation | TestFlight on real iPad, touch/gesture/performance testing | pending | with 1 | - | - |
| 3 | Polish to "Apple built this" | UI refinements based on hardware feel — touch targets, animations, haptics, context menus | pending | - | 2 | - |
| 4 | Favorites | Star toggle, persistence, favorites category, rise-to-top behavior | pending | with 3 | 2 | - |
| 5 | Open source packaging | Repository structure, README, CONTRIBUTING, build instructions, CI, transparent AI story | pending | with 3, 4 | 1 | - |
| 6 | App Store submission | Screenshots, description, review preparation | pending | - | 1, 3, 4, 5 | - |
| 7 | Community launch | Promote in iPad music communities, with Chris's blessing reach out to media | pending | - | 6 | - |
| 8 | v1.1 — Enhanced controls | Sliders/pots toggle, distinct toggle/notch controls, additional collections | pending | - | 6 | - |

### Phase Details

**Phase 1: Chris's Blessing**
- **Goal**: Get explicit approval to ship under the Airwindows name
- **Scope**: Compose a letter explaining the project, philosophy, what you will and won't touch, the open source nature, and ask about space beyond what he does himself
- **Success signal**: Chris says yes (or gives clear direction on what he'd want changed)

**Phase 2: Hardware Validation**
- **Goal**: Confirm the plugin feels right on a real iPad
- **Scope**: TestFlight build, test in AUM/Cubasis/GarageBand, verify state persistence, check touch target sizes, assess performance
- **Success signal**: "I know it when I see it" — the gut check passes

**Phase 3: Polish to "Apple Built This"**
- **Goal**: Close the gap between "functional" and "native-feeling"
- **Scope**: Animations on state changes, haptic feedback, context menus on effect rows, accessibility labels, keyboard shortcut support
- **Success signal**: A stranger would not guess this isn't an Apple-made component

**Phase 4: Favorites**
- **Goal**: Bridge exploration and habitual use
- **Scope**: Star toggle in EffectDetailView header, favorites persistence (AppStorage/UserDefaults), favorites rise to top of category lists, Favorites category in browser
- **Success signal**: You star effects during a real session and find them instantly next time

**Phase 5: Open Source Packaging**
- **Goal**: Make the repo welcoming, readable, and contribution-ready
- **Scope**: Clean repo structure, comprehensive README, CONTRIBUTING.md (including AI-assisted workflow note), build instructions, CI pipeline, issue templates, code documentation for key architecture decisions
- **Success signal**: A competent Swift developer can clone, build, understand the architecture, and submit a PR within an afternoon

**Phase 6: App Store Submission**
- **Goal**: Published as a free app on the App Store
- **Scope**: App Store metadata, screenshots, review compliance
- **Success signal**: App approved and live

**Phase 7: Community Launch**
- **Goal**: Get it in front of iPad music enthusiasts
- **Scope**: Posts in relevant communities (AudioBus forum, r/ipadmusic, Discord servers), outreach to music tech media with Chris's blessing
- **Success signal**: People are using it and talking about it

**Phase 8: v1.1 — Enhanced Controls**
- **Goal**: Richer parameter interaction
- **Scope**: Settings toggle between sliders and rotary pots, distinct visual treatment for toggle parameters and notched/stepped selections
- **Success signal**: Controls feel appropriate to their parameter type

### Parallelism Notes

Phases 1 (Chris) and 2 (hardware testing) can run in parallel — you don't need Chris's blessing to test on your own iPad. Phases 3, 4, and 5 can overlap since they touch different parts of the project (UI polish, data model, repo packaging). Phase 6 gates on 1 (must have blessing), 3, 4, and 5.

---

## Decisions Log

| Decision | Choice | Alternatives | Rationale |
|----------|--------|--------------|-----------|
| UI philosophy | "Apple built this" — invisible design | Skeuomorphic audio UI, Chris's raw style, custom branded | Matches iPad platform expectations; makes 500 effects approachable |
| Dependencies | Zero — Apple frameworks only | AudioKit, JUCE | Simpler build, no licensing complexity, smaller binary, full control |
| Licensing | MIT | GPL, proprietary | Matches upstream Airwindows license; maximally open |
| AI transparency | Commit history + README mention | Hide it, prominent disclaimer, separate doc | Honest without being apologetic; the code speaks for itself |
| DSP boundary | Never touch the sound | Add convenience processing | Chris's work is the product; the app is just the window |
| Platform | iPad first, iPhone later | Universal from day one | iPad is the real music-making platform; iPhone UI is a different problem |

---

## Research Summary

**Market Context**
- No Airwindows AUv3 exists on iOS — this is the first
- The iPad music-making community (AUM, Cubasis, AudioBus ecosystem) is enthusiast-driven and appreciates quality free tools
- Airwindows has a loyal following on desktop platforms who would welcome an iOS port

**Technical Context**
- Upstream consolidation (baconpaul/airwin2rack) provides clean C++ registry architecture
- All 500+ effects compile and run on iOS
- State persistence (fullState/setFullState) is already implemented in the AU
- SwiftUI UI framework is functional with effect browser, parameter controls, and theme system
- No architectural blockers — remaining work is polish, features, and packaging

**Licensing**
- Airwindows source: MIT (Chris Johnson)
- Consolidation wrapper: MIT (Paul Walker)
- iOS port: MIT
- No GPL entanglement (no JUCE dependency)

---

*Generated: 2026-04-10*
*Status: DRAFT - pending Chris's response and hardware validation*
