# MVP0 Limitations

This document records the known limitations of DoReMiRendererKit after Phase 0 through Phase 11F.

## MusicXML Scope

- MusicXML support is still partial, but Phase 11F adds basic lyrics,
  fingering, key signatures, tempo metadata, repeat metadata, and targeted
  diagnostics for common complex notation.
- MXL archives are supported only for the standard `META-INF/container.xml`
  rootfile flow.
- Advanced archive layouts, encrypted archives, and non-file root entries are not supported.
- `score-timewise` is not supported and should produce diagnostics according to `UnsupportedFeaturePolicy`.
- Unsupported MusicXML elements are reported through diagnostics where the parser recognizes them as unsupported.
- Tuplet brackets, slurs, ornaments, grace-note engraving/playback,
  transposition application, advanced beams, cross-staff beam/stem notation,
  and voice collision avoidance are diagnostic-only or minimal metadata in
  Phase 11F.

## Layout And Rendering

- Publishing-quality engraving is not implemented.
- Complex multi-voice collision avoidance is not implemented; Phase 11F emits
  layout diagnostics for basic collision cases.
- Page breaking and advanced system layout are not implemented.
- Snapshot rendering tests cover basic MVP0 cases only: melody, grand staff,
  chord/rest, accidentals, ledger lines, lyrics/fingering, key signatures,
  current-note highlight, and note/staff color combinations.
- Snapshot tests do not guarantee full MusicXML display quality or
  publishing-quality engraving.
- Renderer output is intended for MVP0 ID, coordinate, and color stability, not final engraving quality.

## Interaction

- Basic zoom and scroll coordinate transforms are implemented for
  `ScoreCanvasView`.
- Basic current-note scroll follow is implemented for playback stepping and tap
  selection by using `ScoreLayout.noteByID` and `ScoreViewportTransform`.
- Pinch zoom, inertial scroll tuning, horizontal page navigation, and advanced
  automatic viewport management are not implemented.
- Complex selection state management is not implemented.
- Multiple selection, drag gestures, and annotation workflows are not implemented.
- `ScoreCanvasView.onTap` is the primary MVP0 interaction API.
- `ScoreInteractionHandler` is reserved for future richer interaction handling.

## Playback

- Playback events are generated, but audio playback is not implemented.
- AVFoundation, MIDI, and realtime playback are not used.
- Tempo metadata is parsed, but tempo is not used for actual sound output.
- Repeat barlines are parsed as metadata, but repeat playback expansion is not implemented.
- Tie continuations are identified, but full tie-chain duration merging is not implemented.

## DoReMi Palette App

- Phase 12 app integration is iPad-first MVP functionality, not final product UI.
- The bundled sample and file import use the SDK facade; imported private files
  are not stored by the repository.
- The piano keyboard is visual only and uses a limited MVP display range.
- File import supports `.musicxml`, `.xml`, and `.mxl`; persistent document
  library management and cloud sync are not implemented.
- Diagnostics are shown in Japanese, but full localization is not implemented.
- Audio playback, AVFoundation, MIDI, and AudioEngine remain unsupported.
- iPhone launches, but iPad is the primary QA target.

## Phase 13+ Planned Improvements

The app-execution roadmap for Phase 13 and later is tracked in
[ROADMAP.md](ROADMAP.md). Planned areas that remain intentionally incomplete in
the current MVP are:

- broader iPhone polish and minimum-layout QA
- stronger real-file import verification
- library and recent-files persistence
- audio playback
- practice mode
- real-device iPad validation and TestFlight preparation

## Legal And Packaging

- External SDK packaging is not implemented.
- DocC documentation is a minimal skeleton and not a complete API reference.
- Legal and asset records are provided as project hygiene documents, not as legal advice.
