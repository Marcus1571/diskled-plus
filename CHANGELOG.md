# CHANGELOG.md

## [0.7.2] — 2026-11-11

### Changed
- **Stacked layouts use the full menu-bar height (20 pt)** — operator
  feedback from real-bar comparisons vs the neighboring iStat BAT/100%
  element: the label now sits on the same plane as "BAT" and the LEDs reach
  the "100%" plane.
  - Label font is **10 pt regular** (thinner, matching the iStat elements'
    weight) instead of 9 pt semibold.
  - `dotsLabeled`: dots are now the **same size as the standalone dots
    layout** (7.5 pt) at the very bottom — no more shrunken 5 pt dots.
  - `monogram`: the red (writes) line now sits at the very bottom of the
    bar height; the green (reads) line stays at the top.
- Image sizes derived from the measured 10 pt "SSD" label:
  `dotsLabeled`/`monogram` 20 pt tall (~21 pt wide); `barsLabeled` unchanged
  (centered 16 pt row — operator raised no objection there). Enum raw
  values unchanged, persisted choices keep working.

### Verified on device (2026-11-11)
- Real menu-bar captures of both changed layouts next to the iStat elements
  (`screenshots/realbar2-*.png`): "SSD" plane and weight match "BAT"; dots
  match the standalone dots mode; red line at the lowest plane.

## [0.7.1] — 2026-11-11

### Changed
- **Labels renamed "dl+" → "SSD"** in all three labeled layouts
  (`dotsLabeled`, `monogram`, `barsLabeled`) — the operator's choice; "SSD"
  describes what the LED actually reports.
