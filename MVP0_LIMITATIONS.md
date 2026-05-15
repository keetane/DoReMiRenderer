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
- Basic tie/slur curves, simple beam grouping, and basic triplet brackets are
  available at MVP quality after Phase S6. Ornaments, grace-note
  engraving/playback, transposition application, advanced beams, cross-staff
  beam/stem notation, nested tuplets, and voice collision avoidance remain
  diagnostic-only or limited metadata.

## Layout And Rendering

- Publishing-quality engraving is not implemented.
- Basic note-value drawing is implemented for whole, half, quarter, eighth,
  dotted notes, and common rests. These are MVP shapes intended to make rhythm
  differences visible, not final engraving glyphs.
- Stem direction is MVP-only: single-voice notes below the middle staff line use
  upward stems, and notes on or above the middle staff line use downward stems.
  Chord tones in the same part/measure/staff/voice/onset now share one
  direction based on the chord's average staff position. Full one-stem chord
  engraving, multi-voice stem direction, and collision avoidance remain future
  work.
- Basic clef, time signature, standard barline, and repeat barline drawing is
  implemented from layout elements. Bravura SMuFL glyphs now improve clefs,
  rests, accidentals, repeat dots, time-signature digits, noteheads, and flags,
  with SDK-internal category sizing for iPad readability. The current tuning
  enlarges common noteheads for learning readability, shortens stems, uses
  direction-specific flag glyphs anchored near stem ends, pulls note accidentals
  closer to noteheads, and balances rest sizes, but placement and spacing remain
  MVP quality.
- Bravura 1.392 is bundled as a Swift Package resource under the SIL Open Font
  License. `SMUFL_INTEGRATION_PLAN.md` records the S1-S5 implementation and the
  remaining S6 work while keeping `ScoreLayout` as the coordinate source.
- `notation_coverage_grand_staff.musicxml` and
  `NOTATION_SUPPORT_MATRIX.md` document which common symbols are supported,
  partial, diagnostic-only, or unsupported at the parser/layout/renderer/app
  layers.
- Ties are parsed, affect playback continuation, keep weak continuation
  highlighting, and render same-system MVP curves. Complex tie chains and
  system-crossing tie engraving remain limited.
- Basic same-system slurs and basic 3:2 triplet brackets render at MVP quality.
  Dynamic text engraving, first/second endings, ornaments, grace-note
  rendering, advanced beam grouping, nested tuplets, and transposition-aware
  display remain diagnostic-only or unsupported.
- Complex multi-voice collision avoidance is not implemented; Phase 11F emits
  layout diagnostics for basic collision cases.
- A4-width system wrapping is available for display and the Print MVP, but full
  physical page pagination, page headers/footers, and advanced page breaking
  are not implemented.
- Beam grouping is minimal: safe adjacent flagged notes in the same
  measure/staff/voice can render a Core Graphics beam from stem tip to stem tip,
  isolated eighth notes use SMuFL flags, and mixed eighth/sixteenth groups have
  minimal secondary beam segments. Advanced beam slope/grouping remains a future
  engraving task.
- Ties, slurs, beams, stems, staff lines, ledgers, highlights, and simple
  barlines remain Core Graphics path-based after SMuFL S1-S5. SMuFL is used for
  glyph shapes, not for replacing layout or hit testing.
- Snapshot rendering tests cover basic MVP0 cases only: melody, grand staff,
  chord/rest, accidentals, ledger lines, lyrics/fingering, key signatures,
  current-note highlight, rhythm values, and note/staff color combinations.
- Snapshot tests do not guarantee full MusicXML display quality or
  publishing-quality engraving.
- Renderer output is intended for MVP0 ID, coordinate, and color stability, not final engraving quality.

## Interaction

- Basic zoom and scroll coordinate transforms are implemented for
  `ScoreCanvasView`.
- Basic current-note scroll follow is implemented for playback stepping,
  Practice Mode stepping, playback cursor updates, and tap selection by using
  `ScoreLayout.noteByID` and note anchors derived from layout coordinates.
