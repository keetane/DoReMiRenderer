# DoReMi Palette Integration

This document is the primary design note for Phase 12 DoReMi Palette iOS/iPadOS
app integration.

## Purpose

Phase 12 integrates `DoReMiRendererKit` into a real SwiftUI app experience. The
app loads MusicXML or MXL, displays the score, lets the user toggle note and
staff colors, steps through playback events, follows the current note while
scrolling, shows a simple piano keyboard, and exposes diagnostics for unsupported
MusicXML features.

Audio playback is intentionally not implemented in Phase 12. The app does not
use AVFoundation, MIDI, or an audio engine.

Phase 13 and later move the work from "integration exists" to "app becomes
practical": QA, real file import verification, persistence, playback, practice
mode, and real-device preparation are tracked in [ROADMAP.md](ROADMAP.md).

## Platform Priority

The DoReMi Palette app is iPad-first and should remain usable on iPhone. Layout
and manual QA focus on iPad Simulator first.

## Responsibility Boundary

`DoReMiRendererKit` remains an SDK. It owns parsing, domain models, layout,
rendering primitives, styling, hit testing, playback event generation, viewport
coordinate conversion, and scroll target calculation.

The DoReMi Palette app owns app state, file import, settings persistence,
screen composition, Japanese user-facing messages, the diagnostics panel, and
the piano keyboard UI.

The app must not reparse MusicXML, regenerate `NoteID`, recompute
`ScoreLayout` coordinates, or infer renderer internals.

## SDK APIs Used By The App

- `DoReMiRenderer`
- `ScoreInput`
- `ParseResult`
- `ScoreDocument`
- `LayoutOptions`
- `ScoreLayout`
- `ScoreCanvasView`
- `ScoreStyle`
- `ScaleColorPalette`
- `HitTestResult`
- `PlaybackEvent`
- `PlaybackOptions`
- `PlaybackMetadata`
- `ScoreViewportTransform`
- `ScoreScrollFollower`
- `ScoreScrollTarget`

The app may inspect public read models such as `ScoreNote`, `Pitch`,
`RendererDiagnostic`, and `NoteLayout` to drive UI state.

Current DoReMi Palette notation readability uses SDK-layout standard prefix
order `clef -> key signature -> time signature -> notes` with expanded spacing
so transposed or multi-accidental key signatures do not collide with bass clefs,
4/4, repeat-start barlines, or the first note/rest. The app does not compute
those positions. Accidental glyph colors are resolved through
`ScoreColorResolver`: note accidentals match the associated displayed note
pitch color when note colors are enabled, and fall back to ink when note colors
are disabled.

Measure width is also SDK-owned. DoReMi Palette consumes `ScoreLayout.measure`
frames as-is; it does not widen pickup measures, normalize short-note spacing,
or compensate prefix positions in app code. The current layout engine gives
normal measures a readable minimum width and gives first-measure pickup
candidates and trailing incomplete final measures a 75% normal-width minimum.
Non-final wrapped systems receive MVP width justification, while final systems
remain deliberately under-justified. Beam grouping, hit testing, scroll follow,
and playback IDs stay stable.

The Palette Editor MVP is also app-owned. DoReMi Palette persists a 12
pitch-class enabled set in `AppStorage`, keeps palette pattern selection as an
internal setting, and creates ordinary `ScoreStyle` color rules for the SDK.
Disabled pitch classes resolve to neutral ink for notes and keyboard coloring.
The renderer does not receive app UI state, does not parse MusicXML for the
palette editor, and continues to draw only from `ScoreLayout` and style
resolution.

Measure navigation is app-owned and read-only with respect to the SDK. DoReMi
Palette derives total measure count from `ScoreDocument.parts.first?.measures`,
maps current playback events and selected notes back to their existing
`MeasureID`, and uses the expanded `PlaybackEvent` list to select jump targets.
The app does not reparse MusicXML, regenerate `NoteID`, or calculate score
coordinates. Jumping to a measure updates the runtime index, current note IDs,
keyboard highlight, and existing `ScoreCanvasView` scroll follow state; active
playback is paused before the jump so audio and metronome tasks cannot continue
from the previous position.

