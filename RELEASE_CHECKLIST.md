# Release Checklist

## Phase 17B TestFlight Readiness

- Default launch sample: `Ode to Joy Easy Variation`
  (`Ode_to_Joy_Easy_variation.mxl`).
- Bundled sample Library: two musetrainer/library-derived `.mxl` files copied
  from `sample/`: `Ode to Joy Easy Variation` and `Fur Elise - Beginner Piano`.
  `Happy Birthday To You Piano` is excluded from the TestFlight app bundle after
  the 2026-05-21 rights review because its MusicXML metadata names an arranger
  and has no embedded rights grant. `12 Variations of Twinkle Twinkle Little
  Star`, `Canon in D`, and `The Entertainer` are also intentionally excluded.
- Previous S6/S7/S8/S9/S10/T2 QA samples were removed from the app bundle when
  the bundled sample set was replaced. Do not restore them to the
  TestFlight-facing Library; keep that regression coverage in development
  fixtures and automated tests.
- Display name: `DoReMi Palette`.
- Bundle identifier: `com.doremipalette.app`.
- Version: `0.1.1`.
- Build number: `2`.
- Signing: automatic signing with Apple Development identity and the configured
  development team.
- App icon: `Assets.xcassets/AppIcon.appiconset`.
- Launch screen: generated iOS launch screen setting in the app target.

## Required Commands

```sh
swift test
xcodebuild build -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj -scheme DoReMiPalette -destination 'platform=iOS Simulator,id=841B3A9F-3010-454E-99D4-605C198419E0'
xcodebuild test -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj -scheme DoReMiPalette -destination 'platform=iOS Simulator,id=841B3A9F-3010-454E-99D4-605C198419E0'
xcodebuild test -project Examples/DoReMiRendererExample/DoReMiRendererExample.xcodeproj -scheme DoReMiRendererExample -destination 'platform=iOS Simulator,id=841B3A9F-3010-454E-99D4-605C198419E0'
xcodebuild build -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj -scheme DoReMiPalette -configuration Release -destination 'generic/platform=iOS'
xcodebuild archive -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj -scheme DoReMiPalette -configuration Release -destination 'generic/platform=iOS' -archivePath /tmp/DoReMiPalette.xcarchive -allowProvisioningUpdates
Scripts/check-licenses.sh
Scripts/build-docc.sh
swift run DoReMiRendererDiagnostics LocalSamples
```

Phase 17B verification result:

- 2026-05-20 readiness rerun:
  - `swift test`: passed.
  - License check: passed.
  - Local sample diagnostics: passed and regenerated
    `MUSICXML_COMPATIBILITY_REPORT.md`.
  - DoReMi Palette Debug simulator build: passed.
  - DoReMi Palette App tests: passed after updating the onboarding step-order
    test to the current 12-step guide.
  - DoReMiRendererExample SDK snapshot tests: passed.
  - Release generic iOS build: passed.
  - Archive: passed at `/tmp/DoReMiPalette.xcarchive`.
  - Archive metadata: bundle identifier `com.doremipalette.app`, version
    `0.1.0`, build `1`, signing identity `Apple Development:
    snowborderjack1984@gmail.com (RC8J7NW32Q)`.
  - DocC build: passed, archive written to `/tmp/DoReMiRendererKit.doccarchive`.
  - Simulator install / launch: passed on iPad Pro 13-inch (M5), OS 26.4.1.
- 2026-05-26 performance final verification:
  - `swift test`: passed, 188 tests.
  - DoReMi Palette full App tests: passed, 133 tests.
  - DoReMiRendererExample snapshot tests: passed, 12 tests. Runtime keeps the
    UIKit static-canvas performance path; XCTest/snapshot rendering uses the
    SwiftUI Canvas fallback so screenshots remain flattenable.
  - License check: passed.
  - DocC build: passed, archive written to `/tmp/DoReMiRendererKit.doccarchive`.
  - Local sample diagnostics: passed and regenerated
    `MUSICXML_COMPATIBILITY_REPORT.md`.
  - Release generic iOS build: passed.
  - Archive: passed at `/tmp/DoReMiPalette.xcarchive`.
  - iPad Simulator install / launch: passed via XcodeBuildMCP.
  - Heavy sample playback spot checks saved under
    `/tmp/DoReMiPaletteQA/performance-final/`: Canon in D, Mozart Piano Sonata
    No. 16, and Fur Elise. Point-in-time CPU readings were approximately
    3.2%, 9.6%, and 6.6% respectively in this Simulator run. Previous Twinkle /
    Canon checks from the same performance pass were around 6.5% / 10.7%.
  - No continuous `ScoreStaticCanvasUIView.draw(_:)` hot path was observed in
    the saved stack samples.
- 2026-05-27 playback timing hardening:
  - Runtime scheduling now uses monotonic absolute event times, with generated
    audio prewarmed before the first scheduled onset.
  - iPad Simulator timing logs saved under
    `/tmp/DoReMiPaletteQA/playback-timing/`.
  - Canon in D: average 6.542 ms, p95 15.295 ms, max 19.200 ms.
  - Mozart Piano Sonata No. 16: average 6.052 ms, p95 14.922 ms, max
    28.474 ms.
  - Fur Elise - Beginner Piano: average 9.914 ms, p95 17.391 ms, max
    18.768 ms.
  - The Entertainer: average 8.117 ms, p95 18.273 ms, max 26.375 ms.
  - Twinkle Twinkle Little Star: average 15.715 ms, p95 31.072 ms, max
    32.440 ms.
- 2026-05-27 critical regression verification:
  - Fixed UIKit static-canvas SMuFL/CoreText y-axis orientation without changing
    `ScoreLayout` coordinates.
  - Restored current-note follow using raw current playback note IDs and stable
    measure-level anchors, avoiding the all-note geometry path that previously
    hurt large-score playback.
  - Hardened metronome meter sync with an expanded-sequence click plan. Planned
    clicks are anchored to score measure occurrences, so each 3/4 and 4/4
    measure starts with strong beat 0, pickup measures do not drift following
    bars, and mid-playback ON starts from the next planned click.
  - iPad Simulator evidence is saved under
    `/tmp/DoReMiPaletteQA/critical-regression/`.
  - Follow-up metronome-meter evidence is saved under
    `/tmp/DoReMiPaletteQA/metronome-meter-fix/`.
- 2026-05-28 TestFlight upload:
  - Archive export/upload succeeded for `com.doremipalette.app`.
  - Uploaded build: `0.1.1 (2)`.
  - iPad archive `UISupportedInterfaceOrientations~ipad` includes all four
    iPad multitasking orientations, including
    `UIInterfaceOrientationPortraitUpsideDown`.
  - Archive app bundle contains only `Ode_to_Joy_Easy_variation.mxl` and
    `Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl`.
- Phase 17B screenshot folder: `/tmp/DoReMiPaletteQA/phase-17b/`.

## Manual Before TestFlight Testing

- Wait for App Store Connect processing to finish.
- Add the processed build to internal TestFlight testing.
- Confirm export compliance / encryption answers in App Store Connect.
- Confirm the app launches on a physical iPad.
- Confirm generated-tone audio on device speakers or the selected output route.
- Confirm import of `.musicxml`, `.xml`, and `.mxl` from Files.
- Confirm Library, Recent files, Practice Mode, Playback, Transpose, Palette,
  Diagnostics, and Settings persistence.
- Confirm App Store Connect metadata, age rating, screenshots, and privacy
  answers with the account owner.
