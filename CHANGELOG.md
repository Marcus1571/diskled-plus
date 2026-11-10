# CHANGELOG.md

## [0.3.0] — 2026-11-10

### Added
- `Sources/DiskLEDPlus/AppDelegate.swift` — Brightness menu voice: a `Brightness`
  submenu with ten steps (10%, 20%, … 100%), checkmark on the active one, default
  **60%** on first launch. Selection is persisted (`UserDefaults` key
  `ledBrightnessPercent`, clamped on read), and choosing a value re-renders the
  current LED state immediately so the change is visible between ticks.
- `Sources/DiskLEDPlus/LEDIconRenderer.swift` — brightness support: the lit colors
  are drawn at alpha = brightness %, so a value like 60% reads as the same hue
  dimmed against the menu bar rather than a color shift. Icons are cached per
  (state, brightness) pair. The off-state colors are deliberately untouched — "off"
  must not become "barely lit".

### Fixed
- `Sources/DiskLEDPlus/DiskActivitySource.swift` — the "Statistics property
  missing" warning introduced with the property-lookup fix logged on every tick
  while a transiently-matched entry lacks the dictionary (observed in bursts
  during mount/unmount races on this machine). Now logged once per process and
  suppressed after; behavior unchanged (missing → zero deltas, silent LED).

### Verified on device
- Brightness submenu shows all ten steps with ✓ on 60% (screenshot); clicking
  40% persisted to `UserDefaults` and clicking 60% restored it (read back from
  `defaults`); 60% default renders visibly dimmer than the previous 100% icons.
- Menu B/s readout live-checked during the interaction (Reads/Writes lines
  updating while the menu was open).

## [0.2.0] — 2026-11-10

First on-device verified release (operator's Mac, macOS 27.2 / arm64). **The app
now compiles, runs, and blinks correctly on real hardware.**

### Fixed
- `Sources/DiskLEDPlus/DiskActivitySource.swift` — the written-but-never-compiled
  `IORegistryEntryCreateCFProperty` call used a 5-argument form (with an
  `Unmanaged` out-parameter) that does not exist in the current Swift IOKit
  overlay; replaced with the standard 4-argument form returning
  `Unmanaged<CFTypeRef>?`. This was the only compile error; the build is clean
  otherwise. No behavior change (the new code does the same lookup).
  Also added a unified-log warning when a registry property is present but not
  a readable dictionary.

### Added
- `Sources/DiskLEDPlus/AppDelegate.swift` — opt-in per-tick debug tracing: launch
  with `DISKLED_DEBUG=1` and every tick logs to the unified log (subsystem
  `com.diskledplus.app`) with the milliseconds since the previous tick and the
  raw byte/op deltas for reads and writes. Defaults to off; only the startup
  info line changed otherwise. Purpose: troubleshooting cadence and burst
  behavior without touching the tick or the LED path (see KB.md §Debug tracing).

### Verified on device (clearing the AGENTS.md verification list)
- Compile clean on this toolchain (Swift 5.9+, Command Line Tools, macOS 27.2 SDK).
- `IOBlockStorageDriver` "Statistics" does carry the four expected keys on this
  build — read via `ioreg` and via the running app's deltas.
- Timer fires at ~33 Hz (median tick-to-tick 29.7 ms measured over 133 ticks;
  p95 34.2 ms; no coalescing with `tolerance = 0`).
- Icon renders in the menu bar with colors intact: left green and right red both
  observed lit (screenshots at the System-Events-reported item frame); sustained
  write load locks the icon steadily in the both-lit state.

Remaining human-eye checks for the operator: perceived blink smoothness over a
long session, off-state visibility on light menu bars, and the menu's B/s
readout formatting.

## [0.1.0] — 2026-11-10

First public scaffold. **Source-only release: never compiled or run anywhere yet.**

### Changed/Added (all initial)
- `Package.swift` — SwiftPM executable, macOS 13+, no Xcode project.
- `Sources/DiskLEDPlus/main.swift` — accessory-policy NSApplication entry.
- `Sources/DiskLEDPlus/AppDelegate.swift` — 30 ms tick timer (tolerance 0), blink
  state machine with no smoothing, menu with live B/s readout, About, Quit.
- `Sources/DiskLEDPlus/DiskActivitySource.swift` — IOKit IOBlockStorageDriver
  "Statistics" aggregation, per-tick deltas, counter-reset clamping.
- `Sources/DiskLEDPlus/LEDIconRenderer.swift` — programmatic 16×16 two-rectangle LED
  icon (left green reads, right red writes), 4 cached states, not-template.
- Governance: README/KB/STATUS/findings/AGENTS/CHANGELOG, MIT LICENSE with idea
  credit to Helge Klein's DiskLED.
