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

## SMuFL Rendering QA

Bravura SMuFL glyphs are bundled as SDK resources. When adjusting glyph
readability, keep sizing and anchors in DoReMiRendererKit layout/renderer code:
the app must not reparse MusicXML, choose glyphs, or recompute coordinates.
Recheck Rhythm Values Sample for notehead/stem/flag/rest balance and Notation
Coverage Sample for clef/key/time/accidental spacing. Snapshot diffs should be
limited to intentional glyph size or placement changes.

Current prefix QA should check the standard engraving order
`clef -> key signature -> time signature -> notes`. The SDK layout spacing must
still keep key signatures clear of bass clefs, 4/4, repeat-start barlines, and
the first note/rest, including display-transposed key signatures. When note
colors are enabled, note accidental glyphs must match the associated displayed
note color; key-signature accidentals use pitch-class color. With note colors
disabled, accidentals should render in the default ink color.

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

Use [APP_QA_CHECKLIST.md](APP_QA_CHECKLIST.md) for Phase 13 manual QA. Import
fixtures for local Simulator checks are stored in:

```text
Apps/DoReMiPalette/TestImportFiles/
```

The fixture set includes `.musicxml`, `.xml`, `.mxl`, invalid MusicXML, and an
unsupported `.txt` file. To test the Files picker manually, make those files
available to the Simulator Files app, open DoReMi Palette, tap `読み込み`, and
select each fixture. If direct Simulator file transfer is not available, the app
loader tests cover the same import success and failure paths.

Phase 13 part 1 retry note: the iPad import sheet can be opened in Simulator,
but invalid-file selection still requires making `Apps/DoReMiPalette/TestImportFiles/`
visible from the Simulator Files app. When that transfer route is unavailable,
use the app loader tests as the verification source for invalid files,
unsupported extensions, diagnostics updates, and preserving the existing score
after a failed import.

Minimum iPhone check:

```sh
xcodebuild build \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1'
```

Phase 13 part 1 screenshots use:

```sh
xcrun simctl io booted screenshot /tmp/doremipalette_phase13_part1_ipad_initial.png
```

When multiple Simulators have recently been booted, prefer an explicit UDID:

```sh
xcrun simctl io 841B3A9F-3010-454E-99D4-605C198419E0 screenshot /tmp/doremipalette_phase13_part1_ipad_initial.png
xcrun simctl io A6897099-AEE8-4B13-B281-0878E1A03D01 screenshot /tmp/doremipalette_phase13_part1_iphone_initial.png
```

Retry screenshots recorded during Phase 13 part 1:

- `/tmp/doremipalette_phase13_part1_ipad_initial.png`
- `/tmp/doremipalette_phase13_part1_ipad_import.png`
- `/tmp/doremipalette_phase13_part1_iphone_initial.png`
- `/tmp/doremipalette_phase13_part1_iphone_diagnostics.png`
- `/tmp/doremipalette_phase13_part1_iphone_keyboard.png`

Phase 13 part 2 focuses on keyboard, settings, diagnostics, and app regression
QA. Use the app tests for import failure preservation, settings key persistence,
diagnostics presentation, keyboard pitch mapping, chord highlight behavior, and
layout/playback identity checks. Manual Simulator screenshots recorded for this
pass:

- `/tmp/doremipalette_phase13_part2_ipad_keyboard_on.png`
- `/tmp/doremipalette_phase13_part2_ipad_keyboard_off.png` - attempted; iPad
  Simulator tap automation did not toggle the switch in this retry.
- `/tmp/doremipalette_phase13_part2_ipad_diagnostics.png`
- `/tmp/doremipalette_phase13_part2_ipad_settings.png`
- `/tmp/doremipalette_phase13_part2_iphone_keyboard_on.png`
- `/tmp/doremipalette_phase13_part2_iphone_keyboard_off.png`
- `/tmp/doremipalette_phase13_part2_iphone_diagnostics.png`

If Simulator UI automation becomes unstable, restart Simulator services, then
rerun the app tests before marking an item as manually blocked:

