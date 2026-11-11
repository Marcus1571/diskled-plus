# KB.md

Canonical reference for DiskLED-plus. Facts here describe shipped behavior only.

## What the app does

Menu bar app (LSUIElement/accessory). Status-bar icon = one square, 16×16 pt, split
into two vertical rectangles separated by a 1 pt seam:

| Side | Color when lit | Meaning | Lit when (this tick, unsmoothed) |
|---|---|---|---|
| Left | bright green | reads | read bytes Δ > 0 OR read ops Δ > 0 |
| Right | red | writes | write bytes Δ > 0 OR write ops Δ > 0 |

Off state = same two rectangles in near-dark tint. Blink cadence = the timer tick;
sustained activity produces contiguous lit ticks, which read as steadily ON.

## The blink model

- Tick interval: **30 ms** (`AppDelegate.Constants.tickInterval`, Timer on main
  run loop, `.common` mode, `tolerance = 0` to prevent run-loop coalescing).
- Each tick: `DiskActivitySource.tick()` returns deltas since the previous tick.
  Counter resets (device removed) clamp deltas to 0 instead of fake-blinking.
- First tick only primes the baseline (returns zero deltas), never blinks.
- No averaging anywhere in the LED path. The menu's B/s text uses a rolling ~1 s
  window, display only.

## Data source

- IOKit: enumerate services matching class `IOBlockStorageDriver` (one per physical
  disk block device, including NVMe subclass drivers). For each, read registry
  property `Statistics` and sum keys:
  - `Bytes (Read)`, `Bytes (Write)`, `Operations (Read)`, `Operations (Write)`
- **Keys verified on-device** (2026-11-10, macOS 27.2 build 26B123): `ioreg -r -c
  IOBlockStorageDriver -l` shows exactly these four keys (values are 64-bit
  numbers). Values also flow through the app: per-tick deltas observed during
  real I/O, including 16 MB flush bursts for a 64 MB `dd` write.
- The property read uses `IORegistryEntryCreateCFProperty(entry, key, allocator,
  options)` in its 4-argument returning form; the 5-argument out-param variant
  does not exist in the current Swift IOKit overlay (compile error caught on
  first on-device build).
- Transiently, a matched `IOBlockStorageDriver` entry can lack the `Statistics`
  dictionary (observed in short bursts around mount/unmount races on this
  machine, e.g. 00:47 and again at 01:43 on 2026-11-10). The app treats a
  missing dictionary as zero contribution (no fake blink) and logs this once
  per process, not per tick.
- Read-only; requires no root/admin.
- `kIOMainPortDefault` (min macOS 12; package claims 13+).
- Deliberate choice over matching bare `IOMedia`: IOMedia also matches partitions
  and volumes → double counting.

## Debug tracing (opt-in)

Launch with `DISKLED_DEBUG=1` — every tick then logs to the unified log
(subsystem `com.diskledplus.app`, category `app`, debug level): milliseconds
since the previous tick, and the raw read/write deltas of that tick. Startup
also logs whether tracing is active. Off by default; when off, only errors,
warnings and the startup line are logged.

Inspect with:

```
/usr/bin/log stream --level debug --style compact \
  --predicate 'subsystem == "com.diskledplus.app"'
```

Note: the operator's zsh defines a `log` shell function, so from their
interactive shell use the absolute path `/usr/bin/log`.

## Rendering

- Programmatic NSImages, 16×16 pt, `isTemplate = false`, one per
  (layout, state, brightness). Icon only swapped when the LED state actually
  changed, to avoid pointless redraws (the state machine itself still runs
  every tick).
- **Layouts** (§Settings), six cases selectable in the window: `bars` — two
  vertical rectangles separated by a 1 pt seam (original DiskLED look);
  `dots` — two circles side by side (iStat-Menus-style); `dotsLabeled` —
  white "dl+" stacked above the dots; `letters` — "RW" as the LEDs;
  `monogram` — "dl" + activity "+" (green/red/split/idle); `barsLabeled` —
  white "dl+" left of the bars. All keep left/first=reads-green,
  second=writes-red and the same per-tick on/off rule; off state = same
  shapes in near-dark tint. White "dl+" labels stay lit at all times (so the
  layout remains findable while LEDs are off); idle letters/plus use the
  near-dark channel colors / a dim gray.
- Image sizes: 16×16 pt for `bars`/`dots`/`letters`/`monogram`; 14×16 for
  `dotsLabeled`; 30×16 for `barsLabeled`. The status item runs at
  `variableLength` and is re-measured on layout change.
- Colors: readLit green sRGB(0.05, 1.00, 0.25); writeLit red sRGB(1.00, 0.15, 0.15);
  off tints near-dark green/red respectively.