The first-use guide is app-owned. DoReMi Palette stores guide completion in
`AppStorage`, registers SwiftUI view anchors for key controls, and draws a
coach-mark overlay in the app layer. The SDK, renderer, `ScoreLayout`,
`PlaybackRuntime`, `NoteID`, and playback events do not know about onboarding.
If a SwiftUI anchor is unavailable, the guide falls back to a centered card
instead of asking the SDK for coordinates.

## SDK Internals The App Must Not Use

- internal parser types
- internal MXL loader
- internal layout engine
- internal painter and drawing adapters
- internal playback builder
- internal diagnostics scanner

## Phase 12 Flow

1. Load bundled self-authored sample MusicXML on launch.
2. Parse through `DoReMiRenderer.parseWithDiagnostics(input:)`.
3. Build layout through `DoReMiRenderer.layout(score:options:)`.
4. Build playback events through `DoReMiRenderer.makePlaybackSequence(score:options:)`.
5. Render with `ScoreCanvasView`.
6. Update `currentNoteID` from tap and Previous / Next stepping.
7. Let `ScoreCanvasView` and SDK scroll-follow helpers keep the current note visible.
8. Highlight piano keyboard keys by looking up the current note pitch in `ScoreDocument`.
9. Show parser/layout/playback diagnostics in app UI.
10. Import user `.musicxml`, `.xml`, or `.mxl` files without storing private files in the repository.

## Phase 13+ Flow

The intended follow-up order after Phase 12 is:

1. Phase 13: App QA / import verification / UI tuning
2. Phase 14: Library / recent files / file persistence
3. Phase 15: Audio playback
4. Phase 16: Practice mode
5. Phase 17: Real iPad / TestFlight preparation

Phase 13 is the first step toward practical app readiness. It focuses on
Simulator QA, actual import verification, iPhone minimum checks, and UI
polish. If app QA exposes an SDK gap, the problem should be fed back into
`DoReMiRendererKit` instead of being hidden in app code.

Do not solve SDK gaps by reparsing MusicXML in the app, regenerating `NoteID`,
recomputing `ScoreLayout`, or guessing renderer coordinates.

## Phase 13 Part 1 QA Status

Phase 13 part 1 adds the app QA checklist, local import fixtures, import loader
coverage, and small layout polish for iPad and minimum iPhone reachability.
The app still imports files through the SDK facade and keeps MusicXML parsing,
layout, rendering, and playback-event generation inside `DoReMiRendererKit`.

Manual Files picker checks use self-authored fixtures under
`Apps/DoReMiPalette/TestImportFiles/`. If Simulator file transfer is not
available, app loader tests cover the same supported and failing import paths.
The Phase 13 part 1 retry confirmed iPhone launch, bundled sample visibility,
reachable controls, diagnostics sheet display, keyboard setting reachability,
and `1.0x` score visibility. Manual invalid-file selection through the iPad
Files picker still depends on making the local fixtures available inside the
Simulator Files app; invalid and unsupported import behavior is covered by app
loader tests.

## Phase 13 Part 2 QA Status

Phase 13 part 2 adds app-side regression coverage for keyboard pitch mapping,
current-note keyboard highlighting, chord/rest/out-of-range keyboard behavior,
settings persistence keys, diagnostics presentation, tap selection, zoom
coordinate conversion, and color-setting layout/playback invariance.
The current app zoom interaction is pinch-first: AppStorage keeps a continuous
`0.8x...3.0x` scale, ScorePracticeView passes that scale into
`ScoreCanvasView`, and SDK layout coordinates remain unchanged for hit testing
and current-note follow.

Manual Simulator QA confirmed iPad keyboard visibility, iPad diagnostics and
settings sheets, iPhone keyboard ON/OFF visual state, iPhone diagnostics, and
continued score visibility. iPad Keyboard OFF visual confirmation was attempted
through Simulator UI automation but did not toggle during this retry; the iPhone
visual check and app tests cover the OFF path. Manual invalid-file selection
through the iPad Files picker remains dependent on making the fixtures available
inside the Simulator Files app.

## Phase 14 Library Status

Phase 14 implements the DoReMi Palette Library / Recent files MVP as an app-side
responsibility. The SDK boundary remains unchanged:

- The app owns library metadata, recent-file ordering, sample-score lists, and
  local persistence.
