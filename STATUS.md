# STATUS.md

## Where the project stands right now

**Verified working on device (2026-11-10, operator's Mac, macOS 27.2/arm64).**
v0.6.0: the app builds clean, runs, polls IOKit at 33 Hz, and blinks — idle
shows occasional green read blinks; sustained write load locks the icon
steadily both-lit (green + red) as designed. **New in 0.6.0**: a real
Settings window (menu → Settings…, ⌘,) with the indicator's graphic layout
(bars / new iStat-style two-dots look, new `ledLayout` default key) and the
brightness slider; a standard macOS About panel (icon, version, credits with
author + MIT + repo link). Sparkle self-updating ships since 0.5.0
(signed/notarized DMG, EdDSA appcast; first live rehearsal 0.5.0 → 0.5.1
succeeded silently on device). The `/Applications` copy is the everyday way
to run it.

**Open design decision: RESOLVED (2026-11-11).** The operator picked the
status-bar layout set from the design sheet: the original bars stay default,
plus five new layouts — two dots, "SSD" stacked above the dots, "RW" letters
as LEDs, "SSD" with a blinking line above and below the text, and bars with
an "SSD" label — all selectable and persisted in Settings v0.7.0/resolved design; v0.7.1 renamed labels to "SSD"; v0.7.2 tuned the
stacked layouts to the full bar height after real-bar comparison with the
neighboring iStat elements (10 pt regular label, full-size dots, lines at
the extreme planes).

## What exists

- SwiftPM package, executable target `DiskLEDPlus` (AppKit menu bar app, no Xcode).
- `DiskActivitySource` — IOKit polling of `IOBlockStorageDriver` "Statistics"
  (bytes/ops read), aggregated over all disks, returned as per-tick deltas.
  Key names verified on this macOS build.
- `LEDIconRenderer` — programmatic 16×16 pt icon in two layouts (bars: two
  vertical rectangles; dots: two circles), left green (reads), right red
  (writes); per-layout cached states (off / R / W / both); not-template.
- `AppDelegate` — 30 ms `Timer` (`tolerance = 0`), blink-from-delta with no smoothing,
  menu with live B/s readout (1 s window, display-only), the Brightness submenu
  (10 steps, default 60%, persisted — see KB.md §Brightness), and About/Quit.
- Opt-in debug tracing (`DISKLED_DEBUG=1`, unified log, see KB.md §Debug tracing).

## Next steps (in order)

1. Operator uses the *installed* app (from `/Applications`) for a few days:
   judge perceived blink quality, off-state visibility on a light menu bar,
   and the menu's B/s readout.
2. If rejected by Gatekeeper on any future install (e.g. after a reclone on a
   new Mac) or a Developer ID shows up: notarize the bundle — the packaging
   script is the only place that would change (see KB.md §Packaging).
3. If the menu bar ever throttles swap rendering under load, evaluate a custom
   `NSStatusItem` view with the operator — never silently lengthen the tick.

## Environment notes

Development happens from the Hermes LT checkout (`/opt/data/workspace/diskled-plus/`,
registered as a Hermes project); the operator's daily-use build host's checkout is
`~/src/diskled-plus/`. No deployment target — it never runs on a server; GitHub is
the only distribution channel (plus later a notarized .app if requested).

Menu bar position gotcha for screenshots/verification: the status item's real
frame is discoverable via System Events
(`osascript -e 'tell application "System Events" to tell process "DiskLEDPlus"
to get {position, size} of every menu bar item of every menu bar'`). On this
machine it sits mid-bar among many other meter items; the tiny round dot nearby
belongs to usagebar, not to us.
