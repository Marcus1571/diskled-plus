# STATUS.md

## Where the project stands right now

First public scaffold (v0.1.0) pushed to GitHub as source only. The Swift sources are
complete and internally consistent but have **never been compiled or run** — this
session had no macOS host. The first build must happen on the operator's Mac.

## What exists

- SwiftPM package, executable target `DiskLEDPlus` (AppKit menu bar app, no Xcode).
- `DiskActivitySource` — IOKit polling of `IOBlockStorageDriver` "Statistics"
  (bytes/ops read), aggregated over all disks, returned as per-tick deltas.
- `LEDIconRenderer` — programmatic square icon: two vertical rectangles, left green
  (reads), right red (writes); four cached states (off / R / W / both); not-template.
- `AppDelegate` — 30 ms `Timer` (`tolerance = 0`), blink-from-delta with no smoothing,
  menu with live B/s readout (1 s window, display-only) and About/Quit.

## Next steps (in order)

1. On the operator's Mac: clone to `~/src/diskled-plus`, `swift build -c release`, run,
   fix any compile errors (see AGENTS.md verification list). Copy ground truth back
   into KB.md.
2. Verify every small I/O produces a visible instant blink; verify sustained load
   locks steady ON.
3. If the menu bar throttles 33 Hz swaps, decide a rendering workaround with the
   operator — never silently lengthen the tick.
4. After on-device verification: release a first "works on hardware" tag (0.2.x minor
   bump per pre-1.0 convention).

## Environment notes

Development happens from the Hermes LT checkout (`/opt/data/workspace/diskled-plus/`,
registered as a Hermes project); the operator's daily-use build host's checkout is
`~/src/diskled-plus/`. No deployment target — it never runs on a server; GitHub is
the only distribution channel (plus later a notarized .app if requested).
