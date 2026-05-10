# DoReMi Palette App Integration

Use `DoReMiRendererKit` from an app through the facade and view-level APIs. The
app should own file import, state, settings, diagnostics presentation, and
screen composition.

The app-execution roadmap for Phase 13 and later is tracked in
[ROADMAP.md](../../../../ROADMAP.md).

Phase 13 part 1 adds app QA tracking and self-authored import fixtures for
manual and loader-level `.musicxml`, `.xml`, `.mxl`, invalid file, and
unsupported-extension checks.

Phase 14 adds an app-owned Library / Recent files MVP. The app stores only
metadata for bundled samples and imported files, shows a Library sheet, can
reload recent imports through bookmark metadata when available, and keeps the
current score intact when a recent file is missing. Raw MusicXML and MXL file
contents are not persisted by the library.

Phase 15 adds app-owned MVP playback runtime and generated-tone audio. The SDK
still provides `PlaybackEvent` and metadata; AVFoundation and transport state
remain in the app target.

## Boundary

Apps should call `DoReMiRenderer` for parsing, layout, playback events, and
metadata. Render with `ScoreCanvasView`. Do not call parser, layout engine,
painter, MXL loader, or playback builder implementation types directly.

```swift
let renderer = DoReMiRenderer()
let result = try renderer.parseWithDiagnostics(input: .musicXMLData(data))
let layout = try renderer.layout(score: result.score)
let events = renderer.makePlaybackSequence(score: result.score)
```

## Current Note And Keyboard

Use `PlaybackEvent.noteIDs` or `HitTestResult.nearestNoteID` to update the
current note. A keyboard view can inspect public layout output:

```swift
let pitch = layout.noteLayout(for: noteID)?.pitch
```

Missing notes, rests, and out-of-range pitches should produce no keyboard
highlight.

## Playback Audio

Apps can consume `PlaybackEvent` arrays to drive their own transport:

- update app-owned current note state from the current event
- pass current note IDs to `ScoreCanvasView` and keyboard UI
- keep audio engines outside `DoReMiRendererKit`
- avoid mutating `ScoreLayout` or regenerating `NoteID`

DoReMi Palette's Phase 15 runtime uses generated tones for simple playback.
Rests do not sound, chords play the event MIDI pitches together, and tie
continuations do not retrigger a note.

## App MVP Limits

Audio playback is MVP quality. High-quality instruments, MIDI, background
audio, repeat expansion, exact complex-tuplet timing, transposition playback,
and advanced iPhone-specific polish remain future work.

## Practice Mode Boundary

DoReMi Palette Practice Mode is an app-layer feature. The app consumes public
SDK read models such as `PlaybackEvent`, `NoteID`, score layout note records,
and pitch data, then owns the practice session state. DoReMiRendererKit does not
own Practice Mode UI, scoring, microphone input, MIDI input, or learning
analytics.

Practice Mode advances by explicit user actions, while audio playback advances
by tempo. Enabling Practice Mode should stop app playback and silence app audio;
pressing Play from Practice Mode can return the app to normal playback.
