# Changelog

## 0.1.0-mvp0 - 2026-05-02

Initial experimental MVP0 release.

This version is intended for integration review and early adopter testing. Public
APIs may change before `1.0`.

### SMuFL glyph rendering

- Added Bravura 1.392 as a bundled SDK resource under the SIL Open Font
  License 1.1.
- Added Core Text font registration and an internal SMuFL glyph map for clefs,
  accidentals, rests, repeat dots, time-signature digits, noteheads, and flags.
- Updated `ScorePainter` to render those notation symbols with SMuFL glyphs
  while preserving `ScoreLayout`, `NoteID`, `ScoreElementID`, hit testing,
  color rules, playback events, and app-level responsibilities.
- Tuned SMuFL glyph readability with SDK-internal category sizing for
  noteheads, accidentals, rests, flags, clefs, repeat dots, and time-signature
  digits, plus matching layout frames to reduce clipping and hit-test drift.
- Rebalanced the SMuFL sizing pass after visual QA: whole/half/black
  noteheads now use a closer visual scale, accidentals are slightly smaller,
  rest sizing is consistent, and flags are anchored to the Core Graphics stem
  end instead of floating from the notehead.
- Retuned the SMuFL visual balance after iPad QA: common noteheads are larger,
  stems are shorter and overlap the notehead edge, flags attach closer to the
  stem end, note accidentals sit closer to the notehead, and rest glyphs use a
  more consistent readable size.
- Follow-up SMuFL tuning enlarges black/quarter noteheads again for learning
  readability, shortens stems further, restores down-stem flag glyph selection,
  tightens flag anchors to the stem end, and moves note accidentals closer to
  noteheads.
- Increased clef / key signature / time signature prefix spacing so the
  Notation Coverage Sample exposes clef, key, and time symbols without overlap.
- Added Phase S6 MVP notation refinement: same-system tie/slur curve rendering,
  safe simple beam grouping, basic triplet bracket/number rendering, and the
  self-authored `S6 Notation Refinement Sample` as the current default launch
  sample for QA.
- Fixed the S6 follow-up notation QA issues: tie/slur curves now use the
  opposite-stem side, beams are drawn from the first stem tip to the last stem
  tip, and the S6 sample includes mixed eighth/sixteenth beaming for regression
  checks.
- Added Phase S7 Repeat Playback Expansion MVP: simple forward/backward repeat
  sections now expand in the playback sequence for two passes while preserving
  the original score, layout, note IDs, and playback events.
- Added diagnostics for repeat fallback and unsupported repeat structures such
  as backward repeat without a start, unmatched starts, nested repeats, and
  repeat counts outside the MVP two-pass behavior.
- Added the self-authored `S7 Repeat Playback Sample` grand-staff fixture and
  registered it in the DoReMi Palette Library as the current default launch
  sample for Phase S7 QA. The S6 notation refinement sample remains available
  from Library.
- Added Phase S8 Advanced Repeat / Playback Hardening MVP: first/second ending
  playback expansion, jump-marker parsing/diagnostics, and limited D.C. al Fine
  expansion for jump-only scores while preserving the original score, layout,
  note IDs, and playback events.
- Added the self-authored `S8 Repeat Endings Sample` grand-staff fixture and
  registered it as the current default launch sample for Phase S8 QA.
- Added a piano-focused transpose MVP in DoReMi Palette: `transposeSemitones`
  persists in app settings, playback MIDI pitches are transposed just before
  audio output, keyboard highlights follow sounding pitches, and current-note /
  key text can show written versus sounding values. Score rendering remains
  written-pitch.
- Added Phase T2 Score Display Transpose / MusicXML Transpose Hardening:
  DoReMi Palette can now transpose the rendered score layout while preserving
  the original `ScoreDocument`, `NoteID`, and
  playback event identity. The SDK layout engine applies display-only pitch,
  key-signature, and accidental MVP recalculation from layout options, while
  MusicXML `<transpose>` metadata is parsed and surfaced as diagnostics rather
  than silently ignored.