```sh
xcrun simctl shutdown all
killall Simulator
killall -9 com.apple.CoreSimulator.CoreSimulatorService
open -a Simulator
```

## DoReMi Palette Library And Recent Files

Phase 14 implements the app-side Library / Recent files MVP. The SDK still has
no file-management responsibility: app code reads file data, passes it to the
`DoReMiRenderer` facade through `PaletteScoreLoader`, and stores only local
metadata for successful imports.

The current library persistence is a JSON metadata file under the app's
Application Support directory:

```text
Application Support/DoReMiPalette/library.json
```

The JSON contains recent imported-file metadata such as display name, source
identifier, last-opened date, optional bookmark data, diagnostic summary, last
current note ID, and zoom scale. It must not contain raw MusicXML, MXL bytes, or
private user score contents.

The Library sheet shows bundled samples and recent imported files. Imported
items can be reopened through their stored bookmark metadata when available,
removed from Recent files, or reported as missing with a Japanese message. The
bookmark implementation is intentionally minimal: some providers or simulator
flows may require selecting the file again.

Run the app tests to cover the library model and store:

```sh
xcodebuild test \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1'
```

The tests cover sample/imported source distinction, Codable metadata round
trips, recent duplicate updates, remove-from-recent, bookmark metadata storage,
missing-file handling, corrupt JSON recovery, import success adding a
library item, and import failure leaving both the current score and library
metadata unchanged.

Capture screenshots with:

```sh
xcrun simctl io booted screenshot /tmp/doremipalette_phase12_initial.png
```

For Phase 14 Library QA, useful screenshot paths are:

