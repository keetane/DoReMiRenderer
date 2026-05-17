# Release Checklist

## Phase 17B TestFlight Readiness

- Default launch sample: `Canon in D` (`Canon_in_D.mxl`).
- Bundled sample Library: five user-provided `.mxl` files copied from
  `sample/`. `12 Variations of Twinkle Twinkle Little Star` is intentionally
  excluded because its dense repeat-expanded playback is too long for the
  default bundled sample set.
- Previous S6/S7/S8/S9/S10/T2 QA samples were removed from the app bundle when
  the bundled sample set was replaced.
- Display name: `DoReMi Palette`.
- Bundle identifier: `com.doremipalette.app`.
- Version: `0.1.0`.
- Build number: `1`.
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

- `swift test`: passed.
- DoReMi Palette Debug simulator build: passed.
- DoReMi Palette App tests: passed.
- DoReMiRendererExample SDK snapshot tests: passed.
- Release generic iOS build: passed.
- Archive: passed at `/tmp/DoReMiPalette.xcarchive`.
- License check: passed.
- DocC build: passed, archive written to `/tmp/DoReMiRendererKit.doccarchive`.
- Local sample diagnostics: passed and regenerated
  `MUSICXML_COMPATIBILITY_REPORT.md`.
- Simulator install / launch: passed.
- Phase 17B screenshot folder: `/tmp/DoReMiPaletteQA/phase-17b/`.

Known release warning:

- Xcode validation warns that all interface orientations must be supported
  unless the app requires full screen. This does not block the local Release
  build or Archive, but should be reviewed before external TestFlight or App
  Store submission.

## Manual Before Upload

- Confirm the app launches on a physical iPad.
- Confirm generated-tone audio on device speakers or the selected output route.
- Confirm import of `.musicxml`, `.xml`, and `.mxl` from Files.
- Confirm Library, Recent files, Practice Mode, Playback, Transpose, Palette,
  Diagnostics, and Settings persistence.
- Confirm App Store Connect metadata, age rating, screenshots, and privacy
  answers with the account owner.
