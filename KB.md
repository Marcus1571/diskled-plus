# KB.md

Canonical reference for DiskLED-plus. Facts here describe shipped behavior only.

## What the app does

Menu bar app (LSUIElement/accessory). Status-bar icon = one square, 16×16 pt, split
into two vertical rectangles separated by a 1 pt seam:

| Side | Color when lit | Meaning | Lit when (this tick, unsmoothed) |
|---|---|---|---|
| Left | bright green | reads | read bytes Δ > 0 OR read ops Δ > 0 |
| Right | red | writes | write bytes Δ > 0 OR write ops Δ > 0 |

Off state = same two rectangles in near-dark tint. Blink cadence = the timer tick;
sustained activity produces contiguous lit ticks, which read as steadily ON.

## The blink model

- Tick interval: **30 ms** (`AppDelegate.Constants.tickInterval`, Timer on main
  run loop, `.common` mode, `tolerance = 0` to prevent run-loop coalescing).
- Each tick: `DiskActivitySource.tick()` returns deltas since the previous tick.
  Counter resets (device removed) clamp deltas to 0 instead of fake-blinking.
- First tick only primes the baseline (returns zero deltas), never blinks.
- No averaging anywhere in the LED path. The menu's B/s text uses a rolling ~1 s
  window, display only.

## Data source

- IOKit: enumerate services matching class `IOBlockStorageDriver` (one per physical
  disk block device, including NVMe subclass drivers). For each, read registry
  property `Statistics` and sum keys:
  - `Bytes (Read)`, `Bytes (Write)`, `Operations (Read)`, `Operations (Write)`
- **Keys verified on-device** (2026-11-10, macOS 27.2 build 26B123): `ioreg -r -c
  IOBlockStorageDriver -l` shows exactly these four keys (values are 64-bit
  numbers). Values also flow through the app: per-tick deltas observed during
  real I/O, including 16 MB flush bursts for a 64 MB `dd` write.
- The property read uses `IORegistryEntryCreateCFProperty(entry, key, allocator,
  options)` in its 4-argument returning form; the 5-argument out-param variant
  does not exist in the current Swift IOKit overlay (compile error caught on
  first on-device build).
- Transiently, a matched `IOBlockStorageDriver` entry can lack the `Statistics`
  dictionary (observed in short bursts around mount/unmount races on this
  machine, e.g. 00:47 and again at 01:43 on 2026-11-10). The app treats a
  missing dictionary as zero contribution (no fake blink) and logs this once
  per process, not per tick.
- Read-only; requires no root/admin.
- `kIOMainPortDefault` (min macOS 12; package claims 13+).
- Deliberate choice over matching bare `IOMedia`: IOMedia also matches partitions
  and volumes → double counting.

## Debug tracing (opt-in)

Launch with `DISKLED_DEBUG=1` — every tick then logs to the unified log
(subsystem `com.diskledplus.app`, category `app`, debug level): milliseconds
since the previous tick, and the raw read/write deltas of that tick. Startup
also logs whether tracing is active. Off by default; when off, only errors,
warnings and the startup line are logged.

Inspect with:

```
/usr/bin/log stream --level debug --style compact \
  --predicate 'subsystem == "com.diskledplus.app"'
```

Note: the operator's zsh defines a `log` shell function, so from their
interactive shell use the absolute path `/usr/bin/log`.

## Rendering

- 4 NSImages cached (off / readsOnly / writesOnly / both), 16×16 pt, drawn
  programmatically, `isTemplate = false`.
- Icon only swapped when the LED state actually changed, to avoid pointless redraws
  (the state machine itself still runs every tick).
- Colors: readLit green sRGB(0.05, 1.00, 0.25); writeLit red sRGB(1.00, 0.15, 0.15);
  off tints near-dark green/red respectively.

## Menu

- Header "DiskLED-plus"; live lines "Reads — X/s" and "Writes — X/s" refreshed on
  menu open from the last ~1 s window (live-verified on device while the menu stays
  open); About dialog; Quit (⌘Q). Nothing else ships (no preferences window, no
  installer behavior).

## Brightness

- Right-click (any click on the status item) → menu → **Brightness** → ten items:
  `10%` `20%` `30%` `40%` `50%` `60%` `70%` `80%` `90%` `100%`. Checkmark marks the
  active value. **Default 60%** (operator-set).
- Persisted immediately on selection: `UserDefaults.standard` key
  `ledBrightnessPercent` (integer 10–100, read clamped) — for the bare-binary
  process this lands in `~/Library/Preferences/DiskLEDPlus.plist` (verify with
  `defaults read DiskLEDPlus ledBrightnessPercent`). First launch without the key
  uses 60 via `register(defaults:)` — the default cannot drift upward unnoticed.
- Effect: lit colors are drawn at alpha = value/100 — same hue, dimmer against the
  menu bar, never a different color. The off-state is unaffected by the setting
  (off means off). 100% reproduces the original full-strength look.
- Known good interaction: changing the value re-renders the current state at once,
  so a change is visible even while the light is currently steady ON.

## Build and run

```
git clone git@github.com:Marcus1571/diskled-plus.git ~/src/diskled-plus
cd ~/src/diskled-plus && swift build -c release
.build/release/DiskLEDPlus
```

Kill/later removal: quit via menu. No launch agent ships yet (planned post-0.2).

## Verification list (first on-device build)

Cleared 2026-11-10 on the operator's Mac (macOS 27.2, arm64), evidence in
findings.md and the v0.2.0 CHANGELOG entry:

1. ✅ Compile clean on current macOS/Swift toolchain (after the
   `IORegistryEntryCreateCFProperty` fix).
2. ✅ `Statistics` key names correct on this macOS build (checked via `ioreg`
   and via live per-tick deltas).
3. ✅ 33 Hz tick cadence with no coalescing (median 29.7 ms over 133 traced
   ticks); icon state swaps render in the menu bar. *Perceived* blink
   smoothness over long use remains for the operator to judge.
4. ✅/👤 Off-state renders as near-dark rectangles (visible as a distinct dark
   square on this machine's dark-ish blue bar); light-menu-bar visibility is
   left for the operator to eyeball on a day with a light bar.

## Provenance and license

Idea credit: Helge Klein's DiskLED (Windows). Our code is original Swift, MIT.
No assets, code, or icons were copied from upstream.