```text
/tmp/doremipalette_phase14_part2_library.png
/tmp/doremipalette_phase14_part2_sample_list.png
/tmp/doremipalette_phase14_part2_recent_imported.png
/tmp/doremipalette_phase14_part2_reload_recent.png
/tmp/doremipalette_phase14_part2_missing_file.png
/tmp/doremipalette_phase14_part2_remove_recent.png
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

`ScoreCanvasView` uses transparent note anchors placed at `ScoreLayout`
notehead centers. The current-note follow path uses measured note bounds in the
ScrollView coordinate space: if the current note is inside the safe viewport
margin, it does not scroll; if the note leaves the margin, it scrolls toward the
nearest edge anchor instead of always forcing the score back to the center. Use
playback, Previous / Next, Practice Mode, and tap selection when manually
checking this behavior, especially after manual scrolling and after rests.
Measured note-frame changes update only the visibility data. They must not call
`scrollTo` by themselves, because geometry preference updates also happen during
manual ScrollView dragging and would otherwise override user scrolling.
If a current note does not yet have a measured viewport frame, the follow path
must still scroll to that note's stable anchor ID; otherwise offscreen notes can
never become measured and playback follow stalls.
Do not add custom drag recognizers around the score ScrollView unless they are
proven not to compete with native scrolling; manual scroll recovery depends on
SwiftUI's ScrollView owning normal drag gestures.

Layout bounds are also part of scroll QA. `ScoreLayout.canvasSize` must include
the union of noteheads, stems, flags, dots, rests, staff lines, ledger lines,
barlines, clefs, key signatures, and time signatures within the normal page
margins. When
high/low notes, stems, or flags appear clipped, first check the SDK layout
bounds; ScoreCanvasView also provides scroll-content padding so edge elements
can be brought into the viewport without changing stable layout coordinates.
That padding is applied inside the Canvas coordinate system for scrollable
scores, which keeps the painted score and transparent note anchors aligned.

## DoReMi Palette Playback Tests

Phase 15 playback is tested in the app test target:

```sh
xcodebuild test \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1'
```

The playback tests use a mock `PaletteAudioEngine` for deterministic coverage of
transport state, tempo duration calculation, chords, rests, tie continuations,
audio startup failure, repeated same-pitch events, minimum audible generated-tone
duration, mixed tie-continuation/new-attack events, and layout identity
preservation. The real
`SimpleToneAudioEngine` is intentionally app-side and uses generated tones with
no audio asset files.

Manual Simulator playback checks:

1. Launch DoReMi Palette on iPad Simulator.
2. Confirm Play / Pause / Stop / Reset are visible.
3. Tap Play and confirm the current-note highlight advances.
4. Confirm the keyboard highlight follows the current event.
5. Change tempo between 60 / 90 / 120 / 150 BPM and confirm the cursor speed
   changes.
6. Change tempo while stopped, while playing, and after Pause. The app should
   not close, the current-note highlight should stay valid, and audio should not
   remain stuck on a previous tone.
7. Confirm Previous / Next, Library, Diagnostics, Note Color, and Staff Color
   still work after playback.
8. On Rhythm Values Sample, confirm repeated same-pitch notes and short notes
   advance through the audio path. If the automation environment cannot provide
   audible output, rely on mock-audio tests and ask for user-side listening QA.
9. Turn Metronome ON, press Play, and confirm a strong first beat and weaker
   following beats. Pause, Stop, and Reset should stop clicks immediately.
10. Change BPM while Metronome is ON and playback is running. The click interval
    should follow the new BPM without moving to a different playback event.
11. Start Play with Metronome OFF, turn it ON mid-measure, and confirm the
    first click waits for the next beat boundary instead of treating the toggle
    moment as beat 1.

Capture screenshots with:

```sh
xcrun simctl io booted screenshot /tmp/doremipalette_phase15_playing.png
```

Capture a short recording when needed:

```sh
xcrun simctl io booted recordVideo /tmp/doremipalette_phase15_playback.mov
```

If audio is not audible in the automation environment, verify that the UI cursor
advances and rely on mock audio tests for event-to-audio behavior. The user
should still manually confirm audible output on their Simulator or device.

## Metronome MVP QA

The metronome is implemented only in the DoReMi Palette app layer. It reuses
generated tones through the app audio engine and does not add AVFoundation or
metronome state to DoReMiRendererKit.

Automated checks live in `PalettePlaybackRuntimeTests`:

- default OFF and runtime enable/disable;
- Play starts generated clicks only when enabled;
- strong and weak clicks use distinct generated pitches and velocities;
- enabling the metronome mid-playback waits until the next beat boundary and
  preserves the expected strong/weak beat phase;
- parsed MusicXML time signatures drive the metronome beat cycle, including a
  3/4 regression that clicks strong-weak-weak before the next strong beat;
- compound-meter tests cover `6/8` large-beat mode, `6/8` subdivision mode,
  and `9/8` / `12/8` large-beat accent patterns;
- tap tempo tests cover recent-tap averaging, long-gap reset, and BPM clamping;
- click sound style tests cover generated parameter changes without external
  sound assets;
- disabling while playing stops future clicks;
- existing playback, transpose, repeat, Practice Mode, Library, and
  Diagnostics tests remain unchanged.

Manual QA still needs listening confirmation because Codex cannot judge the
actual audio mix:

1. Enable Metronome from the main controls or Settings.
2. Press Play and confirm beat 1 is stronger than beats 2-4.
3. Pause, Stop, and Reset; no click should continue.
4. Change BPM during playback; clicks should follow the new interval.
5. Start playback with Metronome OFF, turn it ON mid-measure, and confirm it
   joins on the next beat rather than immediately clicking out of phase.
6. Open a 3/4 sample and confirm the strong click repeats every three beats.
7. Open a 6/8 sample. In `大拍`, confirm two large clicks per measure; in
   `細分`, confirm six subdivision clicks with a secondary accent.
8. Use Tap Tempo several times and confirm the BPM picker/runtime follows the
   tapped tempo.
9. Switch click sound styles and confirm the generated click character changes.
10. Open a repeat sample and confirm repeat navigation does not crash or desync
   the transport.

## Tie Continuation Highlight QA

Tie continuation display is app-side state derived from SDK playback events:

- `PlaybackEvent.noteIDs` drive visual current-note candidates.
- `PlaybackEvent.midiPitches` drive new generated-tone attacks.
- The app maps event note IDs back to public layout pitch data to split attack
  notes from continuation notes.

Run the DoReMi Palette tests after changing this path:

```sh
xcodebuild test \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5),OS=26.4.1'
```

Manual checks:

1. Open a score with tie continuation and mixed attack/continuation events.
2. Confirm strong score/keyboard highlight means a newly sounding attack.
3. Confirm weak score/keyboard highlight means a tied continuation.
4. Confirm rest events clear keyboard highlight.
5. Confirm Previous / Next and Practice Mode show the same classification as
   playback.

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

## Practice Mode QA

Phase 16 Practice Mode checks:

1. Build and run DoReMi Palette on the iPad Simulator.
2. Turn Practice Mode on.
3. Confirm Next, Previous, and Reset move the current note highlight.
4. Confirm note name and solfege text update with the current step.
5. Confirm keyboard highlight follows the practice step.
6. Confirm enabling Practice Mode stops automatic playback and audio.
7. Confirm pressing Play from Practice Mode returns to normal playback.
8. Switch color palettes and confirm layout, hit testing, and playback ordering
   do not change.

Automated coverage lives in the DoReMi Palette app tests for practice session
state, note-name formatting, palette invariance, and playback/practice
interoperability.

## Rhythm Values Playback QA

The app includes `rhythm_values_sample.musicxml` as a self-authored bundled
sample for playback QA. Open it from Library / sample scores and confirm:

1. Whole notes sound longer than half notes.
2. Half notes sound longer than quarter notes.
3. Eighth notes sound shorter than quarter notes.
4. Quarter and eighth rests do not sound.
5. Repeated C4 notes are heard as separate attacks, not one joined long note.
6. Tempo changes at 60 / 120 / 150 BPM remain stable.

`noteGateRatio` is fixed in the app playback runtime for MVP. It shortens only
sound duration; event scheduling and score highlighting continue to use the full
musical event duration.

## Note Value Rendering QA

The `rhythm_values_sample.musicxml` sample also verifies visual note-value
rendering. Open it from Library / sample scores and confirm whole, half,
quarter, eighth, dotted notes, and rests are visually distinct. Stem direction is
the current Core Graphics hotfix behavior: single-voice notes below the middle
staff line use upward stems, and notes on or above the middle staff line use
downward stems. Chord tones in the same part/measure/staff/voice/onset share
one MVP direction based on average staff position. Full one-stem chord engraving
and multi-voice collision handling remain future work.

Renderer snapshot coverage includes `rhythm-values.png`. When note-value drawing
changes intentionally, update the snapshot baseline with the normal snapshot
recording flow and review the visual diff before committing it.

## Notation Coverage QA

The app includes `notation_coverage_grand_staff.musicxml` as a self-authored
bundled sample for symbol coverage QA. Open `Notation Coverage Sample` from
Library / sample scores and confirm:

1. Treble and bass clefs are visible on the grand staff.
2. Time signature and key signature are visible near the start of the score.
3. Sharp, flat, and natural accidentals are visible.
4. Whole, half, quarter, and eighth rests are distinguishable.
5. Dotted notes, chords, repeated notes, and ledger-line notes are visible.
6. Repeat start/end barlines are visible.
7. Same-system tie/slur curves, simple beam groups, and basic triplet brackets
   are checked against `NOTATION_SUPPORT_MATRIX.md` so MVP support is not
   mistaken for publishing-quality engraving.
8. Dynamic marks, final/double barline variants, complex tuplets, and advanced
   symbols are checked against `NOTATION_SUPPORT_MATRIX.md` so partial or
   diagnostic-only support is not mistaken for full rendering support.

## S6 Notation Refinement QA

The app includes `s6_notation_refinement_grand_staff.musicxml` as the focused
Phase S6 bundled sample. Open `S6 Notation Refinement Sample` from Library and
confirm:

1. Consecutive eighth notes render as simple beams where safe.
2. A rest breaks a beam group.
3. Same-system tie and slur curves are visible and distinct.
4. Basic triplets show a bracket and number `3`.
5. Mixed eighth/sixteenth groups show a primary beam plus a minimal secondary
   beam segment where expected.
6. Accidentals, chords, repeat barlines, lyrics/fingering, and highlights remain
   visible without major collision.
7. Playback, Practice Mode, Library, Recent files, and Diagnostics still work.

Use the following screenshot paths for manual iPad QA:

- `/tmp/doremipalette_s6_default_sample.png`
- `/tmp/doremipalette_s6_tie_slur.png`
- `/tmp/doremipalette_s6_beam.png`
- `/tmp/doremipalette_s6_tuplet.png`
- `/tmp/doremipalette_s6_playback.png`

Use the following screenshot paths for manual iPad QA:

- `/tmp/doremipalette_notation_coverage_initial.png`
- `/tmp/doremipalette_notation_coverage_symbols.png`
- `/tmp/doremipalette_notation_coverage_playing.png`

The current support audit lives in `NOTATION_SUPPORT_MATRIX.md`. Update it when
parser, layout, renderer, or app-visible behavior changes.

## S7 Repeat Playback QA

The app includes `s7_repeat_playback_sample.musicxml` for Phase S7 regression.
Open `S7 Repeat Playback Sample` from Library and confirm:

1. Repeat start and repeat end barlines are visible.
2. Playback order is Measure 1, Measure 2, Measure 3, Measure 2, Measure 3,
   Measure 4.
3. Score highlight, keyboard highlight, and scroll follow return to the
   repeated measures on the second pass.
4. Practice Mode Next / Previous steps through the expanded playback sequence.
5. Unsupported repeat structures produce diagnostics instead of silent failure.
6. The S6 notation refinement sample remains available and unchanged in Library.

Use the following screenshot paths for manual iPad QA:

- `/tmp/doremipalette_s7_repeat_sample.png`
- `/tmp/doremipalette_s7_repeat_playing_first_pass.png`
- `/tmp/doremipalette_s7_repeat_playing_second_pass.png`
- `/tmp/doremipalette_s7_repeat_outro.png`
- `/tmp/doremipalette_s7_repeat_practice.png`

## S8 Repeat Endings QA

The app includes `s8_repeat_endings_sample.musicxml` as the Phase S8 bundled
sample. Open `S8 Repeat Endings Sample` from Library and confirm:

1. Playback order is Measure 1, Measure 2, Measure 3, Measure 4, Measure 2,
   Measure 3, Measure 5, Measure 6.
2. The first ending is heard and highlighted only on the first pass.
3. The repeated body is revisited, then the second ending and outro are played.
4. Practice Mode Next / Previous follows the same expanded sequence.
5. D.S., Segno, Coda, nested repeats, third endings, and ambiguous ending cases
   remain diagnostic-only.

Use the following screenshot paths for manual iPad QA:

- `/tmp/doremipalette_s8_endings_sample.png`
- `/tmp/doremipalette_s8_first_pass_first_ending.png`
- `/tmp/doremipalette_s8_second_pass_repeated_body.png`
- `/tmp/doremipalette_s8_second_ending.png`

## S9 Repeat Visuals QA

The app previously included `s9_repeat_visuals_sample.musicxml` for Phase S9.
The bundled app sample catalog has since been replaced with user-provided MXL
files from `sample/`, so this Phase S9 fixture is historical rather than a
current bundled Library item.

1. First and second ending numbers are visible above the staff.
2. Ending bracket horizontal lines and hooks are visible and do not replace
   repeat barlines.
3. Playback order remains Measure 1, Measure 2, Measure 3, Measure 4,
   Measure 2, Measure 3, Measure 5, Measure 6.
4. Unsupported D.S. / Segno / Coda structures appear as diagnostics when
   present rather than silent playback behavior.
5. Practice Mode, keyboard highlight, current-note highlight, Library, and
   Diagnostics still work with the expanded playback sequence.

Suggested screenshots:

## Phase 17B TestFlight Readiness

Phase 17B is a release-readiness gate, not a feature phase. After the bundled
sample replacement, the app launch default is
`Canon in D`, and the sample Library contains the five user-provided MXL files
copied from `sample/`. `12 Variations of Twinkle Twinkle Little Star` is kept
out of the bundled sample catalog because its dense repeat-expanded playback is
too long for the default learning sample set. Release configuration,
privacy, license, and archive status must be recorded before any TestFlight
upload.

Run:

```sh
swift test
xcodebuild build \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -destination 'platform=iOS Simulator,id=841B3A9F-3010-454E-99D4-605C198419E0'
xcodebuild test \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -destination 'platform=iOS Simulator,id=841B3A9F-3010-454E-99D4-605C198419E0'
xcodebuild test \
  -project Examples/DoReMiRendererExample/DoReMiRendererExample.xcodeproj \
  -scheme DoReMiRendererExample \
  -destination 'platform=iOS Simulator,id=841B3A9F-3010-454E-99D4-605C198419E0'
