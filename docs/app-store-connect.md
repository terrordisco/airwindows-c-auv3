# App Store Connect metadata

Paste-ready copy for the ASC App Information + TestFlight forms. Pick the option you like where alternatives are offered, then drop into the matching field in App Store Connect.

All character counts noted are Apple's hard limits.

---

## App Information

### App Name (max 30)

**`Airwindows Consolidated AUv3`** (28 chars) — the long, official name. Used on the App Store listing, in search results, and anywhere Apple shows the product name.

The shorter **`Airwindows AUv3`** is set as `CFBundleDisplayName` in `AirwindowsApp/Info.plist` and is what shows up under the home screen icon (iOS truncates anything longer there anyway).

The AU plugin name shown in hosts (AUM, Logic, etc.) is also `Airwindows Consolidated AUv3`, set in the extension's `Info.plist` under `NSExtensionAttributes.AudioComponents.name`.

### Subtitle (max 30)

`350+ Airwindows effects, free` (29) — **recommended**

Alternates:
- `All 350+ effects in one AUv3` (29)
- `Chris Johnson's full DSP toolkit` (32 — too long, cut to "Chris Johnson's DSP toolkit" at 27)

### Primary Category

**Music**

### Secondary Category

**Productivity** — covers "tools used in a workflow." Utilities is also fine.

### Age Rating

**4+** — no objectionable content of any kind.

### Content Rights

Check: **No, my app does not contain, show, or access third-party content** (the DSP is open-source, MIT-compatible).

---

## App Store description (max 4000)

```
All 350+ free Airwindows effects in a single AUv3 plugin for iPad.

Airwindows is a legendary library of hand-crafted audio effects by Chris Johnson — quirky, musical, and freely shared with the world for over a decade. Until now, none of them ran on iPad. This plugin changes that: every Airwindows effect, in one AUv3, in any AUv3-capable host.

Drop it into AUM, Cubasis, GarageBand, Logic Pro, Loopy Pro — anywhere AUv3 plugins are accepted — and you get a browser of 350+ effects sorted by category, search, and curated collections (Recommended, Basic, Latest). Tap an effect to load it. Tweak parameters with sliders or rotary pots, your choice. Read what the effect is for, hop to the matching blog post or YouTube demo from airwindows.com.

The sound is Chris Johnson's, untouched. The wrapper is a thin, Apple-feeling Swift shell on top — deeply designed to appear barely designed.

WHAT YOU GET

• All 350+ Airwindows effects, in any AUv3 host
• Category browser, search, and curated collections
• Sliders or rotary pots — your choice
• Light and dark themes
• Effect descriptions, blog and video links from airwindows.com
• AU state persistence — sessions and presets restore properly
• Free, MIT-licensed, no ads, no tracking, no accounts

CREDITS

• DSP: Chris Johnson — airwindows.com
• Consolidated registry: Paul Walker (baconpaul/airwin2rack)
• iPad port: Sveinbjörn Pálsson

Shipping under the Airwindows name with Chris's blessing.

OPEN SOURCE

The entire wrapper is open source under MIT. Source, build instructions, and contributor guide at github.com/terrordisco/airwindows-c-auv3.

If you find a bug, file an issue. If you want to contribute UI polish, accessibility, or host-compat testing, you're very welcome.
```

Character count: ~1500. Well under the 4000 limit, leaves room for additions.

---

## Keywords (max 100, comma-separated)

```
audio,effects,plugin,AUv3,AU,audiounit,DSP,airwindows,reverb,EQ,compressor,saturation,tape,console,distortion
```

(99 chars including commas.) No need to include words already in the App Name or Subtitle — Apple indexes those automatically.

---

## URLs

| Field | URL |
|---|---|
| **Support URL** (required) | `https://github.com/terrordisco/airwindows-c-auv3/issues` |
| **Marketing URL** (optional) | `https://terrordisco.github.io/airwindows-c-auv3/` *(once the landing page is published)* |
| **Privacy Policy URL** (required) | `https://terrordisco.github.io/airwindows-c-auv3/privacy.html` *(see `landing/privacy.html`)* |

---

## Promotional Text (max 170, can be updated without re-review)

Use this for time-sensitive blurbs. For the launch:

```
350+ legendary Airwindows audio effects, free, in a single AUv3 plugin for iPad. Shipping under Chris Johnson's name with his blessing. Open source.
```

(149 chars.)

---

## TestFlight

### Beta App Description (max 4000)

```
Airwindows Consolidated AUv3 is a free, open-source iPad audio plugin that wraps all 350+ Airwindows effects by Chris Johnson in a single AUv3.

This is a pre-release beta. The audio engine is mature (the DSP itself has been battle-tested for years across desktop platforms), but the iOS wrapper around it is new. The goal of this beta is to confirm the plugin loads and behaves correctly in every major AUv3 host on iPad, and to gather UI feedback before public release.

Confirmed working: AUM, Cubasis, GarageBand, Logic Pro, Loopy Pro.

Feedback: use the in-app feedback links (Email or Report bug → GitHub Issues), or post in the Discord we'll share in the welcome email.
```

### What to Test (max 4000) — first beta build

```
Please try:

1. Loading the plugin in your favorite AUv3 host.
2. Browsing — open the browser, scroll categories, search by name.
3. Picking a few effects and tweaking parameters.
4. The slider ↔ pot toggle in the header chip.
5. The dark/light toggle.
6. State persistence — save your host session and reopen it; the effect and parameters should restore.
7. Saving a preset (.aupreset) and recalling it later.

Specifically interested in:

• Any effect that fails to load or crashes the host.
• Any host where the plugin renders incorrectly or the UI is broken.
• Anything that feels un-Apple-y — placements, spacings, behaviors that surprise you.
• Hosts we haven't yet tested.

If you'd like to chat: the Discord invite is in the welcome email and on the signup page.
```

---

## Bundle IDs to register

| Target | Bundle ID |
|---|---|
| Standalone app | `com.terrordisco.airwindows.app` (or `com.terrordisco.airwindows-c-auv3`) |
| AUv3 extension | `com.terrordisco.airwindows.app.extension` |

Confirm these match what's in `project.yml` (`AirwindowsAUv3/project.yml`).

---

## Screenshots needed

Apple requires at least one screenshot per device class you're submitting for. For iPad-only:

| Class | Size | Count |
|---|---|---|
| 13-inch iPad Pro (M4) | 2064×2752 | up to 10 |
| 12.9-inch iPad Pro (3rd–6th gen) | 2048×2732 | up to 10 |

You only *strictly* need to provide screenshots for the largest size — Apple scales for the others — but providing both classes looks more polished.

Suggested shots (3–5 is plenty):

1. The browser, with a category selected and an effect highlighted.
2. The effect detail surface with sliders.
3. The effect detail surface with rotary pots.
4. The plugin loaded inside AUM (or another host) on iPad.
5. The About screen with credits.

Use both light and dark themes where they look good.

---

## Decisions to make before submitting

- [ ] App Name (recommend `Airwindows AUv3`)
- [ ] Confirm Chris is OK with the description copy (worth a quick check)
- [ ] Confirm bundle IDs match `project.yml`
- [ ] Screenshots captured at both 13" and 12.9" sizes
- [ ] Landing page hosted on GitHub Pages so the Marketing + Privacy URLs resolve
