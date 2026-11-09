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
- Read-only; requires no root/admin.
- `kIOMainPortDefault` (min macOS 12; package claims 13+).
- Deliberate choice over matching bare `IOMedia`: IOMedia also matches partitions
  and volumes → double counting.

## Rendering

- 4 NSImages cached (off / readsOnly / writesOnly / both), 16×16 pt, drawn
  programmatically, `isTemplate = false`.
- Icon only swapped when the LED state actually changed, to avoid pointless redraws
  (the state machine itself still runs every tick).
- Colors: readLit green sRGB(0.05, 1.00, 0.25); writeLit red sRGB(1.00, 0.15, 0.15);
  off tints near-dark green/red respectively.

## Menu

- Header "DiskLED-plus"; live lines "Reads — X/s" and "Writes — X/s" refreshed on
  menu open from the last ~1 s window; About dialog; Quit (⌘Q). Nothing else ships
  (no preferences, no installer behavior).

## Build and run

```
git clone git@github.com:Marcus1571/diskled-plus.git ~/src/diskled-plus
cd ~/src/diskled-plus && swift build -c release
.build/release/DiskLEDPlus
```

Kill/later removal: quit via menu. No launch agent ships yet (planned post-0.2).

## Verification list (first on-device build)

Must be cleared before "works" is claimable; see AGENTS.md for procedure and point
STATUS.md for current state. Items:

1. Compile clean on current macOS/Swift toolchain.
2. `Statistics` key names correct on this macOS build (else fix and update KB.md).
3. 33 Hz `NSStatusItem` image swaps render without visible throttling.
4. Off-state visible on both dark and light menu bar.

## Provenance and license

Idea credit: Helge Klein's DiskLED (Windows). Our code is original Swift, MIT.
No assets, code, or icons were copied from upstream.