xcodebuild build \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -configuration Release \
  -destination 'generic/platform=iOS'
xcodebuild archive \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /tmp/DoReMiPalette.xcarchive \
  -allowProvisioningUpdates
Scripts/check-licenses.sh
Scripts/build-docc.sh
swift run DoReMiRendererDiagnostics LocalSamples
```

Manual QA screenshots should be grouped under
`/tmp/DoReMiPaletteQA/phase-17b/`, not scattered directly under `/tmp`.

- `/tmp/doremipalette_s9_repeat_visuals_sample.png`
- `/tmp/doremipalette_s9_first_ending_visual.png`
- `/tmp/doremipalette_s9_second_ending_visual.png`
- `/tmp/doremipalette_s9_repeat_playback.png`
- `/tmp/doremipalette_s9_diagnostics.png`
- `/tmp/doremipalette_s8_outro.png`
- `/tmp/doremipalette_s8_practice.png`

## Print MVP QA

DoReMi Palette exposes a toolbar `印刷` button and a score layout switcher. The
on-screen score can use the horizontal one-row layout (`横一段`) or an A4-width
layout (`A4`) that wraps measures into systems. Printing always uses the A4
layout so the PDF follows normal sheet-music proportions even if the user is
viewing the horizontal layout.

Implementation boundaries:

- `DoReMiRendererKit` owns the drawing path through `ScoreGraphicsRenderer`,
  which renders an existing `ScoreLayout` / `ScoreDocument` into a `CGContext`.
- DoReMi Palette owns PDF generation and the iOS print sheet.
- The app does not reparse MusicXML, regenerate `NoteID`, or recalculate
  `ScoreLayout` for printing.
- `PaletteScoreLoader` creates both horizontal and A4 `ScoreLayout` values from
  the same parsed `ScoreDocument`; the UI only switches which existing layout is
  active.
- Playback, Practice Mode, Library, and Diagnostics are not involved in the
  print path.

Manual QA:

1. Build and launch DoReMi Palette on iPad Simulator or a real iPad.
2. Load the bundled S6 sample or another sample.
3. Switch between `横一段` and `A4`; confirm the score changes from a single
   horizontal system to wrapped A4 systems without changing playback position.
4. Tap `印刷`.
5. Confirm the iOS print sheet appears with the A4 score PDF.
6. Cancel the sheet and confirm playback, scrolling, Library, and Diagnostics
   still work.

## Phase 16.5 Stabilization Verification

Phase 16.5 is the quality gate before real-device / TestFlight work. Run the
automated checks first:

```sh
swift test
xcodebuild build \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -destination 'platform=iOS Simulator,id=841B3A9F-3010-454E-99D4-605C198419E0'
xcodebuild test \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -destination 'platform=iOS Simulator,id=841B3A9F-3010-454E-99D4-605C198419E0'
xcodebuild test \
  -project Examples/DoReMiRendererExample/DoReMiRendererExample.xcodeproj \
  -scheme DoReMiRendererExample \
  -destination 'platform=iOS Simulator,id=841B3A9F-3010-454E-99D4-605C198419E0'
