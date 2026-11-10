# findings.md

Research log for DiskLED-plus (research done pre- and intra-project; verdicts recorded
with evidence).

## DiskLED's magic number is 30 ms (verified in upstream source)

Checked `MainFrm.h` + `MainFrm.cpp` in helgeklein/DiskLED (raw source, this session's
sibling research): `#define DEFAULT_COUNTER_1_MS 30` — the counter poll timer fires
every 30 ms (~33 Hz). `OnTimer` collects the PDH counter, normalizes against the
user-configured "what counts as 100%", picks one of 5 icons, swaps only when the
level changed. Two LED types exist upstream: `LEDTYPE_FLICKER` (5-stage blink ladder)
and `LEDTYPE_COLOREDBAR` (5 color states). There is zero smoothing machinery: the
furious, per-burst responsiveness is purely a consequence of 33 Hz sampling of
`% Disk Time`. **Verdict:** port the 30 ms tick as a hard default; human flicker
fusion (~15–60 ms) makes 33 Hz perceptually equal to per-I/O blinking.

## Honest nuance recorded for the record

DiskLED (and our port) is not literally event-per-I-O — it is 33 Hz sampling of a
rate counter. Any burst ≥ ~30 ms lights at least one tick. That is the same thing
perceptually, and it is deliberately NOT smoothed like modern router LEDs.

## Rival survey (macOS) — all fail the "furious" criterion

- MenuMeters (classic, open source; App Store fork "MenuMeters Reborn"): disk meter
  shows read/write arrows/lights, but sampled/updated on ~1–2 s cadence.
- iStat Menus (paid): rates and graphs, ~1 s cadence, not an LED philosophy.
- Stats (open source, Swift): disk module with graphs, seconds-scale cadence.
- Activity Monitor menu bar: not even close — 1–2 s, no LED.
Verdict: the niche (any-metric → instant LED at tens-of-ms cadence) is genuinely
empty on macOS; a port is not derivative redundance.

## macOS data source choice

Chose IOKit registry statistics of `IOBlockStorageDriver` services (kernel-maintained
per-disk counters; the class of data `iostat` reads) over alternatives:
- No admin rights needed; cheap per-poll (read property, snapshot, subtract).
- Splits reads and writes natively (required: green=reads, red=writes).
- `IOBlockStorageDriver` matches whole physical disks (incl. NVMe drivers subclasses),
  avoiding per-partition double counting that matching bare IOMedia causes.
Risk logged: exact "Statistics" key names must be verified on-device first build
(see AGENTS.md verification gaps).

## Rendering approach

`NSStatusItem.button?.image` swapped per tick, 4 pre-rendered cached NSImages
(off/R/W/both), `isTemplate = false` so LED colors survive the menu bar tinting.
Icon geometry per operator spec: two vertical rectangles side by side making one
square; left = bright green (reads), right = red (writes); 1 pt seam.

## Upstream project facts (for provenance)

DiskLED by Helge Klein, freeware, source at github.com/helgeklein/DiskLED (Win32/C++,
MFC). Config INI stored next to the EXE. Works on Windows XP+ without admin. We copy
neither code nor assets — idea credit only, stated in LICENSE and About dialog.

## First on-device build/verification (2026-11-10, operator's Mac)

This session had the real host (macOS 27.2 build 26B123, arm64, Command Line Tools,
no full Xcode project). Results, with evidence:

- **Compile:** exactly one error — `IORegistryEntryCreateCFProperty` was called
  with a 5-argument out-parameter form that doesn't exist in the Swift IOKit
  overlay. Fixed to the standard 4-argument returning form; build clean after.
  (Write-time-only code, so this was the entire delta between "source complete"
  and "compiles".)
- **IOKit keys:** `ioreg -r -c IOBlockStorageDriver -l` shows `Bytes (Read)`,
  `Bytes (Write)`, `Operations (Read)`, `Operations (Write)` as 64-bit numbers
  on both internal disks (APPLE AP0512Z, Samsung 980 PRO 1TB). No key drift.
- **Tick cadence:** 133 traced ticks: median dt 29.7 ms, p95 34.2 ms, max
  35.1 ms → solid ~33 Hz, no run-loop coalescing (tolerance 0 works).
- **Blink behavior under traced I/O:** a 64 MB `dd` write to /tmp showed reads
  during the generator phase and the writes as three ~16 MB flush bursts
  several ticks later (APFS async flush — expected; deltas are per-tick, no
  smoothing). Small idle reads (4–350 KB, 1–13 ops) blink throughout.
- **Rendering:** the status item's frame was queried via System Events
  (position 1526,3 size 24×24 on a notoriously crowded menu bar), screenshots
  zoomed onto it show left-half green lit at idle and *both* halves lit
  (green + red) under sustained write load, colors intact — `isTemplate=false`
  holds, macOS did not re-tint the icon.
- **Environment notes for future sessions:** the operator's zsh defines a
  `log` shell function that shadows `/usr/bin/log` (breaks `log stream` with
  a confusing "too many arguments" — use the absolute path); `log stream`
  needs `--level debug` to see debug-level messages. The tiny round dot in the
  menu bar near the right side belongs to the sibling app usagebar.

## README screenshot capture recipe (2026-11-10)

How the six images in `docs/img/` (v0.4.0-era) were captured live, so a future
session can rerun or extend the set. The installed app must be running from
/Applications.

- **Status-item geometry:** `osascript -e 'tell application "System Events" to
  tell process "DiskLEDPlus" to get {position, size} of menu bar item 1 of
  menu bar 1'` → e.g. `1545, 3, 24, 24` (points, x,y,w,h). `menu bar 2` does
  not exist on this macOS build (older notes used it).
- **LED tiles** (`led-off/led-reads/led-writes/led-both.png`): crop the item
  region with `screencapture -x -R1545,0,24,30 <file>` — output is 2x retina
  (48×60 px); the 16×16 pt icon occupies pixels ~x9–40, y14–46.
- **Classification without eyeballing every shot:** ImageMagick mean-channel
  sampling per half — left (green) `magick f.png -crop 16x32+9+14 +repage -scale
  1x1! -format "%[fx:int(255*u.g)]" info:` (lit ≈165, off ≈43); right (red)
  same crop offset +24+14 against `%[fx:int(255*u.r)]` (lit ≈136). On this
  machine the left/green is almost permanently lit under background activity,
  so a writes-only frame is scarce: fire a big `dd` write in the background and
  burst-capture ~40 shots at ~80 ms spacing, then fish for `leftG=43`.
  40 samples yielded 3 writes-only ticks.
- **State generator:** `dd if=/dev/zero of=.build/bigfile bs=1m count=8192
  conv=notrunc` (delete after) while `cat <bigfile> > /dev/null` runs in
  parallel for the both-lit shot. Off/read shots pop up on their own in short
  idle bursts.
- **Menu shots:** open with `osascript ... click menu bar item 1 of menu bar 1`,
  sleep ~0.6 s while it's open, `screencapture -x -R1520,0,320,340
  /tmp/menu-raw.png`, close with `key code 53`. Brightness submenu: click
  `menu item "Brightness" of menu 1 of menu bar item 1 of menu bar 1`, capture
  `-R1520,0,340,385` (385 point height — shorter clips `100%` at the bottom).
  Crop backgrounds away with magick (`-crop 452x512+40+0` for the menu; the
  bright capture keeps two dim fragments of the operator's own window behind
  the menu — benign, real-screenshot furniture on a public repo).
- The LED state in a menu shot is whatever the moment had (menu.png caught
  both-lit, bright-raw reads-lit) — a cosmetic lottery, not a bug.
