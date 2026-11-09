# CHANGELOG.md

## [0.1.0] — 2026-11-10

First public scaffold. **Source-only release: never compiled or run anywhere yet.**

### Changed/Added (all initial)
- `Package.swift` — SwiftPM executable, macOS 13+, no Xcode project.
- `Sources/DiskLEDPlus/main.swift` — accessory-policy NSApplication entry.
- `Sources/DiskLEDPlus/AppDelegate.swift` — 30 ms tick timer (tolerance 0), blink
  state machine with no smoothing, menu with live B/s readout, About, Quit.
- `Sources/DiskLEDPlus/DiskActivitySource.swift` — IOKit IOBlockStorageDriver
  "Statistics" aggregation, per-tick deltas, counter-reset clamping.
- `Sources/DiskLEDPlus/LEDIconRenderer.swift` — programmatic 16×16 two-rectangle LED
  icon (left green reads, right red writes), 4 cached states, not-template.
- Governance: README/KB/STATUS/findings/AGENTS/CHANGELOG, MIT LICENSE with idea
  credit to Helge Klein's DiskLED.
