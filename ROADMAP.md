# Roadmap

This document records the Phase 13+ app-execution roadmap for DoReMiRendererKit
and the DoReMi Palette app.

## Current Position

- `DoReMiRendererKit` has reached the Phase 11F internal-SDK milestone: core
  parsing, layout, rendering, styling, interaction, playback metadata, and
  diagnostics are in place.
- The DoReMi Palette app was integrated in Phase 12.
- From this point forward, the work is no longer "SDK first, app later" in
  isolation. The flow is: stabilize the SDK core, build the app on top of it,
  and feed back any missing capability into the SDK when real app usage exposes
  a gap.

## Phase 13: App QA / Import Verification / UI Tuning

Purpose:

- Bring the DoReMi Palette app closer to day-to-day practical use.
- Strengthen iPad Simulator QA.
- Verify real `.musicxml`, `.xml`, and `.mxl` imports.
- Confirm the app does not catastrophically fail on iPhone.
- Validate the practical value of keyboard, diagnostics, settings, zoom, and
  scroll-follow behavior.

Focus:

- iPad Simulator QA
- iPhone minimum layout check
- file import verification
- app QA checklist
- app integration tests
- keyboard QA
- diagnostics UI QA
- settings persistence QA
- UI polish

Non-goals:

- Audio playback
- AVFoundation / MIDI
- library persistence
- full iPhone optimization
- large-scale UI redesign

Completion criteria:

- Main interactions are confirmed in the iPad Simulator.
- Import success and failure cases are confirmed.
- iPhone launches without total layout collapse.
- App tests pass.
- SDK tests and snapshot tests continue to pass.
- A QA checklist is updated and maintained.

## Phase 14: Library / Recent Files / File Persistence

Purpose:

- Make the DoReMi Palette app practical for repeated daily use.
- Help users manage imported scores.

Focus:

- recently opened files
- file name display
- import history
- security-scoped bookmarks
- sample score list
- local library model
- file metadata
- import error history
- reload

Policy:

- This is an app responsibility.
- The SDK does not own file management.
- The SDK receives MusicXML / MXL data and returns parse, layout, and playback
  outputs.
- App code must continue to use the `DoReMiRenderer` facade and must not
  reparse MusicXML, regenerate `NoteID`, or recalculate score coordinates.
- Private file contents are not saved to `UserDefaults` or repository fixtures;
  only library metadata is persisted locally.
- Private user files stay out of the repository.
- iCloud / cloud sync can come later.

Phase 14 front half:

- Add the app-side library/recent metadata model.
- Represent bundled samples and imported files as distinct source types.
- Persist recent imported-file metadata in local JSON.
- Update the library entry when a duplicate file is imported.
- Record diagnostic summaries, last selected note ID, and zoom scale where
  available.
- Leave full recent-files UI, complete security-scoped bookmark restore, and
  missing-file UI to the Phase 14 back half.

Completion criteria:

- Imported scores can appear in a recent-files view.
- Imported references survive app relaunch.
- Security-scoped resources are handled safely.
- Import failure does not corrupt the existing library.
- Sample scores and user scores are distinguishable.

Non-goals:

- Cloud sync
- score editing
- music sales
- external storage synchronization

## Phase 15: Audio Playback

Purpose:

- Use `PlaybackEvent` to add audio that stays synchronized with score
  highlighting and keyboard highlighting.

Focus:

- play / stop
- tempo application
- `currentNoteID` synchronization
- keyboard highlight synchronization
- playback cursor
- latency checks
- repeat handling limits
- mute / volume
- simple instrument sound

Policy:

- This is the phase to evaluate AVFoundation / AVAudioEngine /
  AVAudioUnitSampler.
- Audio playback starts as an app feature.
- Only minimal playback-metadata improvements should be pushed back into the
  SDK.
- Playback order and `NoteID` mapping must not change.
- Even if sound is basic, highlight and step correctness come first.

Completion criteria:

- Play and stop work.
- `currentNoteID` advances in sync with playback.
- Keyboard highlighting follows playback.
- Tempo metadata is reflected at a minimum level.
- Unsupported repeats and tuplets are treated via diagnostics or limitations.
- Turning audio on or off does not alter score layout.

Non-goals:

- High-end sound libraries
- DAW-like playback
- full MIDI sequencer behavior
- complete repeat expansion
- low-latency instrument-performance quality

Phase 15 implementation note:

- MVP generated-tone playback is implemented app-side in DoReMi Palette.
- AVFoundation is not added to DoReMiRendererKit.
- Chords, rests, tie continuations, tempo selection, score highlight, keyboard
  highlight, and scroll follow are handled through existing `PlaybackEvent` and
  app state.
- High-quality instruments, background audio, full repeat expansion, exact
  complex-tuplet duration, and transposition-aware playback remain future work.

## Phase 16: Practice Mode

Purpose:

- Create a learning experience that feels specific to DoReMi Palette.

Focus:

- one-note-at-a-time practice
- one-hand practice
- note-name display
- color-rule switching
- staff-color switching
- keyboard linkage
- weak-note tracking
- practice history
- visualizing notes that are often missed
- child-friendly display mode

Policy:

- Practice mode is an app responsibility.
- The SDK may be expanded only if the app needs additional read access to
  `NoteID`, pitch, onset, staff, voice, or `PlaybackEvent` data.
- Color logic remains a `ColorRule` concern.
- Renderer code must not grow practice-specific logic.
- App state owns practice progression.

Completion criteria:

- One-note-at-a-time practice works.
- `currentNoteID` and keyboard stay linked.
- Color rules can be switched.
- Practice mode on/off does not break layout.
- Minimal practice history can be stored.

Non-goals:

- AI scoring
- microphone input analysis
- MIDI keyboard input
- advanced learning analytics
- account sync

## Phase 16.5: Notation / Playback Stabilization

Purpose:

- Stabilize notation display, playback timing, audio triggering, scroll follow,
  and Practice/Playback coexistence before real-device and TestFlight work.
- Use `Rhythm Values Sample` and `Notation Coverage Sample` as repeatable QA
  fixtures for user-visible regressions.

Focus:

- basic note-value, rest, dot, flag, clef, accidental, key/time, repeat, and
  continuation-highlight visibility
- layout bounds so high/low notes, stems, flags, ledger lines, rests, clefs,
  and repeats are not clipped
- current-note scroll follow for playback, step, practice, and tap selection
- generated-tone reliability for rests, tie continuations, mixed events,
  chords, repeated pitches, tempo changes, and short values
- Practice Mode and PlaybackRuntime index/state synchronization
- documentation alignment for supported, partial, diagnostic-only, and
  unsupported notation

Completion criteria:

- `swift test`, Palette app build/tests, SDK snapshot tests, license check, and
  DocC build pass.
- Rhythm Values Sample shows distinguishable whole/half/quarter/eighth notes,
  rests, dots, repeated notes, and stable playback timing.
- Notation Coverage Sample exposes the current symbol support state without
  app-level MusicXML reparsing or renderer-side source interpretation.
- Scroll follow does not block manual scrolling, does not snap every nearby
  event back to center, and resumes after rests/offscreen notes.
- Practice step movement and normal playback use the same event index when
  switching modes.
- Remaining limits are recorded in `MVP0_LIMITATIONS.md`,
  `NOTATION_SUPPORT_MATRIX.md`, and `APP_QA_CHECKLIST.md`.

Non-goals:

- SMuFL font bundling
- full tie/slur curve engraving
- advanced beam grouping, tuplets, ornaments, endings, or collision avoidance
- TestFlight distribution work

## Phase 17: Real iPad / TestFlight Preparation

Purpose:

- Validate on-device behavior and prepare for TestFlight distribution.

Current Phase 17A status:

- Physical iPad install / launch and manual MVP checks have been completed by
  user-side QA.