- The SDK does not manage files or security-scoped bookmarks.
- The app reads `.musicxml`, `.xml`, or `.mxl` data and passes it to
  `DoReMiRenderer` through the existing `PaletteScoreLoader`.
- The app must not reparse MusicXML, regenerate `NoteID`, recalculate
  `ScoreLayout` coordinates, or infer renderer internals.
- Private score contents are not stored in `UserDefaults` or library metadata.

The implementation adds internal app models for sample and imported library
items, diagnostic summaries, JSON persistence for imported metadata, and a
Library sheet that lists bundled samples and recent imported files. Successful
imports add or update an imported library item and keep the existing
current-score reset behavior. Failed imports and failed recent reloads do not
replace the current score.

Recent imported files store metadata only, including optional bookmark data.
Bookmark resolve and start/stop access are handled in the app. If a file cannot
be resolved, the app shows a missing-file message and lets the user remove the
recent item. SDK changes are only warranted if app QA finds parse/layout/hit
test/playback metadata gaps; app code must not work around those by reparsing
MusicXML or inferring renderer coordinates.

## Phase 15 Playback Runtime Status

Phase 15 adds MVP audio playback as an app-side responsibility:

- `DoReMiRendererKit` still provides `PlaybackEvent` and playback metadata.
- DoReMi Palette owns the playback runtime, transport state, tempo control, and
  audio engine.
- AVFoundation is imported only in app-side playback/audio files.
- The renderer does not schedule audio or own playback state.
- Playback does not mutate `ScoreLayout`, regenerate `NoteID`, or recalculate
  score coordinates.
- `currentNoteID` and current note IDs remain app state and feed
  `ScoreCanvasView`, scroll follow, and `KeyboardView`.

The MVP audio engine generates simple tones without external assets. Chords play
all event MIDI pitches together, rests do not sound, and tie continuations do
not retrigger a note. If audio startup fails, the app can still advance the
cursor and highlight state. The Metronome MVP is app-side as well: the Palette
runtime owns the persisted ON/OFF setting, starts generated strong/weak clicks
with Play, follows the current BPM, builds measure-based click plans from the
expanded `PlaybackEvent` sequence, and stops on Pause / Stop / Reset /
playback end. Each planned click remains app state and records the measure
occurrence, beat index, time signature, and accent; DoReMiRendererKit does not
own metronome state, scheduling, or AVFoundation code. Phase S7 adds simple
repeat playback expansion in
the SDK playback sequence builder, and Phase S8 adds first/second ending MVP
expansion plus limited jump-marker diagnostics/handling. Phase S9 adds visual
first/second ending brackets as SDK layout/rendering elements. The app runtime
still only consumes an already-ordered `PlaybackEvent` list; it does not parse
MusicXML repeat syntax. High-quality instruments, complex jump repeat handling,
tuplets duration accuracy, transposition playback, and latency optimization
remain future work.

## Completion Criteria

- DoReMi Palette app builds as an iOS SwiftUI app.
- Bundled sample score appears on launch.
- MusicXML and MXL imports go through the SDK facade.
- Note color, staff color, current-note highlight, tap selection, zoom, and
  scroll follow work together.
- Previous / Next updates `currentNoteID`.
- Keyboard highlight follows the current note.
- Diagnostics are visible to the user.
- App settings persist with lightweight storage.
- Play / Pause / Stop / Reset controls can advance playback events with score
  and keyboard highlight synchronization.
- SDK tests, snapshot tests, Example app build, app build, license check, DocC
  build, and diagnostics collection continue to pass.

## Known App MVP Limits

- Audio playback is generated-tone MVP quality only.
- AVFoundation is app-side only; MIDI and AudioEngine-quality instrument
  playback are not implemented.
- No editing, annotation workflow, or drag selection.
- File import is local-device import only.
- Keyboard range is limited to the MVP range used by the app.
- iPad is the primary QA target; iPhone layout is functional but not final.

## Phase 16 Practice Mode MVP

Practice Mode is implemented in the DoReMi Palette app layer. The app uses
DoReMiRendererKit public read models such as `PlaybackEvent`, `NoteID`,
`ScoreLayout.noteByID`, and note pitch exposed through layout records. The SDK
continues to own parsing, layout, rendering, styling, hit testing, and playback
event generation; it does not own practice-session UI or state.