- Scroll follow avoids recentering every nearby note; it scrolls when the next
  current note leaves the measured viewport margin. It uses edge anchors to
  avoid forcing every follow request back to the center. Advanced user-scroll
  arbitration and precise content-offset synchronization remain future work.
- Scrollable score padding is applied in the Canvas coordinate system so the
  top and bottom edge of the visible score have room for stems, flags, ledger
  lines, and notation symbols without shifting SDK layout coordinates.
- Layout canvas bounds include generated element frames plus safe padding so
  high/low notes, stems, flags, rests, clefs, and ledger lines are not clipped
  in normal MVP samples. Collision-aware engraving and complex multi-system
  bounds remain future work.
- Pinch zoom, inertial scroll tuning, horizontal page navigation, and advanced
  automatic viewport management are not implemented.
- Complex selection state management is not implemented.
- Multiple selection, drag gestures, and annotation workflows are not implemented.
- `ScoreCanvasView.onTap` is the primary MVP0 interaction API.
- `ScoreInteractionHandler` is reserved for future richer interaction handling.

## Playback

- Playback events are generated and Phase 15 adds app-side MVP audio playback.
- AVFoundation is used only in the DoReMi Palette app, not in
  DoReMiRendererKit.
- The Phase 15 audio engine uses generated simple tones, not a high-quality
  instrument.
- Tempo metadata and manual tempo selection can affect app playback timing, but
  precision scheduling and latency optimization are not implemented.
- Generated tones use a minimum audible duration for short pitched events while
  keeping event scheduling duration unchanged. Real audio timing still needs
  user-side listening QA on Simulator or device.
- Mixed visual events can contain tied continuations and new attack pitches; the
  app plays the `midiPitches` attack list and does not sound continuation-only
  events.
- Phase S7 expands simple forward/backward repeat playback sections for two
  passes in the `PlaybackSequence`. Phase S8 adds a first/second ending MVP for
  one clear repeat section and a limited D.C. al Fine jump-only expansion.
  Phase S9 renders same-system first/second ending brackets and numbers. Phase
  S10 adds jump-only D.S. al Fine, D.C. al Coda, and D.S. al Coda expansion,
  plus simple repeat counts up to four passes. The score and layout are not
  duplicated. Third endings, nested repeats, ambiguous endings, mixed
  repeat/jump structures, multiple Segno/Coda markers, complex jumps, and
  system-crossing ending brackets remain unsupported or diagnostic-only.
  Expansion has explicit loop-prevention limits and falls back with diagnostics
  rather than risking infinite playback.
- Tie continuations are identified and DoReMi Palette visually distinguishes
  newly sounding attacks from tied continuations in score and keyboard
  highlights. Full tie-chain duration merging and tie-curve engraving are not
  implemented.
- Background audio, MIDI, external instruments, high-quality samples, and audio
  recording are not implemented.

## DoReMi Palette App

- Phase 12 app integration is iPad-first MVP functionality, not final product UI.
- The bundled sample and file import use the SDK facade; imported private files
  are not stored by the repository.
- The piano keyboard is visual only and uses a limited MVP display range.
- File import supports `.musicxml`, `.xml`, and `.mxl`; persistent document
  library management and cloud sync are not implemented.
- Diagnostics are shown in Japanese, but full localization is not implemented.
- MVP generated-tone audio playback is supported in the app. MIDI, background
  audio, high-quality instruments, and advanced playback interpretation remain
  unsupported.
- iPhone builds and has minimum manual QA coverage, but iPad remains the
  primary target and the iPhone UI is not final.

## Phase 13+ App Roadmap Status

The app-execution roadmap for Phase 13 and later is tracked in
[ROADMAP.md](ROADMAP.md). Phase 13 through Phase 16 now have MVP
implementations:

- Phase 13 app QA / import verification / iPad and iPhone minimum checks
- Phase 14 Library / Recent files MVP
- Phase 15 generated-tone audio playback MVP
- Phase 16 Practice Mode MVP