- Phase 17B TestFlight readiness is now the active release-preparation gate.
- Phase 17B restores the default launch sample to `DoReMi Palette Sample`,
  leaves all notation/repeat/transpose QA samples available from Library,
  confirms release signing/build settings, and records privacy, license, known
  limitation, and beta-review notes before any App Store Connect upload.

Focus:

- real iPad checks
- memory usage checks
- larger MusicXML files
- file-import permission checks
- app icon
- launch screen
- privacy wording
- App Store Connect preparation
- TestFlight builds
- crash / performance checks
- minimum supported OS checks

Policy:

- Do not rely on Simulator-only validation.
- Verify file import, scroll, keyboard, diagnostics, and settings on a real
  iPad.
- Re-check legal, asset, and third-party notices before external distribution.
- Avoid unnecessary communication and data collection.
- Review privacy manifest or App Store privacy metadata if required.

Completion criteria:

- The app launches on a real iPad.
- MusicXML / MXL import works on-device.
- Main workflows do not crash.
- A TestFlight build can be produced.
- Privacy / license / asset checks are complete.
- Known limitations are visible in the README or app UI.

Non-goals:

- App Store release
- billing
- account features
- cloud sync

## SDK Feedback Loop

If app work reveals a true SDK gap, fix the SDK instead of hiding the problem in
app code.

SDK-side issues include:

- unreadable MusicXML
- misplaced notes
- hit-test drift
- incorrect note or staff colors
- missing playback data
- missing pitch information needed by the keyboard
- repeat / tuplets / transposition requirements that matter in practice
- diagnostics that do not explain a failure
- layout that still needs app-side compensation

App-side issues include:

- screen composition
- file list
- settings
- library
- practice state
- keyboard presentation
- diagnostics presentation
- import history
- lightweight local persistence

Do not solve SDK gaps by:

- reparsing MusicXML in the app
- regenerating `NoteID` in the app
- recomputing `ScoreLayout` coordinates in the app
- guessing renderer coordinates in the app
- publicizing SDK internals just to satisfy app needs

## Recommended Order After Phase 13

1. Phase 14: Library / recent files - complete MVP
2. Phase 15: Audio playback - complete MVP
3. Phase 16: Practice mode - complete MVP
4. Phase 16.5: Notation / playback stabilization
5. Phase 17: Real iPad / TestFlight preparation

If Phase 13 reveals a serious file-import issue, fix it before moving to Phase 14.
If Phase 15 reveals missing playback data, feed the requirement back into the SDK.
If Phase 16 reveals missing `NoteID`, pitch, or staff data, extend the SDK read
model minimally.

### Phase 16 MVP implementation note

Phase 16 implements the first Practice Mode inside the DoReMi Palette app. The
mode is app-owned: it consumes existing `PlaybackEvent`, `NoteID`, and public
layout read data, and does not add practice state to DoReMiRendererKit.

MVP behavior:

- Practice Mode moves one `PlaybackEvent` at a time through explicit user input.
- Automatic playback remains separate and tempo-driven.
- Enabling Practice Mode stops automatic playback and silences app audio.
- Pressing Play while Practice Mode is enabled leaves Practice Mode and starts
  normal playback.
- Chord events are treated as one practice step; the score highlights the first
  note and the keyboard can highlight all pitches in the event.
- Rest steps display as `休符` and do not highlight a keyboard key.
- Note-name and solfege display use written pitch in MVP.
- Palette selection is an app setting and must not change `ScoreLayout`,
  `NoteID`, or `PlaybackEvent` identity.

Phase 16 still does not include scoring, microphone input, MIDI keyboard input,
AI analysis, account sync, or full practice history.

## Notation Coverage / Symbols Hardening

Before Phase 17/TestFlight work, keep a lightweight notation hardening loop in
place:

- use self-authored samples, not private or copyrighted scores, to reproduce
  missing symbols;
- update `NOTATION_SUPPORT_MATRIX.md` when parser, layout, renderer, app-visible,
  or playback behavior changes;
- keep renderer behavior driven only by `ScoreLayout` and domain models;
- prefer diagnostics over silent failure for unsupported symbols;
- feed app-visible notation gaps back into the SDK only when the fix belongs in
  parser/domain/layout/rendering.