Scripts/check-licenses.sh
Scripts/build-docc.sh
```

Manual iPad Simulator QA should use `Notation Coverage Sample` first, then
`Rhythm Values Sample` for rhythm-specific checks. Confirm that:

- high and low notes, stems, flags, ledger lines, rests, clefs, and repeat
  barlines are not clipped at `1.0x`, `1.5x`, and `2.0x`;
- manual scrolling still works while stopped, and playback follow keeps the
  current measure/note visible without snapping every nearby event to center;
- rest events do not sound, tie continuations do not retrigger, mixed events
  sound only attack pitches, and repeated pitches remain separate attacks;
- Practice Mode stepping, Reset, and Play handoff keep the same current event.

## SMuFL Integration

The SMuFL music-font track is documented in
[SMUFL_INTEGRATION_PLAN.md](SMUFL_INTEGRATION_PLAN.md). Bravura 1.392 is bundled
as a DoReMiRendererKit Swift Package resource and registered by the SDK renderer
with Core Text. No App-specific glyph selection is allowed.

When changing the SMuFL renderer path, keep the development flow explicit:

1. Confirm font license, version, source, and app redistribution terms.
2. Update asset and third-party notices before committing any new or changed
   font file.
3. Add a small glyph-map test before replacing renderer shapes.
4. Keep all glyph placement driven by `ScoreLayout` / `ElementLayout`.
5. Use `Notation Coverage Sample` and `Rhythm Values Sample` as before/after
   QA fixtures.
6. Review snapshot diffs manually before recording new baselines.
7. Confirm fallback rendering still works by testing `ScorePainter` with a nil
   SMuFL font name.
8. Keep glyph readability tuning in the SDK renderer. `SMUFLGlyphSizePolicy`
   owns category scales for noteheads, accidentals, rests, flags, clefs, repeat
   dots, and time-signature digits; the app must not choose glyph sizes.
9. When adjusting SMuFL visuals, check both glyph size and anchor policy:
   noteheads should keep whole/half/black sizes visually close, stems should
   meet the notehead edge, flags should attach to the stem end, accidentals
   should not crowd noteheads or key signatures, and clef/key/time prefix
   spacing should remain non-overlapping.

SMuFL must improve symbol shapes only. It must not move MusicXML parsing,
layout, hit testing, color resolution, or playback into the app or an external
renderer.

## Phase 17A Real iPad QA Runbook

Phase 17A validates DoReMi Palette on a physical iPad before TestFlight work.
Simulator success is not enough for this gate.

Detect devices:

```sh
xcrun xctrace list devices
xcodebuild \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -showdestinations
```

Build for a detected iPad:

```sh
xcodebuild build \
  -project Apps/DoReMiPalette/DoReMiPalette.xcodeproj \
  -scheme DoReMiPalette \
  -destination 'platform=iOS,id=<device-id>' \
  -derivedDataPath /tmp/DoReMiPaletteDeviceDerivedData