- Added self-authored T2 samples for key transpose, accidental transpose, and
  MusicXML transpose diagnostic QA.
- Fixed the T2 display-transpose follow-up QA issues: prefix notation now uses
  the standard `clef -> key signature -> time signature` order with expanded
  collision-safe spacing, and note accidentals now resolve to the same pitch
  color as their associated displayed note when note colors are enabled.
  Key-signature accidentals also use pitch-class coloring when note colors are
  enabled.
- Updated the transpose UI so score display transpose is always enabled by
  default and the control uses a key picker (`C`, `C#`, `D`, ...) instead of
  semitone +/- buttons.
- Added a DoReMi Palette Palette Editor MVP. The toolbar palette button opens a
  sheet with 12 pitch-class ON/OFF controls, all-on / all-off reset actions, a
  generated C2-C6 score preview, and a C2-C6 keyboard preview. Disabled pitch
  classes fall back to neutral ink while preserving layout, playback,
  transpose, repeat, Practice Mode, and Library behavior.
- Removed the visible preset pattern picker from the palette sheet and adjusted
  the preview layout so the C2-C6 score preview is visible in the sheet.
- Added an app setting for measure-number display. DoReMi Palette enables it by
  default and renders only odd-numbered measures to keep the score readable.
- Prepared Phase 17B TestFlight readiness: restored the default launch sample
  to the normal `DoReMi Palette Sample`, kept S6/S7/S8/S9/S10/T2 QA samples in
  Library, aligned the app version to `0.1.0` / build `1`, and added release,
  privacy, and beta-review checklist documents for pre-TestFlight review.
- Replaced the DoReMi Palette bundled sample scores with user-provided MXL
  files from `sample/`. The default launch score is now `Canon in D`; `12
  Variations of Twinkle Twinkle Little Star` was removed from the app sample
  catalog because its dense repeat-expanded playback is too long for the default
  learning sample set.
- Kept Core Graphics fallback rendering for font lookup or registration failure.
- Dynamics remain diagnostic-only unless represented by existing text
  annotations; system-crossing curves, advanced beams, complex tuplets, and
  collision-aware engraving remain future work.

### Phase 17A real iPad QA start

- Confirmed a physical `iPad Pro 2nd` running iPadOS `26.4.2` is visible to
  `xcrun xctrace` and `xcodebuild -showdestinations`.
- Confirmed the DoReMi Palette Debug build succeeds for the real iPad
  destination with bundle identifier `com.doremipalette.app`.
- Recorded the current QA blocker: Codex-side `devicectl` install / launch is
  blocked by a local CoreDeviceService initialization timeout, so runtime,
  audio, file-import, and settings QA still need Xcode Run or a recovered
  CoreDevice environment.
- Added the Phase 17A real-device QA checklist and device runbook. No app code,
  SDK code, signing setting, public API, or asset changes were made.

### Added

- Swift Package `DoReMiRendererKit`.
- Added a Print MVP for DoReMi Palette: the app can generate a PDF from the
  current `ScoreLayout` and open the standard iOS print sheet. The SDK exposes
  a small `ScoreGraphicsRenderer` CGContext drawing entry point so printing can
  reuse `ScorePainter` without app-side MusicXML parsing or coordinate
  recalculation.
- Added a score layout switcher for DoReMi Palette. Users can toggle between
  the existing horizontal one-row layout (`横一段`) and an A4-width layout (`A4`)
  that wraps measures into systems; printing always uses the A4 layout.
- Domain model for score documents, measures, notes, pitch, time, clefs, staves,
  score elements, diagnostics, and color rules.
- Minimal MusicXML `score-partwise` parser with diagnostics.
- MXL loading through standard `META-INF/container.xml` rootfile resolution.
- Minimal score layout engine with deterministic IDs and layout lookup tables.
- SwiftUI Canvas renderer through `ScoreCanvasView`.
- Styling and color resolution through `ScoreStyle`, `ColorRule`,
  `ColorContext`, and `ScoreColorResolver`.
