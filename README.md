# DiskLED-plus

Every I/O gets its own blink.
A macOS menu bar app in the spirit of Helge Klein's DiskLED: not a thermometer, not a
graph — a live LED. One square made of two vertical rectangles: **left bright green
for reads, right red for writes**. Sampled at 30 ms (~33×/s), so every tiny read or
write becomes its own instant flash the way 80s-era physical HDD LEDs did — and
sustained load reads as steadily ON — never lazy, rounded-up, averaged summaries like
today's router LEDs do.

Fully open source (MIT), builds in one command with SwiftPM, no admin rights needed.

## Build and run

```
git clone git@github.com:Marcus1571/diskled-plus.git ~/src/diskled-plus
cd ~/src/diskled-plus && swift build -c release
.build/release/DiskLEDPlus
```

## What it is NOT

It is not iStat Menus, MenuMeters, or Stats — those are excellent meters, but they
sample on seconds-scale cadence and present numbers or graphs. DiskLED-plus samples
at 33 Hz and shows *every* tick the disk actually moved data, exactly as deeply
explained in [findings.md](findings.md#diskleds-magic-number-is-30-ms-verified-in-upstream-source).

For the full architecture, blink model, and build/run reference, see
[KB.md](KB.md#what-the-app-does). Idea credit: [DiskLED](https://helgeklein.com/free-tools/diskled/)
by Helge Klein (Windows, freeware) — no code or assets copied.