```

Check the bundle identifier:

```sh
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
  /tmp/DoReMiPaletteDeviceDerivedData/Build/Products/Debug-iphoneos/DoReMiPalette.app/Info.plist
```

Install and launch, when CoreDevice is healthy:

```sh
xcrun devicectl list devices
xcrun devicectl device install app \
  --device <device-id> \
  /tmp/DoReMiPaletteDeviceDerivedData/Build/Products/Debug-iphoneos/DoReMiPalette.app
xcrun devicectl device process launch \
  --device <device-id> \
  com.doremipalette.app
```

If `devicectl` times out while initializing CoreDeviceService, use Xcode
instead: open `Apps/DoReMiPalette/DoReMiPalette.xcodeproj`, select the physical
iPad as the destination, then run Product > Run. Confirm the iPad is unlocked,
trusted, and Developer Mode is enabled under Settings > Privacy & Security.

After launch, complete the Phase 17A checklist in
`APP_QA_CHECKLIST.md`. Record any issue by layer: device setup, signing,
runtime, audio, file import, layout, scroll, practice, library, or diagnostics.

## Phase S10 Repeat / Jump Playback QA

S10 repeat navigation remains SDK playback-sequence work. Parser/domain retain
the MusicXML markers, `PlaybackSequenceBuilder` expands supported jump-only
orders, and DoReMi Palette consumes the resulting event list without reparsing
MusicXML.

Focused samples:

- `S10 D.C. al Fine Sample`: expected measure order `1,2,3,4,1,2,3`.
- `S10 D.S. al Fine Sample`: expected measure order `1,2,3,4,2,3`.
- `S10 D.C. al Coda Sample`: expected measure order `1,2,3,1,2,4,5`.
- `S10 D.S. al Coda Sample`: expected measure order `1,2,3,4,2,3,5,6`.
- `S10 Repeat Diagnostics Sample`: nested repeat, third ending, repeat+jump,
  excessive count, and multiple Segno diagnostics.
- `S10 All Repeat Symbols Sample`: visual/manual QA fixture containing repeat
  start/end, first/second endings, Segno, To Coda, Fine, D.C., D.C. al Fine,
  D.C. al Coda, D.S., D.S. al Fine, Coda, and D.S. al Coda in one score. This
  sample intentionally mixes repeats and jumps, so diagnostics are expected.

When adding repeat/jump support, keep explicit expansion limits in place and
prefer a warning diagnostic over any ambiguous or potentially looping playback
order.

## Piano Transpose QA

DoReMi Palette transpose is an app-side piano practice feature. It must not
alter SDK score parsing, `NoteID`, `ScoreElementID`, or `PlaybackEvent`
identity.

Checklist:

1. Use the control bar or Settings sheet key picker (`C`, `C#`, `D`, ...) to
   choose a different target key and return to the original key.
