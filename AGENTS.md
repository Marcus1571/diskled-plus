# AGENTS.md

**Governance pointer (read first):** before working in this project, read
`GOVERNANCE.md` and `USER.md` from their working copy — the private GitHub repo
`Marcus1571/governance` — at the start of every session (pull the fresh copy). They
hold the operator's cross-project defaults and always apply. This file governs when
the two disagree on a project-specific fact; general defaults yield to this file,
except cross-cutting principles (secrets handling, destructive-action caution), which
apply everywhere.

## What this project is

DiskLED-plus — a macOS menu bar app that shows disk activity the way Helge Klein's
DiskLED does on Windows: as instantaneous, per-tick blinking LEDs, never as smoothed
meters. Two vertical rectangles forming one square: **left bright green = reads,
right red = writes**. Every I/O burst within a tick is guaranteed at least one
visible blink; sustained load reads as steadily ON.

## Stack and build

- Swift 5.9+ / SwiftPM, single executable target, no Xcode project.
  - Build: `swift build -c release`
  - Run: `.build/release/DiskLEDPlus`
- macOS 13+ (`kIOMainPortDefault` needs 12+; the docs claim 13 to be safe).
- AppKit only (no SwiftUI), `NSStatusItem` + `NSApplication.setActivationPolicy(.accessory)`.

## Non-negotiable design rules

1. **No smoothing, ever.** The LED bit-on condition is "any bytes OR operations moved
   during this tick". No averages over longer windows, no low-pass filter, no easing —
   that is the whole point of the project. Only the menu's B/s readout may use the
   rolling 1 s window (display-only).
2. **Keep the default tick at 30 ms** (`Constants.tickInterval`), matching DiskLED's
   proven `DEFAULT_COUNTER_1_MS = 30`. Do not raise it to "be nice to the CPU" without
   explicit operator approval — a lazier LED is a different, worse product.
3. Icon is a **not-template** image (`isTemplate == false`): the LED colors must
   survive; macOS must not re-tint the icon.
4. Deadline discipline: if the tick work (IOKit read + icon swap) ever needs to be
   off the main thread, it must stay self-contained — never introduce UI work off
   main.

## Verification gaps (first on-device session — new code that has never run)

The code was written without access to a Mac. Before trusting it, verify on real
hardware (operator's Mac, checkout at `~/src/diskled-plus/`):

- Does `swift build` compile clean? Fix imports/API drift as needed.
- Does the `"Statistics"` dictionary on `IOBlockStorageDriver` services actually
  carry `Bytes (Read)` / `Bytes (Write)` / `Operations (Read)` / `Operations (Write)`
  on this macOS build? Cross-check against `ioreg -l` output or `iostat` sources if
  keys differ, then fix `DiskActivitySource.swift` and update KB.md.
- Do 33 Hz icon swaps on `NSStatusItem` actually render furry-fast, or does the menu
  bar throttle? If throttled, evaluate a custom `NSStatusItem` view or slightly
  coarser rendering; **do not silently raise the tick interval** (see rule 2).
- Does the off-state remain visible on both a dark and a light menu bar?

## Working here

- Six governance files at repo root, per `Marcus1571/governance` conventions.
  Generic content only — no real hostnames/IPs/infra names in any of them.
- Every pushed code change is a release (item 6 of USER.md's sequence): version bump,
  CHANGELOG entry, `STATUS.md`/`KB.md` sync, tag, GitHub Release, push.
- Commit identity for agent-made commits here: "Hermes LT <hermes-lt@legba.local>"
  (repo-local git config, matching sibling projects).
- Operator drops UI screenshots into `screenshots/` (gitignored, never commit the
  PNGs).