- Hit testing from `ScoreLayout` coordinates.
- Playback event sequence generation without audio playback.
- iOS example app for parse, layout, render, color toggles, tap selection, and
  playback-event stepping.
- MVP0 legal, asset, third-party, and limitation notes.
- Phase 11A iOS Simulator snapshot tests for basic rendering regression
  coverage, including melody, grand staff, chords/rests, accidentals, ledger
  lines, current-note highlight, and note/staff color combinations.
- Phase 11B zoom and scroll coordinate conversion through
  `ScoreViewportTransform` and scaled `ScoreCanvasView` rendering.
- Phase 11D current-note scroll follow target calculation through
  `ScoreScrollFollower`, with `ScoreCanvasView` support for following
  `currentNoteID` changes.
- Phase 11F advanced MusicXML compatibility:
  - local/private diagnostics collection executable and compatibility report
  - lyric and fingering parsing, layout, rendering, hit testing, and snapshots
  - key signature layout elements for treble/bass staves
  - tempo and repeat metadata parsing without audio or repeat expansion
  - specific diagnostics for tuplets, slurs, ornaments, grace notes,
    transposition, beams, cross-staff notation, and voice collision limits
- Phase 12 DoReMi Palette iOS/iPadOS app integration:
  - separate SwiftUI app target under `Apps/DoReMiPalette`
  - bundled self-authored sample loading
  - `ScoreCanvasView` integration with color toggles, tap selection, zoom,
    current-note scroll follow, and Previous / Next stepping
  - simple piano keyboard highlight from public `ScoreLayout` pitch lookup
  - `.musicxml`, `.xml`, and `.mxl` file import through the SDK facade
  - Japanese diagnostics panel and lightweight display settings persistence

### Changed

- Phase 9 public API shrink moved parser, MXL loader errors, layout engine,
  painter, drawing adapters, playback builder, and future interaction handler
  implementation details behind the facade.
- Low-level layout, hit-test, and playback records remain publicly readable, but
  direct initializers are internal. Apps should obtain these values from
  `DoReMiRenderer`, `ScoreLayout`, and `ScoreCanvasView`.

### Known Limitations

- Experimental `0.x` API surface.
- Minimal MusicXML coverage.
- MXL support is limited to standard unencrypted rootfile flow.
- Publishing-quality engraving, complex collision avoidance, complex selection,
  and audio playback are not implemented.
- Snapshot coverage is limited to basic MVP0 rendering cases and does not
  guarantee full MusicXML display quality.
- Advanced MusicXML support remains partial; complex notation often produces
  diagnostics rather than full engraving.
- Pinch zoom, inertial scroll tuning, horizontal page navigation, and advanced
  automatic viewport management are not implemented.
- DoReMi Palette app integration is MVP quality; audio playback, advanced file
  library management, and iPhone-specific polish are not implemented.

## Roadmap Update - 2026-05-06

Added a Phase 13+ roadmap entry in `ROADMAP.md` and linked it from the README,
development notes, integration boundary, MVP limitation notes, and this
changelog. The roadmap now clearly separates:

- Phase 13: app QA, real import verification, and UI tuning
- Phase 14: library, recent files, and persistence
- Phase 15: audio playback
- Phase 16: practice mode
- Phase 17: real iPad and TestFlight preparation

The roadmap also records the feedback loop that sends real app gaps back into
the SDK when needed.

## Phase 13 Part 1 - App QA Start

Added the first Phase 13 app-readiness updates:

- `APP_QA_CHECKLIST.md` for iPad, iPhone, import, diagnostics, keyboard, and
  settings QA tracking
- self-authored import fixtures for `.musicxml`, `.xml`, `.mxl`, invalid
  MusicXML, and unsupported-extension checks
- DoReMi Palette app loader tests for supported import formats, failure
  handling, current-note reset, and existing-score preservation
- small SwiftUI layout polish for iPad readability and minimum iPhone
  reachability