2. Confirm generated playback, score layout, score highlight, and keyboard
   highlight move together to the selected display key.
3. Confirm keyboard attack, continuation, chord, and next-note highlights use
   transposed MIDI pitches.
4. Confirm current-note text shows written and sounding notes when transpose is
   nonzero.
5. Confirm key text shows written key and sounding key when the parsed
   MusicXML key signature is available.
6. Confirm Practice Mode, Previous / Next, repeat-expanded samples, and jump
   samples use the same transpose setting without reparsing MusicXML.

## Phase T2 Score Display Transpose QA

T2 display transpose is always enabled in the app UI. It still must not rewrite
the original `ScoreDocument` or MusicXML file.

Checklist:

1. Use the key picker (`C`, `C#`, `D`, ...) and confirm the score layout, key
   signature, simple accidentals, playback, and keyboard highlights move to the
   selected display pitch.
2. Confirm the picker maps from the current written key to the selected target
   key and persists through app relaunch.
3. Confirm `NoteID`-based score highlight, keyboard highlight, Practice Mode,
   Previous / Next, and repeat-expanded samples still work.
4. Open `T2 MusicXML Transpose Sample` and confirm diagnostics report
   MusicXML `<transpose>` metadata instead of silently applying automatic
   concert-pitch conversion.
