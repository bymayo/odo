# Odo

A macOS menu bar app for yearly activity goals, built on Strava data. Swift
package (no Xcode project), SwiftUI + AppKit, macOS 13+, auto-updates via Sparkle.

## Commands

```sh
make run              # build Odo.app (ad-hoc signed) and launch it
make dev              # swift run: bare executable, no Sparkle, LaunchAgent fallback
make package          # build Release and wrap it in a DMG (this Mac only)
make package SIGN=1   # the same, signed and notarised (reads .env.local)
make release VERSION=1.0.1   # bump Info.plist, commit, tag and push
make icon             # redraw Packaging/AppIcon.icns and .png from OdoMark.swift
make clean            # remove build/ and .build/
```

## Architecture

- `Sources/Odo/`: all app code. `AppDelegate` owns the status item and popover; `StravaViewModel` fetches, caches (`~/Library/Application Support/Odo`) and derives stats; `AppSettings` wraps UserDefaults.
- `OdoMark` draws the running-track mark: the menu bar template image, the popover header and, via `Scripts/AppIcon` (`make icon`), `Packaging/AppIcon.icns` and a 1024px `AppIcon.png`. Change the shape there and rerun `make icon`; both are committed.
- `Fitness` computes training load per activity (heart-rate TRIMP scaled so an hour at threshold is 100, then Strava's `suffer_score`, then a per-sport time estimate) and the fitness (42-day), fatigue (7-day) and form series; `FitnessView` draws the tab. Adding fields to `StravaActivity` means bumping `kCacheVersion` so cached years re-fetch.
- `Notifier` sends kudos for activities new since the last sync (current year only, none on the first sync, none older than three days), and the week/month/year summaries and pace reminders after each sync, for the menu bar's sport and metric; it records each period it has sent in UserDefaults so nothing repeats, and is inert in dev builds (no bundle). `CatchUp` (Pace.swift) works out the catch-up rate and the automatic doable target, shared by the goal cards and the pace reminder.
- `Fonts` registers Switzer (Indian Type Foundry, Fontshare) from `Contents/Resources/Fonts`; use `.font(.odo(size:weight:))`, never `.system`. Its licence allows embedding in the app but not hosting in this public repo, so `Scripts/fetch-fonts.sh` downloads it into `.fonts/` (gitignored) on every build; signed builds fail without it, and `swift run` falls back to the system font.
- `Packaging/`: `Info.plist` (version, bundle ID `uk.co.bymayo.odo`, `SUFeedURL`, `SUPublicEDKey`) and entitlements. `Scripts/build-dmg.sh` assembles `Odo.app` from the package build; there is no Xcode-generated plist.
- `AppInfo.isBundled` separates Odo.app from `swift run`. Sparkle (`Updater`) and SMAppService (`LaunchAtLogin`) only work in the bundle; dev builds skip updates and use a LaunchAgent.
- `LegacyMigration` copies settings from the old `StravaBar` and bare-executable `Odo` defaults domains into the bundle's, moves the cache and swaps old launch agents. It runs once, before anything reads settings.

## Releases

Same pipeline as Cargo. Pushing a `v*` tag runs `.github/workflows/release.yml`: it checks the tag matches `Packaging/Info.plist`, builds a universal binary, signs inside out (Sparkle's XPC services, Autoupdate and Updater.app each need the hardened runtime, or notarisation comes back Invalid), notarises, verifies with `spctl`/`stapler`, publishes the DMG to `bymayo/odo-releases` and overwrites `appcast.xml` there. Release notes are the matching `## <version>` section of `CHANGELOG.md`.

Failures open a `release-alert` issue (`.github/scripts/release-alert.sh`); `release-health.yml` catches tags never released, versions never tagged and pending Apple agreements.

Secrets on this repo: `MACOS_CERTIFICATE_P12`, `MACOS_CERTIFICATE_PASSWORD`, `MACOS_SIGNING_IDENTITY`, `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID` (the same as Cargo's), plus `SPARKLE_PRIVATE_KEY` and `RELEASES_REPO_TOKEN` (a token with contents write on `bymayo/odo-releases`).

The Sparkle EdDSA key is Odo's own, in the login Keychain under the account `odo` (not Cargo's). Export it for the secret with:

```sh
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account odo -x sparkle_private_key.txt
```

**Every build that leaves this machine must be signed and notarised.** A plain `make package` is for this Mac only. After a release, confirm it rather than assuming:

```sh
spctl -a -vvv -t install build/Odo-<version>.dmg   # expect: accepted, source=Notarized Developer ID
```

## Every commit

1. **`CHANGELOG.md`**: add a line under the version the work is heading for, written for the person receiving the update. The heading must match the tag; the workflow reads it verbatim.
2. **The version** in `Packaging/Info.plist`, kept in step with that section. `make release` bumps it, commits, tags and pushes; it refuses to run off `main` or without a changelog section.
3. **This file**, when a change makes it wrong.

Tooling-only changes (scripts, Make targets, notes) need neither a changelog line nor a version.