Current priorities:

1. Visual tie arcs, distinct from slurs.
2. Slur layout/rendering beyond diagnostic-only support.
3. Final/double barline style retention and rendering.
4. Dynamic and tempo text rendering.
5. Beam grouping and tuplets after basic symbol visibility is stable.

This is intentionally separate from Practice Mode and audio playback. App code
must not infer symbols from raw MusicXML or renderer coordinates.

## SMuFL Symbol Rendering Status

The notation-quality track is SMuFL-based symbol rendering, documented in
[SMUFL_INTEGRATION_PLAN.md](SMUFL_INTEGRATION_PLAN.md). S1-S5 are implemented
with Bravura 1.392 as an SDK resource. The goal is to improve
the visual shape of common music symbols without handing layout, MusicXML
interpretation, IDs, hit testing, colors, or playback to an external renderer.
`ScoreLayout` remains the only coordinate source, and `ScorePainter` must still
consume layout elements rather than MusicXML source text.

Phase S1: SMuFL integration preparation - complete

- Select the first font candidate, currently Bravura.
- Confirm license, redistribution, bundle placement, and fallback policy.
- Design the internal glyph map and snapshot update rules.

Phase S2: SMuFL font registration - complete

- Add and register the chosen font in the app/example bundles.
- Verify Canvas/Core Text access and fallback behavior.
- Record asset and third-party notices.

Phase S3: Clef / accidental / rest glyph rendering - complete

- Move treble clef, bass clef, accidentals, and common rests to SMuFL glyphs.
- Preserve layout-derived anchors and color behavior.

Phase S4: Repeat / dynamics / time signature glyph rendering - partial

- Improve repeat dots and time signature digits.
- Dynamic symbols remain diagnostic-only unless represented by existing text
  annotations.
- Keep barline and spacing responsibility in layout/rendering code.

Phase S5: Notehead / flag glyph rendering - complete

- Improve whole, half, quarter, eighth noteheads and flags.
- Preserve `NoteID`, `ScoreElementID`, hit-test frames, and note colors.

Phase S6: Tie / slur / beam refinement - complete

- Refine Core Graphics curves and paths that are better drawn geometrically:
  ties, slurs, beams, stems, and minimal collision details.

Phase S7: Repeat Playback Expansion MVP - complete

- Expand simple forward/backward repeat playback sections for two passes in
  `PlaybackSequenceBuilder`.
- Keep `ScoreDocument`, `ScoreLayout`, `NoteID`, and renderer state unchanged.
- Practice Mode and app playback consume the same expanded event sequence.

Phase S8: Advanced Repeat / Playback Hardening MVP - complete

- Expand one clear first/second ending repeat section in `PlaybackSequenceBuilder`.
- Parse repeat ending metadata and common jump-marker words into playback
  metadata without changing score layout or renderer responsibilities.
- Support basic D.C. al Fine only for jump-only scores in S8; later S10 expands
  the jump-only D.S. al Fine / al Coda paths.
- Keep Practice Mode, Previous / Next, current-note highlighting, keyboard
  highlighting, and scroll follow on the expanded playback sequence.

Phase S9: Advanced Repeat Visuals / Jump Marker Hardening MVP - complete

- Render first/second ending brackets and ending numbers from layout elements.
- Keep S8 repeat-ending playback expansion unchanged while making the visual
  ending brackets visible in the app and snapshots.
- Add an S9 repeat visuals sample for Library/default QA and diagnostic-only
  jump-marker checks.
- Continue to leave third endings, nested repeats, complex jumps, and
  system-crossing ending brackets as documented limitations; S10 handles the
  limited jump-only D.S./Coda playback paths.

Phase S10: Complete Repeat Symbols Before TestFlight - complete

- Prioritize remaining repeat and jump playback before TestFlight so the app
  fails with diagnostics instead of silently misplaying common navigation marks.
- Implement supported jump-only cases in `PlaybackSequenceBuilder`: D.S. al
  Fine, D.C. al Coda, and D.S. al Coda, while preserving the existing D.C. al
  Fine path.