## Settings window

- Menu → **Settings…** (⌘,) opens the app's preferences window
  (`SettingsWindowController`, plain AppKit): **Indicator layout** pop-up
  (six layouts, §Rendering) with a live 4x preview of the both-lit state,
  and a **LED brightness** slider (10–100 %).
- Every change persists immediately and applies live; nothing is written on
  window close. Menu and window stay in sync both ways through
  `AppDelegate.sharedLayout` / `sharedBrightnessPercent` — the settings
  window updates a checkmark in the Brightness submenu, a menu change updates
  the slider on next `refresh()`.
- Keys: `ledLayout` (string, `bars` default) and `ledBrightnessPercent`
  (§Brightness). The settings window is available from bare-binary launches
  too (unlike Start at Login / Check for Updates, nothing here needs a
  bundle).

## Menu

- Header "DiskLED-plus"; live lines "Reads — X/s" and "Writes — X/s" refreshed on
  menu open from the last ~1 s window (live-verified on device while the menu stays
  open); Brightness (§Brightness); Start at Login (§Start at Login, bundle
  launches only); Check for Updates… (bundle launches only); **Settings…**
  (⌘,, §Settings); **About DiskLED-plus** — the standard macOS About panel
  (app icon, name, version) with credits: author Marcus1571, MIT license, and
  a clickable repo link; Quit (⌘Q).

## Brightness

- Right-click (any click on the status item) → menu → **Brightness** → ten items:
  `10%` `20%` `30%` `40%` `50%` `60%` `70%` `80%` `90%` `100%`. Checkmark marks the
  active value. **Default 60%** (operator-set). Also editable as a slider in the
  Settings window (§Settings); both stay in sync.
- Persisted immediately on selection: `UserDefaults.standard` key
  `ledBrightnessPercent` (integer 10–100, read clamped). It lands in
  `~/Library/Preferences/com.diskledplus.app.plist` when run from the .app bundle
  (verify with `defaults read com.diskledplus.app ledBrightnessPercent`);
  pre-0.4.0 bare-binary launches stored it in `DiskLEDPlus.plist`, and the first
  bundled launch migrates any existing value across *before* `register(defaults:)`,
  so the migrated value wins over the default (the 0.3.0-operator setting of 50%
  migrated on first run). First launch without any stored key uses 60 via
  `register(defaults:)` — the default cannot drift upward unnoticed.
- Effect: lit colors are drawn at alpha = value/100 — same hue, dimmer against the
  menu bar, never a different color. The off-state is unaffected by the setting
  (off means off). 100% reproduces the original full-strength look.
- Known good interaction: changing the value re-renders the current state at once,
  so a change is visible even while the light is currently steady ON.

## Updates (Sparkle)