Areas that remain intentionally incomplete in the current MVP are:

- broader iPhone polish beyond minimum viability
- real-device iPad runtime QA and TestFlight preparation
- user-side audible confirmation on real devices
- provider-dependent file bookmark recovery beyond the current MVP
- advanced notation, SMuFL glyph rendering, and publishing-quality engraving

Phase 17A has confirmed physical iPad discovery and Debug device build for
`iPad Pro 2nd` on iPadOS `26.4.2`. Codex-side install / launch is currently
blocked by a local CoreDeviceService timeout, so real-device launch, audio,
file import, persistence, and runtime interaction checks remain pending until
the app is run from Xcode or CoreDevice is recovered.

Phase 13 adds import fixtures, app import-path tests, keyboard/settings/
diagnostics regression tests, and minimum iPhone manual checks. Real user
document workflows through Files remain partly manual, and the app still does
not provide the finished persistent-library experience.

Phase 14 adds an app-side Library / Recent files MVP:

- bundled sample and imported score metadata can be represented separately
- successful imports add or update recent imported-file metadata
- recent metadata is saved as local JSON
- a Library sheet lists bundled samples and recent imported files
- recent items can be reopened or removed
- missing files show a recovery message instead of crashing
- diagnostics summary, last current note ID, and zoom scale can be retained
- raw MusicXML / MXL contents are not persisted in app settings or library JSON

The following remain limitations after Phase 14:

- iCloud sync and cloud library features are not implemented
- security-scoped bookmark handling is minimal and provider-dependent
- missing-file recovery asks the user to reselect or remove the item; automatic
  repair is not implemented
- advanced library organization, thumbnails, search, and editing are not
  implemented
- broader real-device persistence QA is still pending
- audio behavior should still be manually verified on real devices because
  Simulator audio availability can vary

## Phase 16.5 Stabilization Limits

Phase 16.5 hardens the notation/playback/scroll foundation before Phase 17, but
it is still an MVP stabilization pass:

- Generated-tone audio is covered by mock and Simulator tests, but real-device
  audibility and latency still need user-side QA.
- Scroll follow is designed to keep current notation visible without blocking
  manual scrolling; advanced inertia tuning and user-scroll arbitration remain
  future work.
- Layout bounds now include MVP rendered elements and positive-origin
  compensation, but complex collision-aware engraving is still unsupported.
- `Notation Coverage Sample` is a QA fixture, not proof of full MusicXML
  compatibility.
- Tie continuation highlighting is available, and same-system tie/slur curves
  now render at MVP quality. System-crossing curves and collision-aware curve
  placement remain future notation work.

## Legal And Packaging

- External SDK packaging is not implemented.
- DocC documentation is a minimal skeleton and not a complete API reference.
- Legal and asset records are provided as project hygiene documents, not as legal advice.

## Phase 16 Practice Mode Limits

Practice Mode MVP is available, but it is intentionally small:

- No automatic scoring.
- No microphone input analysis.
- No MIDI keyboard input.
- No AI feedback or advanced learning analytics.
- No account sync.
- No advanced practice history beyond current app session state.
- Note names and solfege use written pitch; transposition-aware display remains
  future work.
- Chord practice is event-based and not split into individual chord tones.
- Rest practice displays `休符` and does not highlight a keyboard key.

## Note Gate / Articulation Limits

`noteGateRatio` shortens generated tone playback only. It does not change score
notation duration, layout, hit testing, `PlaybackEvent`, or `NoteID` identity.
The current implementation is a fixed MVP articulation gap for generated tones,
with a small minimum audible duration for very short pitched events. Rests and
tie continuations still do not trigger new audio.
Full legato, staccato, accent, slur-aware articulation, and high-quality human
performance interpretation remain unsupported.

## Tie Continuation Display Limits

The app can show a tied continuation with a weaker highlight so users can tell
why a visually current note does not sound again. This is a display aid, not
full tie engraving. System-crossing tie/slur arcs, collision-aware tie
placement, and advanced tie-chain interpretation remain future notation work.