Practice Mode and PlaybackRuntime are separate flows:

- PlaybackRuntime advances automatically according to tempo and playback events.
- Practice Mode advances only when the user taps Next, Previous, or Reset.
- Turning Practice Mode on stops automatic playback and silences audio.
- Pressing Play from Practice Mode exits Practice Mode and resumes normal
  playback behavior.
- Practice Mode updates app `currentNoteIDs`, which drives score highlight,
  keyboard highlight, and scroll follow through existing app bindings.

MVP limitations remain: written-pitch note names only, no scoring, no microphone
or MIDI input, no AI analysis, and no advanced practice history.

## Playback Gate Ratio and Rhythm Sample

DoReMi Palette owns generated-tone articulation. The app playback runtime keeps
`PlaybackEvent` scheduling duration unchanged, but sends a shorter sound duration
to the app audio engine through `noteGateRatio`. This is intentionally outside
DoReMiRendererKit: the SDK still provides score, layout, and playback events,
while the app decides how generated tones are articulated.

The bundled `Rhythm Values Sample` is available through the sample catalog for
manual playback QA of whole, half, quarter, eighth, rests, repeated C notes, and
a simple chord.

## Attack / Tie Continuation Highlight Boundary

DoReMiRendererKit provides playback events; DoReMi Palette owns the app-side
display state that explains those events to the user. The app treats
`PlaybackEvent.noteIDs` as the visual current-note set and
`PlaybackEvent.midiPitches` as the new-audio-attack set.

When a tied note is visually current but not newly sounding, the app marks it as
a continuation. Score and keyboard UI use a weaker highlight for continuation
notes and the normal strong highlight for attack notes. Mixed events, such as a
tied lower note plus a newly sounding upper note, show both states at the same
time. Scroll follow prefers attack notes and falls back to continuation notes
when no attack is present.

The app must not reparse MusicXML or infer tie semantics from raw XML. It uses
only the SDK playback event and public layout pitch lookup.

## Note Value Rendering

DoReMiRendererKit owns note-value interpretation and rendering. MusicXML
`<type>` and `<dot>` are parsed into the domain model, layout emits notehead,
stem, flag, dot, and rest elements, and `ScorePainter` draws those layout
elements. DoReMi Palette only selects and displays the resulting score; it does
not infer note values or drawing coordinates in app code.

The `Rhythm Values Sample` is also the manual QA score for verifying that whole,
half, quarter, eighth, dotted notes, and rests are visually distinct.

## Notation Coverage Sample

The bundled `Notation Coverage Sample` is the app-level QA score for common
notation symbols on a two-staff grand staff. It is self-authored and available
through the sample catalog / Library sheet.

DoReMiRendererKit owns parser, domain, layout, and renderer behavior for these
symbols. The app only opens the sample through the existing SDK facade and shows
the resulting `ScoreCanvasView`; it does not reparse MusicXML or infer symbol
positions.

Current symbol support is tracked in `NOTATION_SUPPORT_MATRIX.md`. MVP-visible
items include clefs, time/key signatures, accidentals, common rest values,
dots, chords, ledger lines, repeat barlines, same-system tie/slur curves, safe
MVP beam groups including minimal mixed eighth/sixteenth secondary beams, and
basic triplet brackets. Dynamics, tempo text rendering,
final/double barline variants, complex tuplets, and advanced collision-aware
engraving remain partial or diagnostic-only and should be fed back into the SDK
in future notation hardening work.

## SMuFL Rendering Boundary

SMuFL music-font adoption is active for S1-S5 and is documented in
`SMUFL_INTEGRATION_PLAN.md`. It remains an SDK rendering concern, not an app
feature. DoReMi Palette should continue to open scores through the SDK facade
and display `ScoreCanvasView`; it should not choose SMuFL glyphs, reparse
MusicXML, infer symbol anchors, or compensate for renderer coordinates in app
code.

The current role of SMuFL is to improve glyph shapes for clefs, rests,
accidentals, repeat dots, time signature digits, noteheads, and flags.
Staff lines, ledgers, stems, beams, ties, slurs, highlights, tuplet brackets,
and selection overlays can remain Core Graphics paths where geometry is more
appropriate.

