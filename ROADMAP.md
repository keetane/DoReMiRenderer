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

- Physical device discovery is working for `iPad Pro 2nd` on iPadOS `26.4.2`
  with device ID `00008027-001905583CC3802E`.
- The DoReMi Palette Debug device build succeeds for that iPad destination.
- Codex-side `devicectl` install / launch is currently blocked by a local
  CoreDeviceService initialization timeout, so physical runtime QA is not yet
  complete.
- Phase 17B TestFlight preparation should not start until the app has been
  installed/launched on the real iPad and the Phase 17A checklist has been
  completed.

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

## SMuFL Symbol Rendering Plan

The next notation-quality track is SMuFL-based symbol rendering, documented in
[SMUFL_INTEGRATION_PLAN.md](SMUFL_INTEGRATION_PLAN.md). The goal is to improve
the visual shape of common music symbols without handing layout, MusicXML
interpretation, IDs, hit testing, colors, or playback to an external renderer.
`ScoreLayout` remains the only coordinate source, and `ScorePainter` must still
consume layout elements rather than MusicXML source text.

Phase S1: SMuFL integration preparation

- Select the first font candidate, currently Bravura.
- Confirm license, redistribution, bundle placement, and fallback policy.
- Design the internal glyph map and snapshot update rules.

Phase S2: SMuFL font registration

- Add and register the chosen font in the app/example bundles.
- Verify Canvas/Core Text access and fallback behavior.
- Record asset and third-party notices.

Phase S3: Clef / accidental / rest glyph rendering

- Move treble clef, bass clef, accidentals, and common rests to SMuFL glyphs.
- Preserve layout-derived anchors and color behavior.

Phase S4: Repeat / dynamics / time signature glyph rendering

- Improve repeat dots, dynamic symbols, and time signature digits.
- Keep barline and spacing responsibility in layout/rendering code.

Phase S5: Notehead / flag glyph rendering

- Improve whole, half, quarter, eighth noteheads and flags.
- Preserve `NoteID`, `ScoreElementID`, hit-test frames, and note colors.

Phase S6: Tie / slur / beam refinement

- Refine Core Graphics curves and paths that are better drawn geometrically:
  ties, slurs, beams, stems, and minimal collision details.

The `notation_coverage_grand_staff.musicxml` and `rhythm_values_sample.musicxml`
samples are the primary before/after QA fixtures for this track. Snapshot
baseline updates are expected during implementation phases, but only after
reviewing diffs as intentional symbol-quality improvements.
