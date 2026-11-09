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