Phase 13 part 1 retry confirmed iPhone launch, bundled sample visibility,
reachable controls, diagnostics sheet display, keyboard setting reachability,
and `1.0x` score visibility. Manual invalid-file selection through the iPad
Files picker remains tracked because the local fixtures still need to be made
available inside the Simulator Files app; app loader tests cover the invalid
and unsupported import paths.

## Phase 13 Part 2 - Keyboard / Settings / Diagnostics QA

Expanded the second Phase 13 app-readiness pass:

- keyboard pitch-mapping tests for natural notes, accidentals, current-note
  changes, chord highlighting, rest/missing-note, and out-of-range behavior
- app regression tests for tap selection, keyboard visibility state, zoom
  coordinate conversion, settings key persistence, diagnostics presentation,
  and color-setting layout/playback invariance
- Japanese diagnostics presentation helper for summary, severity, unsupported
  feature, repeat, and location text
- iPad/iPhone Simulator screenshots for keyboard, diagnostics, and settings QA

Phase 13 remains an app QA phase only. It does not add audio playback, library
persistence, or SDK public API changes.

## Phase 14 Part 1 - Library / Recent Files Foundation

Started the app-side Library / Recent files foundation without changing SDK
public API:

- internal DoReMi Palette library metadata model for sample and imported scores
- local JSON persistence for imported metadata only
- diagnostic-summary, last-current-note, and zoom-scale metadata fields
- bundled sample represented as a sample library item
- successful imports add or update an imported library item
- duplicate imports update the existing recent item
- failed imports keep the current score and do not add library metadata
- app tests for Codable round trips, corrupt store recovery, duplicate update,
  import success, and import failure behavior

Recent files UI, complete security-scoped bookmark restore, missing-file UI, and
remove-from-recent actions remain Phase 14 back-half work.

## Phase 14 Part 2 - Recent Files UI / Persistence / Missing File Handling

Completed the app-side Library / Recent files MVP without changing SDK public
API:

- Library sheet for bundled samples and recent imported files
- sample and imported rows with last-opened date and diagnostics summary
- tap-to-open for samples and recent imported files
- remove-from-recent action for imported items
- minimal bookmark metadata save/resolve path for imported files
- missing-file and failed-reload handling that keeps the current score intact
- app tests for reload success/failure, nil bookmark, bookmark metadata update,
  remove-from-recent, and metadata-only persistence

Security-scoped bookmark behavior remains provider-dependent, and raw MusicXML /
MXL contents are still not persisted by the library.

## Phase 15 - Audio Playback / Playback Runtime

Added MVP app-side playback runtime and generated-tone audio:

- app-side playback state for Play / Pause / Stop / Reset
- event-index based automatic playback over existing `PlaybackEvent` arrays
- tempo selection with clamped BPM handling and parsed tempo metadata fallback
- synchronized `currentNoteID`, score highlight, keyboard highlight, and scroll
  follow through existing app state
- generated sine-tone audio engine using AVFoundation only in the app target
- chord playback by mixing all event MIDI pitches
- rest and tie-continuation events do not trigger new audio
- mock-audio tests for runtime transitions, rest/chord/tie behavior, audio
  startup failure, tempo duration, and layout identity preservation

No SDK public API changes, external audio assets, or new dependencies were
added.

### Fixed

- Fixed a DoReMi Palette crash when changing tempo from the playback control.
  Tempo changes now safely clamp BPM, avoid reentrant SwiftUI state mutation,
  silence current audio, and restart playback scheduling from the current event
  when changed during playback.

## Phase 16 - Practice Mode MVP

- Added app-side Practice Mode for one-event-at-a-time score practice.
- Added written note-name and solfege display for the current practice step.
- Added Practice Mode controls for ON/OFF, Next, Previous, and Reset.
- Added a minimal color palette selector that does not mutate layout or playback
  identity.
- Defined PlaybackRuntime interoperability: Practice Mode stops playback, and
  Play exits Practice Mode for normal tempo-driven playback.
