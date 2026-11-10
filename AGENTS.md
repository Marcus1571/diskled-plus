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

## On-device status and standing checks

Cleared 2026-11-10 (v0.2.0) against the written-but-never-run code: compile
clean (one API-signature fix — see CHANGELOG), `IOBlockStorageDriver`
"Statistics" keys confirmed, 33 Hz cadence confirmed with no coalescing, both
LED halves verified rendering, steady-ON under sustained load. Evidence and
the per-item verification list live in `KB.md` §Verification list and
`findings.md` — do not re-derive them; extend the checks as the code evolves
instead of repeating cleared ones.

Still on the operator's eyes: perceived blink smoothness over real use,
off-state visibility on a light menu bar, and the menu's B/s readout.

## Working here

- Six governance files at repo root, per `Marcus1571/governance` conventions.
  Generic content only — no real hostnames/IPs/infra names in any of them.
- Every pushed code change is a release (item 6 of USER.md's sequence): version bump,
  CHANGELOG entry, `STATUS.md`/`KB.md` sync, tag, GitHub Release, push.
- **macOS release additions since v0.5.0** (after the version+docs commit, before
  `gh release create`): `scripts/make-dmg.sh <version> "Developer ID"` (signs and
  notarizes — requires the Developer ID keychain cert and the `diskledplus-notary`
  notary profile; stapling included), then `scripts/make-appcast.sh <version>`
  (regenerates `appcast.xml`, committed in the release commit), then upload the
  DMG as the GitHub Release asset. Push order matters: tag + release (asset live)
  before `git push origin main`, so the appcast's enclosure URL is valid once
  main's feeder readers see it.
- Commit identity for agent-made commits here: "Hermes LT <hermes-lt@legba.local>"
  (repo-local git config, matching sibling projects).
- Two screenshot homes, by purpose (operator decided 2026-11-10 when README
  screenshots shipped): `screenshots/` is the gitignored drop-zone for
  *verification* artifacts — never commit those PNGs. Public-facing images
  embedded in README/KB live under `docs/img/` and ARE committed. Recipes for
  capturing them live in `findings.md`.
