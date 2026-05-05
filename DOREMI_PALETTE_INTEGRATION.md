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
- SDK tests, snapshot tests, Example app build, app build, license check, DocC
  build, and diagnostics collection continue to pass.

## Known Phase 12 Limits

- No audio playback.
- No AVFoundation, MIDI, or AudioEngine integration.
- No editing, annotation workflow, or drag selection.
- File import is local-device import only.
- Keyboard range is limited to the MVP range used by the app.
- iPad is the primary QA target; iPhone layout is functional but not final.