- Added app tests for practice state, note-name formatting, palette invariance,
  and playback/practice coexistence.

## Playback note gate and rhythm sample

- Added app-side `noteGateRatio` for generated-tone playback. Event scheduling
  still uses full `PlaybackEvent` duration, while sound duration defaults to 85%.
- Silenced the current generated tone before each new pitched event so repeated
  same-pitch notes are articulated separately.
- Added the self-authored `rhythm_values_sample.musicxml` bundled sample for
  whole, half, quarter, eighth, rest, repeated-note, and simple chord playback QA.
- Added tests for gate-ratio clamping, sound-duration calculation, repeated same
  pitch playback, and rhythm-value sample parsing.

## Note value rendering fix

- Added MusicXML `<type>` and `<dot>` propagation into the domain and layout
  models so note values are not inferred by the app or renderer.
- Render whole notes as hollow noteheads without stems, half notes as hollow
  noteheads with stems, quarter notes as filled noteheads with stems, and eighth
  notes as filled noteheads with stems and flags.
- Added layout/rendering support for note dots and basic rest-value drawing.
- Added parser, layout, renderer, app sample, and snapshot coverage for rhythm
  value rendering.
- Hotfixed Core Graphics stem geometry so single-voice notes below the middle
  staff line use upward stems and notes on or above the middle line use downward
  stems, while whole notes remain stemless.
- Fixed chord stem direction so chord tones in the same
  part/measure/staff/voice/onset share one MVP stem direction instead of mixing
  up and down stems inside a single chord.
- Fixed current-note scroll follow to avoid recentering every nearby playback or
  practice step. `ScoreCanvasView` now keeps layout-coordinate note anchors and
  only scrolls again when the current note leaves the viewport margin.

## Notation coverage sample and symbol audit

- Added the self-authored `notation_coverage_grand_staff.musicxml` bundled
  sample for checking treble/bass clefs, time and key signatures, accidentals,
  rest values, dots, ties, slurs, repeats, chords, ledger lines, and tempo /
  dynamic diagnostics in one app-visible score.
- Added MVP layout and rendering for clef, time signature, basic barline, and
  repeat barline elements from `ScoreLayout`.
- Added `NOTATION_SUPPORT_MATRIX.md` to distinguish supported, partial,
  diagnostic-only, and unsupported notation symbols.

## SMuFL integration planning

- Added `SMUFL_INTEGRATION_PLAN.md` for the future Bravura-first SMuFL
  rendering track.
- Recorded the license, architecture, QA, snapshot, and stop-condition policy
  for using SMuFL glyphs as symbol shapes while keeping MusicXML parsing,
  layout coordinates, IDs, hit testing, color resolution, and playback in
  DoReMiRendererKit.
- Added roadmap phases S1-S6 for preparation, font registration,
  clef/accidental/rest glyphs, repeat/dynamics/time signatures, notehead/flag
  glyphs, and tie/slur/beam refinement.
- No font files, renderer code, Info.plist entries, snapshot baselines, public
  APIs, or external dependencies were changed in this planning step.

## Playback follow / bounds / audio reliability fix

- Expanded `ScoreLayout.canvasSize` from rendered element union bounds within
  the normal page margins so high/low notes, stems, flags, ledger lines, rests,
  clefs, and barlines are less likely to clip at the top or bottom of the canvas.
- Stabilized `ScoreCanvasView` current-note follow heuristics so playback,
  step, practice, and tap-driven current-note changes can resume after rests and
  follow far-enough notes without snapping every nearby event back to center.
- Added a minimum audible generated-tone duration for short pitched playback
  events while preserving the original event scheduling duration.
- Added regression tests for layout bounds, scroll follow heuristics, and
  repeated/short-note audio paths.

## Tie continuation highlight distinction

- Split DoReMi Palette current-note display into attack and tie-continuation
  highlight states using `PlaybackEvent.noteIDs`, `PlaybackEvent.midiPitches`,
  and public layout pitch lookup.
