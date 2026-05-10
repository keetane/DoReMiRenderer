# API Stability

DoReMiRendererKit is currently `0.1.0-mvp0` and experimental. Source and binary
compatibility are not guaranteed before `1.0`.

## Recommended Entry Points

External consumers should prefer the facade and view-level APIs:

- `DoReMiRenderer`
- `RendererConfiguration`
- `ScoreInput`
- `ParseResult`
- `ScoreDocument`
- `LayoutOptions`
- `ScoreLayout`
- `ScoreCanvasView`
- `ScoreStyle`
- `ScoreColor`
- `ScaleColorPalette`
- `NoteColorStyle`
- `StaffLineColorStyle`
- `ColorContext`
- `ScoreColorResolver`
- `HitTestResult`
- `PlaybackOptions`
- `PlaybackEvent`
- `PlaybackMetadata`
- `ScoreViewportTransform`
- `ScoreScrollFollower`
- `ScoreScrollTarget`

The facade keeps parsing, layout, and playback sequence generation in one
stable-looking place while the lower-level implementation remains free to evolve.

## Phase 9 Public API Audit Notes

Phase 9 narrowed the public API toward facade-first external use. These changes
are breaking for direct use of implementation types, which is acceptable for the
experimental `0.x` line.

Moved from public to internal:

- `MusicXMLParser`
- `MusicXMLParserError`
- `MXLLoaderError`
- `ScoreLayoutEngine`
- `ScorePainter`
- `ScoreDrawingContext`
- `CoreGraphicsScoreDrawingContext`
- `PlaybackSequenceBuilder`
- `ScoreInteractionHandler`
- `ScoreColor.cgColor`

Restricted to internal construction while keeping public read access:

- `ScoreLayout`
- `ScoreLayoutResult`
- `SystemLayout`
- `StaffLayout`
- `MeasureLayout`
- `NoteLayout`
- `ElementLayout`
- `StaffLineLayout`
- `LedgerLineLayout`
- `HitTestResult`
- `PlaybackEvent`

These types remain public where consumers need to inspect parser, layout, hit
test, rendering, or playback outputs. Their direct initializers are hidden
because external apps should receive them from `DoReMiRenderer`, `ScoreLayout`,
or `ScoreCanvasView`, not synthesize renderer internals.

Public by design for MVP0:

- Domain identifiers and read models such as `NoteID`, `ScoreElementID`,
  `MeasureID`, `StaffID`, `VoiceID`, `ScoreDocument`, `ScorePart`, `Measure`,
  and `ScoreNote`.
- Music values such as `MusicalTime`, `Pitch`, `PitchStep`, `PitchClass`,
  `Clef`, `ClefKind`, `KeySignature`, and `TimeSignature`.
- Diagnostics and policies such as `ParseResult`, `ScoreLayoutResult`,
  `RendererDiagnostic`, `DiagnosticSeverity`, `MusicXMLLocation`, and
  `UnsupportedFeaturePolicy`.
- Styling APIs such as `ScoreStyle`, `ScoreColor`, `ScaleColorPalette`,
  `ColorPolicy`, `ScoreSelection`, visual style records, color-style enums,
  color-rule protocols, and `ScoreColorResolver`.
- Layout output records because hit testing, custom overlays, and app-side
  inspection need stable IDs and coordinates.

## Areas To Stabilize Before 1.0

- Facade parse, layout, and playback event methods.
- Domain identifiers and deterministic ID behavior.
- `ScoreDocument` read model required by clients.
- `ScoreLayout` coordinate and lookup semantics.
- `ScoreCanvasView` construction and MVP interaction closure.
- Viewport transform and current-note scroll target semantics.
- Styling and color resolution contracts.
- Diagnostics categories and unsupported-feature behavior.

## Areas That Should Remain Internal

- ZIP archive extraction implementation details.
- XML delegate and parser cursor state.
- Layout spacing heuristics and intermediate metrics.
- Renderer command plumbing that is not needed by external consumers.
- Direct parser, layout engine, painter, and playback builder implementations.
- Example app state management.
- DoReMi Palette app state, keyboard view, file importer, diagnostics UI, and
  settings persistence.
- Test fixture generation helpers.

## App Feedback Loop

Phase 13 and later treat the DoReMi Palette app as the practical integration
surface. If the app exposes an SDK gap, the preferred fix is to extend or adjust
the SDK read model or facade in a minimal way rather than duplicating parsing,
layout, or rendering logic in the app.

The app should not be forced to reparse MusicXML, regenerate `NoteID`, or
recompute `ScoreLayout` coordinates just to cover an SDK omission.

## SMuFL And API Stability

The planned SMuFL rendering track should not require app-facing API expansion.
SMuFL glyph selection, font fallback, and glyph anchoring should remain internal
renderer/layout concerns unless an external consumer needs additional read-only
inspection data.

Before `1.0`, the SDK may adjust internal layout element metadata to support
better glyph rendering. Those changes should preserve the public facade,
`ScoreLayout` coordinate semantics, stable IDs, hit-test behavior, color
resolution contracts, and playback event identity.