- Bundled app checks for updates **weekly** (Sparkle 2,
  `SUScheduledCheckInterval = 604800`; `SUAutomaticallyUpdate = true` — updates
  install without a confirmation dialog once that preference is granted).
  The startup check honors the interval: it fires at launch **only when the
  scheduled interval has elapsed** since the previous check (confirmed live
  2026-11-11 — a same-day release was skipped silently at relaunch; the
  check ran after `SULastCheckTime` in the app's defaults was back-dated,
  or use the menu's Check for Updates… to force it immediately).
  Also observed live 2026-11-11: the Autoupdate installer can sit idle
  waiting for the running app to terminate before swapping the bundle —
  quitting the app lets the install complete; the new version is then
  launched by hand (or by the installer on its normal path).
  Feed: `Info.plist` `SUFeedURL` = raw.githubusercontent copy of this repo's
  `appcast.xml`; update first run shows Sparkle's standard one-time
  "Check automatically?" permission prompt.
- **Verification chain:** the app embeds `SUPublicEDKey`
  `4X6j0DXdJCmcxqe3fkMKWxKuuHhhM+rYrK5LauHe9UA=`; the appcast enclosure's EdDSA
  signature (from Sparkle `sign_update`, private key in the operator's login
  keychain, never in the repo) is what makes Sparkle accept an update. GitHub
  signed the installer DMG with Developer ID; Apple notarized it.
- **Numeric version mapping:** `CFBundleVersion` = major·10000 + minor·100 +
  patch (0.5.0 → 500). `sparkle:version` in appcast.xml must use the same
  mapping; Sparkle compares numerically. Don't bump patch by hand in both
  files — regenerate the appcast with `scripts/make-appcast.sh`.
- Menu: **Check for Updates…** (bundle launches only, like Start at Login).
- Sparkle ships via SwiftPM (binary artifact); its framework is embedded by
  `make-app.sh` into `Contents/Frameworks` and signed deepest-first — the
  framework (with its XPC services and Autoupdate helper) is signed before
  the app bundle so notarization sees a consistent tree.
- Appcast lifecycle per release, in order: (1) `make-dmg.sh <v> "Developer ID"`,
  (2) `make-appcast.sh <v>` → commit `appcast.xml`, (3) tag, (4) `gh release
  create` with the DMG attached, (5) push main. The feed URL serves the *main*
  branch's `appcast.xml`; it must not point at an enclosure that doesn't exist
  yet, hence release-before-push.

## Packaging (.app bundle)

- `scripts/make-app.sh` builds `.build/app/DiskLED-plus.app` from a fresh
  `swift build -c release`: the bare binary plus a minimal `Info.plist`. No Xcode
  project; the script is the whole package step.
- Bundle identity: bundle ID `com.diskledplus.app`; on disk the bundle is named
  `DiskLED-plus.app`, the executable inside is `DiskLEDPlus`.
- `LSUIElement = true` (menu-bar-only, no Dock icon — belt-and-braces with the
  app's own `.accessory` activation policy), `LSMinimumSystemVersion = 13.0`,
  `NSHighResolutionCapable = true`. No bundle icon ships; the visible icon is the
  programmatic status-bar image.
- Version stamp: `CFBundleShortVersionString` / `CFBundleVersion` default to the
  latest `## [X.Y.Z]` heading in `CHANGELOG.md`; pass a version explicitly for a
  pre-CHANGELOG build (`scripts/make-app.sh 0.4.1`).
- Signing: **ad-hoc** (`codesign --sign -`) — the build host holds no Apple
  Developer ID. Locally built apps carry no quarantine attribute, so Gatekeeper
  never intercepts local installs; distributing to *other* machines would need
  Developer ID signing + notarization (parked until such an identity exists).
- Install: `cp -R .build/app/DiskLED-plus.app /Applications/`.
- **App icon:** generated at package time by `scripts/make-icon.swift` (a
  Swift script drawing via CoreGraphics — same lit colors as the LED bars),
  converted through an `.iconset` into `Resources/AppIcon.icns` and declared
  via `CFBundleIconFile`. No `.icns` binary lives in git; the README's
  rendered copy is `docs/img/app-icon.png`.

## Start at Login

- Menu → **Start at Login**: the checkmark is re-derived from the live
  `SMAppService.mainApp.status` on every toggle — macOS is the source of truth,
  never a UserDefaults flag. Toggling calls `register()` / `unregister()`; the
  first registration may need one-time approval in
  System Settings → General → Login Items.
- The menu voice appears **only when launched from the .app bundle**; from the
  bare binary it is withheld (`SMAppService.mainApp` cannot register a
  non-bundle executable, so a voice there would be a liar button).
- Scripted installs can register without opening the menu: launch the bundle
  once with `--enable-login-item`; the app performs the registration at startup
  and logs the resulting status (unified log, §Debug tracing).

## Build and run

Development-style run (bundled, **not** the bare binary):

```
git clone git@github.com:Marcus1571/diskled-plus.git ~/src/diskled-plus
cd ~/src/diskled-plus && scripts/make-app.sh
open .build/app/DiskLED-plus.app
```

Since 0.5.0 the executable links Sparkle, so the bare
`.build/release/DiskLEDPlus` aborts at dyld load (framework not on rpath) —
always run the built bundle (v0.6.0, confirmed on device).

Everyday install (bundled, start-at-login capable): `scripts/make-app.sh` then
`cp -R .build/app/DiskLED-plus.app /Applications/` (details in §Packaging); enable
the login item from the app menu (§Start at Login).

Quit via the app menu.

## Verification list (first on-device build)

Cleared 2026-11-10 on the operator's Mac (macOS 27.2, arm64), evidence in
findings.md and the v0.2.0 CHANGELOG entry:

1. ✅ Compile clean on current macOS/Swift toolchain (after the
   `IORegistryEntryCreateCFProperty` fix).
2. ✅ `Statistics` key names correct on this macOS build (checked via `ioreg`
   and via live per-tick deltas).
3. ✅ 33 Hz tick cadence with no coalescing (median 29.7 ms over 133 traced
   ticks); icon state swaps render in the menu bar. *Perceived* blink
   smoothness over long use remains for the operator to judge.
4. ✅/👤 Off-state renders as near-dark rectangles (visible as a distinct dark
   square on this machine's dark-ish blue bar); light-menu-bar visibility is
   left for the operator to eyeball on a day with a light bar.

## Provenance and license

Idea credit: Helge Klein's DiskLED (Windows). Our code is original Swift, MIT.
No assets, code, or icons were copied from upstream.