- Added weaker secondary score highlighting for tied continuations while keeping
  the strong current-note highlight for newly sounding notes.
- Added keyboard highlight styling that distinguishes newly sounding pitches
  from tied continuation pitches.
- Added regression tests for mixed attack/continuation events, continuation-only
  tie events, rest events, and keyboard highlight priority.

## Layout bounds / scroll follow / audio reliability follow-up

- Kept SDK layout bounds stable while adding ScoreCanvasView scroll-content
  padding so edge notes, stems, flags, and ledger lines have room inside the
  scrollable viewport.
- Changed current-note follow to use measured note bounds and edge anchors
  instead of suppressing follow after user scroll or always returning to center.
- Updated playback audio triggering so any event with `midiPitches` plays those
  attack pitches, even when the same visual event also contains tied
  continuation notes.
- Added regression coverage for measured-bounds follow anchors, layout element
  bounds, and mixed tie-continuation/new-attack audio.
- Follow-up fix: moved scroll padding inside the Canvas coordinate system so
  top-edge notation is not clipped by the Canvas itself.
- Restored manual scrolling by keeping measured note-frame updates as data only;
  scroll execution now happens on current-note / zoom / layout changes, not on
  every geometry preference update.
- Removed the extra ScrollView drag recognizer from the follow path so normal
  manual scrolling remains owned by SwiftUI's ScrollView.
- Restored follow for offscreen notes whose measured viewport frame is not yet
  available by falling back to the stable note anchor ID.

## Phase 16.5 - Notation / Playback Stabilization

- Added a formal stabilization gate before Phase 17 for notation display,
  layout bounds, scroll follow, generated-tone playback, and Practice/Playback
  coexistence.
- Added SDK layout-origin compensation for extreme high notation whose rendered
  element bounds would otherwise extend above the canvas origin.
- Added regression coverage for high notes, upward stems, flags, and ledger
  lines staying inside positive canvas bounds.
- Synchronized Practice Mode step movement with `PalettePlaybackRuntime` so
  pressing Play after practice stepping resumes from the practiced event.

## Phase S9 - Advanced Repeat Visuals / Jump Marker Hardening MVP

- Added first/second ending visual bracket layout and Core Graphics rendering
  from `ScoreLayout` elements, including ending numbers and bracket hooks.
- Added `S9 Repeat Visuals Sample` as the default bundled QA sample while
  keeping S6, S7, S8, notation coverage, rhythm values, and the original sample
  available from Library.
- Kept S8 first/second ending playback expansion unchanged and added regression
  coverage that S9 playback order remains intro, repeated body, first ending,
  repeated body, second ending, and outro.
- Strengthened QA/docs around diagnostic-only jump markers such as D.S., Segno,
  Coda, and To Coda. The S9 sample includes a D.S. marker to verify diagnostics
  are visible without changing playback.

## Phase S10 - Complete Repeat Symbols Before TestFlight

- Added jump-only playback expansion for D.S. al Fine, D.C. al Coda, and
  D.S. al Coda while preserving the existing D.C. al Fine path.
- Added explicit repeat-count handling for simple repeats up to four passes,
  with invalid/excessive counts diagnosed rather than silently ignored.
- Added loop-prevention limits for jump/repeat expansion and diagnostics for
  unsafe mixed repeat+jump structures, multiple Segno/Coda markers, nested
  repeats, and third endings.
- Added MVP visual marker layout/rendering for Fine, D.C., D.S., Segno, Coda,
  and To Coda as `ScoreLayout` elements consumed by `ScorePainter`.
- Added five self-authored S10 QA samples for D.C. al Fine, D.S. al Fine,
  D.C. al Coda, D.S. al Coda, and diagnostic repeat/jump cases.
- Added `S10 All Repeat Symbols Sample` so manual QA can inspect repeat
  start/end, first/second endings, Segno, To Coda, Fine, D.C., D.C. al Fine,
  D.C. al Coda, D.S., D.S. al Fine, Coda, and D.S. al Coda in one score.
