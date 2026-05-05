# DoReMi Palette App Integration

Use `DoReMiRendererKit` from an app through the facade and view-level APIs. The
app should own file import, state, settings, diagnostics presentation, and
screen composition.

The app-execution roadmap for Phase 13 and later is tracked in
[ROADMAP.md](../../../../ROADMAP.md).

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

## Phase 12 Limits

The DoReMi Palette app integration is visual only. Audio playback, AVFoundation,
MIDI, AudioEngine, persistent document libraries, and advanced iPhone-specific
polish are outside Phase 12.
