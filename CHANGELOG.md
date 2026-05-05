# Changelog

## 0.1.0-mvp0 - 2026-05-02

Initial experimental MVP0 release.

This version is intended for integration review and early adopter testing. Public
APIs may change before `1.0`.

### Added

- Swift Package `DoReMiRendererKit`.
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