5. Treat enharmonic spelling, complex key changes, and transposing-instrument
   concert-pitch handling as MVP limitations unless a focused test proves the
   case.

## Palette Editor QA

The DoReMi Palette palette editor is app-owned. It passes filtered pitch-class
color rules into `ScoreStyle`; the SDK renderer does not store app UI state.

Checklist:

1. Launch DoReMi Palette and confirm the toolbar `パレット` button is visible.
2. Open the palette sheet and confirm there is no visible preset pattern
   picker, then confirm `全ON`, `全OFF`, `リセット`, 12 pitch-class buttons,
   C2-C6 score preview, and C2-C6 keyboard preview are visible in the sheet.
3. Confirm the default state is all pitch classes enabled.
4. Toggle `C` off and confirm C pitch classes fall back to neutral ink in the
   preview score and keyboard while other pitch classes remain colored.
5. Toggle `C` back on or use `リセット` and confirm color is restored.
6. Confirm Note Color OFF still renders notes in ink, independent of the
   pitch-class enabled state.
7. Confirm Staff Color ON follows the same enabled pitch-class filter for the
   staff-line color hints available in the MVP.
8. Confirm Playback, Practice Mode, transpose, repeat samples, Library, and
   Diagnostics still work.

Suggested screenshots:

- `/tmp/doremipalette_palette_button.png`
- `/tmp/doremipalette_palette_sheet_all_on.png`
- `/tmp/doremipalette_palette_sheet_c_off.png`
- `/tmp/doremipalette_palette_preview_keyboard.png`
- `/tmp/doremipalette_palette_preview_score.png`
