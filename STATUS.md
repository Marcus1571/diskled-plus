# STATUS.md

**0.12.0 released** (2026-11-17): About page redesigned to the heat-warning panel card style (operator request, same design language as NeverSleep 0.15.0): icon header (icon 52 pt, leading-aligned) + three cards (♥ Support with QR/tiers/link/caption, 🐞 Report a Bug, 📄 License & code) + tagline footer; window 316 pt wide. Full sequence, released, notarized. E2E: About opened and verified.

## Where the project stands right now

**0.10.3:** appearance-flip re-render added — KVO on `effectiveAppearance` forces one
LED redraw when the system flips dark↔light, so the dynamic label/off colors never go
stale on an idle disk (live flip test pending the operator's eyes; macOS 27 removed the
AppleScript appearance control the session could have used).

**0.10.2:** PayPal link and QR payload lowercased to
`paypal.me/marcodalmoro` (QR asset regenerated and self-verified).

**0.10.1:** About-page links are real buttons (the attributed NSTextField
link labels never fired on click — verified on device that the buttons do).

**0.10.0:** "Report a Bug…" menu item (ladybug SF Symbol) + About page section,
both opening the repo's GitHub Issues. Verified on device (menu + About
screenshots in `screenshots/`).

**0.9.0:** About is now the NeverSleep-style mini page with the PayPal
donation QR (verified on device: QR renders, link and layout correct —
`screenshots/about-0.9.0-verify.png`).

**0.8.3:** off state = labelColor @15% alpha (clear in 0.8.1/0.8.2 made the icon invisible at idle; friend's Mac reported app missing). Unverified on a light bar.

**0.8.2:** label color now `NSColor.labelColor` (adapts to light/dark bar) — unverified on a light bar.

**0.8.1:** LED off state is now transparent (nothing drawn) instead of a near-dark tint — on a light menu bar the old blink read as black↔green/red. Awaiting operator's eyes on a light bar. `docs/img/led-off.png` still shows the old near-dark off state (regenerate when convenient).

**Verified working on device (2026-11-12, operator's Mac, macOS 27.2/arm64).**
v0.6.0: the app builds clean, runs, polls IOKit at 33 Hz, and blinks — idle
shows occasional green read blinks; sustained write load locks the icon
steadily both-lit (green + red) as designed. **New in 0.8.0**: the labeled
layouts' "SSD" label became a *drive label* — the system drive's medium type
is detected at launch via the IOKit registry (root volume → whole media →
`IOBlockStorageDriver` → `Device Characteristics` → `Medium Type`) and the
label reads "HDD" on a spinning-disk boot, staying "SSD" otherwise/unknown
(see KB.md §Drive type). Same change fixed a real pre-existing bug: IOKit
enumeration released each registry entry one step late, so external drives
never contributed stats and one handle leaked per tick. Sparkle self-updating
succeeded silently on device). A real Settings window (menu → Settings…, ⌘,)
carries the layout and brightness preferences since 0.6.0. The `/Applications`
copy is the everyday way to run it.

**Open design decision: RESOLVED (2026-11-11).** The operator picked the
status-bar layout set from the design sheet: the original bars stay default,
plus five new layouts — two dots, "SSD" stacked above the dots, "RW" letters
as LEDs, "SSD" with a blinking line above and below the text, and bars with
an "SSD" label — all selectable and persisted in Settings v0.7.0/resolved design; v0.7.1 renamed labels to "SSD"; v0.7.2 tuned the
stacked layouts to the full bar height after real-bar comparison with the
neighboring iStat elements (10 pt regular label, full-size dots, lines at
the extreme planes). v0.8.0 made the label *dynamic*: it reads the detected
system-drive medium type — "HDD" on a spinning-disk boot, "SSD" otherwise
(§KB.md Drive type).

## What exists

- SwiftPM package, executable target `DiskLEDPlus` (AppKit menu bar app, no Xcode).
- `DiskActivitySource` — IOKit polling of `IOBlockStorageDriver` "Statistics"
  (bytes/ops read), aggregated over all disks, returned as per-tick deltas.
  Key names verified on this macOS build.
- `LEDIconRenderer` — programmatic status-bar icon across six layouts (bars:
  two vertical rectangles; dots: two circles; three drive-labeled variants;
  "RW" letters), left green (reads), right red (writes); per-layout cached
  states (off / R / W / both); not-template. The label text is the detected
  system-drive type ("SSD"/"HDD", KB.md §Drive type).
- `SystemDriveType` — one-shot launch detection of the root volume's drive
  medium type from the IOKit registry (feeds the labeled layouts' label;
  unknown falls back to "SSD").
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
