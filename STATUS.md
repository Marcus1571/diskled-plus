# STATUS.md

## Where the project stands right now

**Verified working on device (2026-11-10, operator's Mac, macOS 27.2/arm64).**
v0.4.0: the app builds clean, runs, polls IOKit at 33 Hz, and blinks — idle
shows occasional green read blinks; sustained write load locks the icon
steadily both-lit (green + red) as designed. Screenshot verification of the
icon's lit states was done by zooming onto the System-Events-reported status
item frame. **Brightness submenu verified end-to-end on device** (ten steps,
default 60%, selection persisted to `UserDefaults`, operator set 50%, migrated
into the bundle-identifier domain on first bundled launch). **v0.4.0 adds real
packaging**: `scripts/make-app.sh` produces an ad-hoc-signed
`DiskLED-plus.app`, installed in `/Applications`, with a **Start at Login**
toggle (`SMAppService.mainApp`) — the installed `/Applications` copy is the
everyday way to run it from now on.

## What exists

- SwiftPM package, executable target `DiskLEDPlus` (AppKit menu bar app, no Xcode).
- `DiskActivitySource` — IOKit polling of `IOBlockStorageDriver` "Statistics"
  (bytes/ops read), aggregated over all disks, returned as per-tick deltas.
  Key names verified on this macOS build.
- `LEDIconRenderer` — programmatic square icon: two vertical rectangles, left green
  (reads), right red (writes); four cached states (off / R / W / both); not-template.
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
