# Development

This project is a Swift Package with an iOS Example App.

The Phase 13+ execution order is tracked in [ROADMAP.md](ROADMAP.md). In
short, the next steps are app QA/import verification, then library and recent
file handling, then audio playback, practice mode, and finally real iPad /
TestFlight preparation.

## Local Tests

```sh
swift test
```

## MusicXML Compatibility Diagnostics

Private and third-party MusicXML samples belong in `LocalSamples/`, which is
ignored by git. Generate a compatibility report without embedding score contents:

```sh
swift run DoReMiRendererDiagnostics \
  --input LocalSamples \
  --output MUSICXML_COMPATIBILITY_REPORT.md
```

If `LocalSamples/` is missing, the command writes a skipped report and exits
successfully.

Phase 11F fixtures must be self-authored. If a private sample exposes a missing
MusicXML feature, create a small synthetic fixture that reproduces only that
feature; do not copy measures from the private score into tests.

Advanced MusicXML package tests cover:

- lyrics and fingering parse/layout/render/hit test
- key signature layout and ColorRule invariants
- tempo and repeat metadata without repeat expansion
- tuplets, slurs, ornaments, grace notes, transposition, cross-staff notation,
  and complex voices as explicit diagnostics where full rendering is not safe

## Example App Build

```sh
xcodebuild build \
  -project Examples/DoReMiRendererExample/DoReMiRendererExample.xcodeproj \
  -scheme DoReMiRendererExample \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1'
```

If that simulator is not installed, list available destinations:

```sh
xcodebuild -project Examples/DoReMiRendererExample/DoReMiRendererExample.xcodeproj \
  -scheme DoReMiRendererExample \
  -showdestinations
```

Then replace the destination with an installed iPad simulator, or use
`generic/platform=iOS Simulator` for CI builds that do not need to boot a
specific device.

## DoReMi Palette App Build And Test

Build the Phase 12 integration app:

```sh
xcodebuild build \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1'
```

Run app model and keyboard tests:

```sh
xcodebuild test \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1'
```

Manual simulator checks for Phase 12:

- bundled sample appears on launch
- note color and staff color toggles work
- `Previous` / `Next` move the current-note highlight
- tapping a note updates the current note
- zoom `1.0x`, `1.5x`, and `2.0x` render correctly
- keyboard highlight follows the current note
- diagnostics sheet opens and shows warnings/errors in Japanese
- file import accepts `.musicxml`, `.xml`, and `.mxl`

Phase 13 expands this checklist to include real import verification, iPhone
minimum layout checks, and small UI polish adjustments. Keep the roadmap in
[ROADMAP.md](ROADMAP.md) and the integration boundary in
[DOREMI_PALETTE_INTEGRATION.md](DOREMI_PALETTE_INTEGRATION.md) aligned with the
current app state.

Capture screenshots with:

```sh
xcrun simctl io booted screenshot /tmp/doremipalette_phase12_initial.png
```

## Snapshot Tests

Snapshot tests run in the Example App's iOS XCTest target:

```sh
xcodebuild test \
  -project Examples/DoReMiRendererExample/DoReMiRendererExample.xcodeproj \
  -scheme DoReMiRendererExample \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1'
```

Baselines live in:

```text
Tests/DoReMiRendererKitTests/__Snapshots__/
```

Record or update baselines with:

```sh
xcodebuild test \
  -project Examples/DoReMiRendererExample/DoReMiRendererExample.xcodeproj \
  -scheme DoReMiRendererExample \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1' \
  DMP_RECORD_SNAPSHOTS=1
```

The default pixel tolerance is 1%. Override it with:

```sh
xcodebuild test \
  -project Examples/DoReMiRendererExample/DoReMiRendererExample.xcodeproj \
  -scheme DoReMiRendererExample \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1' \
  DMP_SNAPSHOT_TOLERANCE=0.02
```

When a comparison fails, the test writes `actual.png`, `expected.png`, and
`diff.png` under:

```text
/tmp/DoReMiRendererSnapshots/<snapshot-name>/
```

Red pixels in `diff.png` indicate changed pixels. Review the actual image before
updating a baseline, and only record new baselines for intentional rendering
changes.

## Zoom And Scroll Coordinate Tests

Zoom and scroll conversion is covered by normal package tests:

```sh
swift test
```

The transform tests verify:

- identity mapping at `1.0x`
- scaled mapping at `2.0x`
- scaled mapping with content offset
- layout-to-view-to-layout round trips
- non-positive scale clamping
- note hit testing after view-to-layout conversion

When snapshot baselines change after zoom or scroll work, confirm the change is
caused by intended rendering behavior rather than a coordinate conversion bug
before recording new baselines.

## Scroll Follow Tests

Current-note scroll follow is covered by normal package tests:

```sh
swift test
```

The scroll follower tests verify:

- missing `NoteID` returns no target
- offscreen notes return a target
- target offsets clamp to zero and content bounds
- scale `1.0x` and `2.0x` produce expected centered offsets
- already visible notes inside the viewport margin do not request scrolling
- playback-step and tap-derived note IDs can be converted into scroll targets

Manual iPad Simulator checks should confirm that `Previous` / `Next` and note
taps keep the highlighted note visible at `1.0x`, `1.5x`, and `2.0x`.

## DocC Build

```sh
Scripts/build-docc.sh
```

The default output is:

```text
/tmp/DoReMiRendererKit.doccarchive
```

Override it with:

```sh
DOCC_OUTPUT_PATH=/tmp/custom.doccarchive Scripts/build-docc.sh
```

## License Check

```sh
Scripts/check-licenses.sh
```

The check confirms that `THIRD_PARTY_NOTICES.md` records ZIPFoundation and its
MIT License, and performs a simple GPL/LGPL string scan over dependency files.

## Common Failure Notes

- If `swift package dump-symbol-graph` succeeds but `xcrun docc convert` fails,
  confirm Xcode command line tools are selected with `xcode-select -p`.
- If the Example App build cannot find the simulator destination, run
  `xcodebuild -showdestinations` for the Example project and update the
  destination string.
- If a snapshot test fails, inspect the artifact directory printed in the XCTest
  failure message before recording a new baseline.
- If dependency resolution changes, re-run the license check and update
  `THIRD_PARTY_NOTICES.md` before committing.
- If GitHub Actions fails on simulator destination availability, prefer
  `generic/platform=iOS Simulator` unless a booted simulator is required.