- Keep repeat/jump expansion bounded with max repeat passes, max jump counts,
  and max expanded event safeguards.
- Treat repeat count as an MVP feature: use explicit counts up to four passes,
  default missing counts to two, and diagnose invalid/excessive counts.
- Keep third endings, nested repeats, mixed repeat+jump structures, multiple
  Segno/Coda markers, and ambiguous jumps diagnostic-backed unless a safe
  limited expansion exists.
- Add focused S10 samples for D.C. al Fine, D.S. al Fine, D.C. al Coda, D.S. al
  Coda, and diagnostic repeat/jump cases.
- TestFlight entry criteria: supported S10 samples load, expected expanded
  orders are verified, unsupported structures emit diagnostics, app playback and
  Practice Mode continue to consume only expanded `PlaybackEvent` sequences, and
  non-repeat samples remain unchanged.

Piano Transpose MVP - complete

- Add an app-side `transposeSemitones` setting for piano practice, persisted in
  `AppStorage` and clamped to `-12...+12`.
- Transpose generated playback and keyboard highlights at the app runtime
  layer without changing `ScoreDocument`, `ScoreLayout`, `NoteID`, or
  `PlaybackEvent`.
- Show written note/key and sounding note/key when transpose is nonzero.
- Keep score-display transposition, key-signature redraw, MusicXML
  `<transpose>`, and transposing-instrument concert-pitch handling as future
  work.

Phase T2: Score Display Transpose / MusicXML Transpose Hardening - complete

- Make display transpose the default app behavior and replace semitone +/- UI
  with a key picker (`C`, `C#`, `D`, ...).
- Rebuild `ScoreLayout` from the original `ScoreDocument` with display-only
  transpose options. The original score, MusicXML file,
  `NoteID`, `ScoreElementID`, and playback events are not rewritten.
- Recalculate display pitch positions, MVP key signatures, note colors, and
  simple accidentals for the transposed score view.
- Keep playback, keyboard highlight, Practice Mode, and repeat/jump expansion
  aligned with the existing sounding transpose setting.
- Parse MusicXML `<transpose>` metadata and report it through diagnostics.
  Automatic transposing-instrument concert-pitch conversion remains a planned
  hardening item rather than a default behavior.
- Add T2 key, accidental, and MusicXML transpose diagnostic samples.

Palette Editor MVP - complete

- Add a DoReMi Palette toolbar palette entry point and sheet-based editor.
- Keep preset palette selection internal and expose persisted 12 pitch-class
  ON/OFF controls with all-on/all-off/reset actions.
- Show generated C2-C6 score and keyboard previews in the sheet so users can see
  the pitch-class color filter before returning to the score.
- Apply disabled pitch classes through app-created `ScoreStyle` color rules and
  keyboard coloring without moving app UI state into the SDK renderer.
- Leave arbitrary RGB/HEX editing, octave-specific enablement, import/export,
  and cloud sync as future palette hardening.

Metronome MVP - complete

- Add a persisted app-side `metronomeEnabled` setting with controls in the main
  playback area and Settings.
- Reuse generated app audio tones for strong and weak clicks without adding
  AVFoundation or scheduling responsibility to DoReMiRendererKit.
- Start clicks with Play when enabled, stop them on Pause / Stop / Reset /
  playback end, and follow the current playback BPM.
- Metronome Advanced MVP adds compound-meter large-beat/subdivision modes for
  `6/8`, `9/8`, and `12/8`, strong/medium/weak accent patterns, Tap Tempo, and
  generated click sound styles.
- Keep Practice Mode as manual stepping; standalone practice metronome,
  arbitrary accent editing, imported click sounds, and sample-accurate
  scheduling remain future hardening.

The `notation_coverage_grand_staff.musicxml` and `rhythm_values_sample.musicxml`
samples are the primary before/after QA fixtures for this track. Snapshot
baseline updates are expected during implementation phases, but only after
reviewing diffs as intentional symbol-quality improvements.