## Phase 16.5 Stabilization Boundary

Phase 16.5 is an app-and-SDK stabilization pass before Phase 17. SDK-owned work
stays in parser/domain/layout/rendering/playback-event generation: layout bounds,
note-value/rest visibility, symbol support status, `PlaybackEvent` semantics,
and `ScoreCanvasView` follow behavior. App-owned work stays in playback runtime,
audio engine, Practice Mode state, Library/Recent files, keyboard display, and
current-note highlight classification.

The app still must not reparse MusicXML, regenerate `NoteID`, recalculate
`ScoreLayout` coordinates, or infer unsupported notation from raw source text.
If a Phase 16.5 QA issue exposes a true notation/layout gap, the fix belongs in
DoReMiRendererKit rather than in app-side coordinate compensation.

## Phase 17A Real Device Boundary

Phase 17A is a real-iPad QA gate. Device discovery, signing, provisioning,
install, launch, Files import behavior, audio route behavior, and physical
interaction checks are app/device concerns. They must not change the SDK/App
boundary: DoReMi Palette still opens scores through the SDK facade and uses
`ScoreCanvasView`, while DoReMiRendererKit remains responsible for parsing,
layout, rendering, hit testing, diagnostics, and playback-event generation.

Physical iPad install / launch and MVP interaction checks have now been
confirmed by user-side QA. Phase 17B TestFlight readiness is a release
configuration, legal/privacy, checklist, and archive-preparation pass. The
TestFlight-facing bundled Library is intentionally limited to two learning MXL
samples: `Ode to Joy Easy Variation` and `Fur Elise - Beginner Piano`.
`Happy Birthday To You Piano` is excluded after the pre-TestFlight rights review
because its MusicXML metadata names an arranger and has no embedded rights
grant. Historical S6/S7/S8/S9/S10/T2 QA samples are not restored to the
user-facing Library; repeat, transpose, notation, and layout QA coverage should
live in SDK/app tests and development fixtures instead.

Playback timing hardening remains app-side. `PalettePlaybackRuntime` schedules
generated audio against a monotonic absolute clock and prewarms the app audio
engine, while DoReMiRendererKit continues to provide only `PlaybackEvent`
metadata. UI cursor updates, score highlights, scroll follow, and keyboard
highlights follow playback state; they must not block generated audio triggers.
Current-note follow uses SDK-provided layout identity and lightweight
measure-level anchors; DoReMi Palette does not recompute score coordinates.
The UIKit static-canvas path compensates SMuFL/CoreText glyph orientation inside
the renderer drawing helper without changing layout or app hit-test ownership.

## Phase S10 Repeat / Jump Boundary

Phase S10 keeps repeat and jump navigation in DoReMiRendererKit playback
sequence construction. DoReMi Palette receives the expanded `PlaybackEvent`
array and uses it for playback, Practice Mode, Previous / Next, score
highlighting, keyboard highlighting, and scroll follow. The app must not inspect
MusicXML words such as D.C., D.S., Fine, Segno, Coda, or To Coda.

Visual jump markers are SDK layout/renderer elements. They are drawn from
`ScoreLayout` and do not alter the app's Library, Practice, audio, or
diagnostics ownership boundaries.

## Piano Transpose Boundary

The piano transpose MVP starts app-side and now always requests display
transpose from the app UI:

- `transposeSemitones` is stored by DoReMi Palette settings and clamped to
  `-12...+12`.
- `PalettePlaybackRuntime` applies transpose only immediately before generated
  audio playback.
- Keyboard attack/continuation and next-note highlights use transposed sounding
  MIDI pitches.
- The app exposes a key picker (`C`, `C#`, `D`, ...) and stores the selected
  target as the existing clamped `transposeSemitones` value.
- DoReMi Palette asks the SDK loader to rebuild
  `ScoreLayout` from the original `ScoreDocument` using display transpose
  options. The app still does not reparse MusicXML or calculate score
  coordinates itself.
- Written key / sounding key and written note / sounding note are presentation
  text in DoReMi Palette.
- MusicXML `<transpose>` metadata is parsed and diagnosed by the SDK. Automatic
  transposing-instrument concert-pitch conversion remains disabled by default.