- **Vertical space fully used in the stacked/labeled layouts** (operator's
  critique vs the iStat BAT/100% element): stacked layouts now draw at the
  full 17 pt bar height with no internal margin — "SSD" (~9 pt semibold,
  iStat's two-line density) tight at the top plane, the LEDs at the very
  bottom plane. Applies to `dotsLabeled` and `monogram`; `barsLabeled`
  keeps a centered 16 pt row.
- **`monogram` redesigned per operator**: "SSD" in white with an activity
  line above and below the text (lines span the text width, over/underline
  style) — top line green on reads, bottom line red on writes, both
  near-dark when idle. Replaces the "dl" + diagonally split "+" glyph.
- Image sizes now derived from the measured "SSD" label text:
  `dotsLabeled`/`monogram` 17 pt tall (~20 pt wide), `barsLabeled`
  (~34×16). Enum raw values unchanged — persisted `ledLayout` choices keep
  working with no migration.
- `scripts/make-mockups.swift` — updated to the renamed/redesigned variants.

### Verified on device (2026-11-11)
- Real menu-bar captures of all changed layouts next to the iStat elements
  (`screenshots/realbar-*.png`): "SSD" sits on the same plane as iStat's
  "BAT", the LEDs sit down at the "100%" plane; no excessive top/bottom
  margins remain.

## [0.7.0] — 2026-11-11

### Added
- **Six indicator layouts** (operator's pick from the 2026-11-11 design
  sheet) — `LEDLayout` grows from 2 to 6 cases, all selectable in the
  Settings window, choice persisted under `ledLayout` (survives app updates):
  - `bars` — the original two rectangles (default, unchanged).
  - `dots` — two circles side by side (iStat-style).
  - `dotsLabeled` — small white "dl+" **stacked above** the two dots
    (operator's modification: minimize horizontal cost).
  - `letters` — "RW" where the letters themselves are the LEDs (R green on
    reads, W red on writes, near-dark when idle).
  - `monogram` — "dl" in white plus an activity "+": green on reads-only,
    red on writes-only, split diagonally (clipped glyph) when both, dim
    gray when idle.
  - `barsLabeled` — white "dl+" to the left of the bars.
- **Live preview** in the Settings window: a 4x-scaled both-lit rendering of
  the selected layout, refreshed on every layout/brightness change.
- `LEDIconRenderer` — per-layout image sizes (labeled layouts are wider than
  the 16×16 square: `dotsLabeled` 14×16, `barsLabeled` 30×16) and per-layout
  drawing, incl. text rendering and the clipped-glyph split plus.
- `scripts/make-mockups.swift` — regenerated as the six *shipped* variants
  (screenshots/statusbar-shipped.png, 2026-11-11).

### Changed
- `AppDelegate` — status item now runs at `variableLength` (was `squareLength`)
  so wider labeled layouts fit; `applyLayout` re-measures the item length.
- Behavior notes (KB §Settings): white "dl+" labels stay lit at all times so
  labeled layouts remain findable while the LEDs are off — the LED channels
  themselves still follow the strict off state; idle "RW"/"+" letters use the
  near-dark channel colors.

## [0.6.0] — 2026-11-11

### Added
- **Settings window** — new `Sources/DiskLEDPlus/SettingsWindowController.swift`.
  Menu → **Settings…** (⌘,) opens the app's first real preferences window:
  **Indicator layout** radio buttons (Bars / Dots) and a **LED brightness**
  slider (10–100%). Every change persists immediately to `UserDefaults.standard`
  and applies live to the status-bar icon; the window controls and the menu's
  Brightness submenu stay in sync in both directions (static shared accessors
  `AppDelegate.sharedLayout` / `sharedBrightnessPercent` are the single
  cross-object surface).
- **"Dots" indicator layout** — `LEDIconRenderer` now draws two layouts:
  `bars` (the original two vertical rectangles) and `dots` (two circles side
  by side, left green = reads, right red = writes — iStat-Menus-style, lower
  profile for a crowded menu bar). Same unsmoothed per-tick blink rule and
  off-state tints; brightness applies identically. Persisted under the new
  UserDefaults key `ledLayout` (default `bars`, so existing installs keep
  their look until changed).
- **Standard macOS About panel** — `AppDelegate.showAbout` now uses
  `NSApp.orderFrontStandardAboutPanel` (system panel: app icon, name,
  version) with an attributed credits block: author (Marcus1571), the pitch,
  the MIT license note, and a clickable link to
  github.com/Marcus1571/diskled-plus. Replaces the modal NSAlert text dump.
- `scripts/make-mockups.swift` — renders a status-bar design sheet (six
  candidate layouts, including label variants) into `screenshots/` for
  layout-design decisions; not part of the app.

### Changed
- `AppDelegate` — menu gains **Settings…**; `setBrightness` now routes
  through the shared accessor; layout/brightness application centralized in
  `applyLayout`/`applyBrightness` so menu and Settings window cannot drift.
- `KB.md` — dev-run instructions corrected: since 0.5.0 the bare binary
  links Sparkle and cannot launch without its framework (dyld abort); bare
  dev runs are replaced by running the built bundle.

## [0.5.1] — 2026-11-10

### Added
- **App icon** — the app now has a real one (previously the default gray
  grid placeholder). `scripts/make-icon.swift` renders it at package time:
  dark rounded plate, the two LED bars in the app's actual colors
  (`readLit`/`writeLit`), both lit, with lens-bright cores and glow; packed
  into `Resources/AppIcon.icns` by `scripts/make-app.sh` (CFBundleIconFile).
  No binary assets in the repo — the icns is generated during packaging, and
  `docs/img/app-icon.png` (the rendered PNG) is committed for the README.
- `Sources/DiskLEDPlus/AppDelegate.swift` — **About dialog rewritten**:
  version in the title (read from the bundle, blank for bare-binary
  launches), organized paragraphs (what it does / LED legend with color
  squares / the no-averaging point / license + inspiration credit), repo URL.

### Changed
- `README.md` — app icon shown in "What it looks like".
- `KB.md` — Packaging section notes the generated icon.

## [0.5.0] — 2026-11-10

### Added
- **Software updates (Sparkle 2.10.1 via SwiftPM)** — the bundled app now
  self-updates: automatic check at startup and weekly (`SUScheduledCheckInterval`
  604800, `SUAutomaticallyUpdate` so updates install without a prompt), feed
  `appcast.xml` in this repo served via raw.githubusercontent, EdDSA-signed
  (public key `4X6j0DXdJCmcxqe3fkMKWxKuuHhhM+rYrK5LauHe9UA=` baked into
  `Info.plist` as `SUPublicEDKey`; private key lives in the operator's login
  keychain, never in the repo). Menu gains a **Check for Updates…** voice
  (bundle launches only). `Sources/DiskLEDPlus/AppDelegate.swift` wires
  `SPUStandardUpdaterController`; bare-binary launches keep working without it.
- **`scripts/make-dmg.sh`** — distribution artifact: Developer ID–signed
  `.dmg` (built from `make-app.sh "$version" "Developer ID"` with hardened
  runtime + timestamp), staged with an /Applications symlink, default-assumed
  notary keychain profile `diskledplus-notary` (submits + waits + staples +
  validates; warns and skips cleanly when the profile isn't set up).
- **`scripts/make-appcast.sh`** — regenerates `appcast.xml` for a version from
  the built DMG: GitHub-Release enclosure URL, `sparkle:version` numeric stamp
  (CFBundleVersion mapping: major*10000+minor*100+patch, so 0.5.0 → 500),
  EdDSA signature via Sparkle's `sign_update` against the keychain key,
  `sparkle:releaseNotesLink` → the GitHub release page.
- `scripts/make-app.sh` — now embeds the Sparkle framework
  (`.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64`)
  into `Contents/Frameworks`, adds `@executable_path/../Frameworks` rpath, and
  stamps `Info.plist`: version from CHANGELOG heading (or argument), numeric
  CFBundleVersion, SU keys (`SUFeedURL`, `SUPublicEDKey`,
  `SUEnableAutomaticChecks`, `SUScheduledCheckInterval`,
  `SUAutomaticallyUpdate`). Signing is deepest-first (framework → bundle);
  passing `"Developer ID"` as second argument produces the notarizable
  hardened-runtime build; no argument keeps ad-hoc for local dev.
- `Package.swift` — Sparkle 2.10.1 dependency (SPM binary artifact; tools used
  by scripts live in `.build/artifacts/sparkle/Sparkle/bin/`).

### Changed
- **Developer ID trust chain fixed on the build host** (operator context, not
  code): the newly minted Developer ID Application cert
  (`Marco Dal Moro (NGPL7S3YX3)`) chains to Apple's newer
  **Developer ID Certification Authority, OU=G2** intermediate, which was not
  installed on this Mac — `codesign` failed with "unable to build chain to
  self-signed root". Fixed by fetching
  `https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer` into the
  login keychain (this remains true for any future Mac rebuild: install the
  G2 intermediate before first codesign).
- `KB.md` — new §Updates (Sparkle) section; §Packaging updated for
  Developer ID signing + the DMG + appcast release flow.
- `AGENTS.md` — release procedure for this project now includes the DMG +
  appcast steps.

## [0.4.0] — 2026-11-10

### Added
- `scripts/make-app.sh` — packages a fresh release build into a proper `.app`
  bundle at `.build/app/DiskLED-plus.app`: minimal `Info.plist` (bundle ID
  `com.diskledplus.app`, `LSUIElement`, `LSMinimumSystemVersion 13.0`,
  `NSHighResolutionCapable`), version stamped from the latest CHANGELOG heading
  (overridable via argument), ad-hoc codesigned — the build host has no Apple
  Developer ID, so notarization remains parked (see KB.md §Packaging). Install
  by `cp -R` to `/Applications/`.
- `Sources/DiskLEDPlus/AppDelegate.swift` — **Start at Login** menu voice, shown
  only when running from a `.app` bundle (withheld for the bare binary, where
  `SMAppService.mainApp` registration cannot work): toggles
  `SMAppService.mainApp.register()/unregister()`, with the checkmark derived
  from the live `SMAppService.mainApp.status` instead of a stored flag. A
  one-shot `--enable-login-item` launch argument performs the registration for
  scripted installs. Errors surface as a warning dialog (and into the unified
  log).
- Defaults migration in `applicationDidFinishLaunching`: before
  `register(defaults:)`, a first bundled launch copies `ledBrightnessPercent`
  from the pre-0.4.0 bare-binary defaults domain (`DiskLEDPlus`) into the
  bundle-identifier domain (`com.diskledplus.app`) if the new domain has no
  stored value — the operator's existing setting (50%) carried over.

### Changed
- `KB.md` — new §Packaging and §Start at Login sections; §Menu, §Brightness and
  §Build and run updated for the bundle and the defaults-domain change.
- `README.md` — Build and run section now points to `make-app.sh` +
  `/Applications` for everyday use.
- `STATUS.md` — current-state and next-steps updated (packaging shipped;
  operator evaluation now happens against the installed app).

## [0.3.0] — 2026-11-10

### Added
- `Sources/DiskLEDPlus/AppDelegate.swift` — Brightness menu voice: a `Brightness`
  submenu with ten steps (10%, 20%, … 100%), checkmark on the active one, default
  **60%** on first launch. Selection is persisted (`UserDefaults` key
  `ledBrightnessPercent`, clamped on read), and choosing a value re-renders the
  current LED state immediately so the change is visible between ticks.
- `Sources/DiskLEDPlus/LEDIconRenderer.swift` — brightness support: the lit colors
  are drawn at alpha = brightness %, so a value like 60% reads as the same hue
  dimmed against the menu bar rather than a color shift. Icons are cached per
  (state, brightness) pair. The off-state colors are deliberately untouched — "off"
  must not become "barely lit".

### Fixed
- `Sources/DiskLEDPlus/DiskActivitySource.swift` — the "Statistics property
  missing" warning introduced with the property-lookup fix logged on every tick
  while a transiently-matched entry lacks the dictionary (observed in bursts
  during mount/unmount races on this machine). Now logged once per process and
  suppressed after; behavior unchanged (missing → zero deltas, silent LED).

### Verified on device
- Brightness submenu shows all ten steps with ✓ on 60% (screenshot); clicking
  40% persisted to `UserDefaults` and clicking 60% restored it (read back from
  `defaults`); 60% default renders visibly dimmer than the previous 100% icons.
- Menu B/s readout live-checked during the interaction (Reads/Writes lines
  updating while the menu was open).

## [0.2.0] — 2026-11-10

First on-device verified release (operator's Mac, macOS 27.2 / arm64). **The app
now compiles, runs, and blinks correctly on real hardware.**

### Fixed
- `Sources/DiskLEDPlus/DiskActivitySource.swift` — the written-but-never-compiled
  `IORegistryEntryCreateCFProperty` call used a 5-argument form (with an
  `Unmanaged` out-parameter) that does not exist in the current Swift IOKit
  overlay; replaced with the standard 4-argument form returning
  `Unmanaged<CFTypeRef>?`. This was the only compile error; the build is clean
  otherwise. No behavior change (the new code does the same lookup).
  Also added a unified-log warning when a registry property is present but not
  a readable dictionary.

### Added
- `Sources/DiskLEDPlus/AppDelegate.swift` — opt-in per-tick debug tracing: launch
  with `DISKLED_DEBUG=1` and every tick logs to the unified log (subsystem
  `com.diskledplus.app`) with the milliseconds since the previous tick and the
  raw byte/op deltas for reads and writes. Defaults to off; only the startup
  info line changed otherwise. Purpose: troubleshooting cadence and burst
  behavior without touching the tick or the LED path (see KB.md §Debug tracing).

### Verified on device (clearing the AGENTS.md verification list)
- Compile clean on this toolchain (Swift 5.9+, Command Line Tools, macOS 27.2 SDK).
- `IOBlockStorageDriver` "Statistics" does carry the four expected keys on this
  build — read via `ioreg` and via the running app's deltas.
- Timer fires at ~33 Hz (median tick-to-tick 29.7 ms measured over 133 ticks;
  p95 34.2 ms; no coalescing with `tolerance = 0`).
- Icon renders in the menu bar with colors intact: left green and right red both
  observed lit (screenshots at the System-Events-reported item frame); sustained
  write load locks the icon steadily in the both-lit state.

Remaining human-eye checks for the operator: perceived blink smoothness over a
long session, off-state visibility on light menu bars, and the menu's B/s
readout formatting.

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
