# DoReMi Palette App QA Checklist

This checklist tracks Phase 13 app readiness checks for the DoReMi Palette
iOS/iPadOS app.

## Scope

Phase 13 focuses on app QA, import verification, and MVP UI polish. It does not
include audio playback, AVFoundation, MIDI, library persistence, practice mode,
or TestFlight preparation.

## Pass Criteria

- The app launches on the target simulator.
- The bundled sample score is visible.
- Core controls remain reachable.
- File import success and failure paths are covered by tests, and manually
  checked where Simulator interaction allows it.
- Existing SDK tests, app tests, snapshot tests, license check, diagnostics
  command, and DocC build continue to pass.
- Any manual item that cannot be completed has a recorded reason and a test
  fallback.

## iPad Checks

- [x] App launches on iPad Pro 13-inch (M5) Simulator.
- [x] App installs and launches on the connected physical `iPad Pro 2nd`.
- [x] User completed physical-device confirmation after internal TestFlight
  distribution.
- [x] Bundled sample score appears.
- [x] Note color and staff color are visible.
- [x] `Previous` / `Next` controls are reachable.
- [x] Score supports pinch zoom.
- [x] Keyboard can be shown with score still visible.
- [x] Keyboard current-note highlight is visible.
- [x] Diagnostics sheet opens without breaking score display.
- [x] Diagnostics sheet shows score context summary: source name,
  part/measure/note counts, playback event count, layout mode, canvas size,
  and current BPM.
- [x] Settings sheet opens without breaking score display.
- [ ] Manual `.musicxml` import through the Files picker.
- [ ] Manual `.xml` import through the Files picker.
- [ ] Manual `.mxl` import through the Files picker.
- [ ] Manual invalid-file import through the Files picker.

## iPhone Checks

- [x] iPhone 17 Simulator build succeeds.
- [x] App launches on an available iPhone Simulator.
- [x] Bundled sample score appears.
- [x] Controls are not completely off-screen.
- [x] Keyboard control remains reachable.
- [x] Keyboard ON/OFF visual state was rechecked.
- [x] Diagnostics sheet opens.
- [x] Score is visible at default zoom.

## Import Checks

- [x] `.musicxml` fixture loads through the app loader.
- [x] `.xml` fixture loads through the app loader.
- [x] `.mxl` fixture loads through the app loader.
- [x] Invalid MusicXML enters an error state.
- [x] Unsupported extension enters an error state.
- [x] Empty supported import files are rejected before parsing.
- [x] Supported import files larger than 50 MB are rejected before reading /
  parsing.
- [x] Failed import keeps the previously loaded score.
- [x] Successful import resets the playback cursor to the first event.
- [x] Diagnostics are retained or updated after import.

## Diagnostics Checks

- [x] No-diagnostics state has a user-facing Japanese message.
- [x] Warning diagnostics are distinguishable from errors.
- [x] Diagnostic codes are visible.
- [x] Unsupported-feature and repeat diagnostics are mapped to Japanese user messages.
- [x] Import failure shows an error message.
- [x] Invalid and unsupported import failures keep the existing score in app-loader tests.
- [x] Empty and oversized import failures keep the existing score and bundled
  Library metadata in app-loader tests.

## Transpose / Prefix / Accidental Color Checks

- [x] Display transpose can rebuild the score layout without mutating the
  original score or playback events.
- [x] Prefix order is the standard `clef -> key signature -> time signature ->
  notes` while keeping clef/key/time collisions fixed.
- [x] Display-transposed key signatures use the same collision-safe standard
  prefix spacing.
- [x] SDK measure-width normalization keeps first-measure pickup/anacrusis
  bars readable instead of collapsing to a single onset.
- [x] Final incomplete measures keep the same guarded minimum width instead of
  collapsing at the end of a score.
- [x] Non-final wrapped systems distribute leftover width without stretching
  compact beamed short-note groups across the full bar.
- [x] Compact short-note and beamed groups are no longer flush-left inside
  normalized measures; their internal spacing remains compact.
- [x] Fur Elise-style sixteenth passages keep readable visual gaps while staying
  close to their rhythmic onset rather than floating in the measure center.
- [x] Normal measures keep a readable minimum width, and clef/key/time/repeat
  prefixes remain inside the measure width budget.
- [ ] Manual iPad QA: open a pickup/anacrusis score and confirm the first
  measure is not extremely narrow.
- [ ] Manual iPad QA: open a score with a trailing incomplete final measure and
  confirm the final bar remains readable without over-justifying the final
  system.
- [ ] Manual iPad QA: confirm beamed short-note measures remain compact without
  sitting too far left or leaving only right-side whitespace.
- [ ] Manual iPad QA: open Fur Elise - Beginner Piano and confirm the opening
  sixteenth-note flow is readable.
- [x] Note accidental colors match the associated displayed note color when
  Note Color is ON.
- [x] Note accidentals use default ink when Note Color is OFF.
- [x] Key-signature accidentals use pitch-class color when Note Color is ON.

## Keyboard Checks

- [x] Keyboard is visible on iPad.
- [x] Keyboard can be hidden from controls/settings.
- [x] Current note highlights a key.
- [x] C/D/E/F/G/A/B natural pitch mapping is covered by tests.
- [x] Sharp/flat enharmonic mapping follows the MVP MIDI-number model.
- [x] Chords highlight all current event note IDs in MVP.
- [x] Rest, missing-note, and out-of-range behavior are covered by tests.
- [x] Keyboard ON/OFF does not clear the loaded score.

## Settings Persistence Checks

- [x] Note color setting uses `AppStorage`.
- [x] Staff color setting uses `AppStorage`.
- [x] Keyboard visibility uses `AppStorage`.
- [x] Zoom scale uses `AppStorage`.
- [x] Settings keys store and restore values in isolated defaults tests.
- [x] Settings exposes a visible reset action for display/playback preferences
  without deleting imported files or Library contents.
- [x] Note/staff color changes do not change layout or playback identity.
- [x] Zoom scale does not change the layout coordinate hit-test model.
- [x] Pinch zoom uses a continuous `0.8x...3.0x` scale and Settings exposes
  Reset Zoom.
- [x] First-use guide completion uses `AppStorage`.
- [x] Settings includes a replay action for the first-use guide.
- [ ] Full relaunch persistence manual check on physical app lifecycle.

## First-Use Guide Checks

- [x] App tests cover guide step order, next/back bounds, skip/complete state,
  and persisted completion key.
- [ ] Manual iPad QA: fresh install shows the guide after sample load.
- [ ] Manual iPad QA: Settings button guide highlights the toolbar Settings
  button.
- [ ] Manual iPad QA: Coloring guide opens the Settings sheet and highlights
  the color controls.
- [ ] Manual iPad QA: Layout guide remains in the Settings sheet and highlights
  the layout controls.
- [ ] Manual iPad QA: current-note/keyboard guide returns to the main score and
  anchors near the current-note or keyboard area.
- [ ] Manual iPad QA: measure jump anchors to the measure input box.
- [ ] Manual iPad QA: Previous/Next guide anchors to the Next button.
- [ ] Manual iPad QA: Play/Stop and key/transpose guide steps anchor to the
  expected controls.
- [ ] Manual iPad QA: Back / Next / Skip / Done work and completed guides do not
  replay automatically.
- [ ] Manual iPad QA: Settings `使い方ガイドを再表示` restarts the guide.

## Palette Editor Checks

- [x] Toolbar exposes a `パレット` entry point.
- [x] Palette sheet has no visible preset pattern picker and includes
  all-on/all-off/reset actions, 12 pitch-class buttons, C2-C6 score preview,
  and C2-C6 keyboard preview.
- [x] Default pitch-class color state is all ON.
- [x] Pitch-class enabled state persists through `AppStorage`.
- [x] Disabled pitch classes fall back to neutral ink in note color resolution.
- [x] Note Color OFF ignores pitch-class filtering and uses default ink.
- [x] Keyboard preview and highlights use the same pitch-class enabled state.
- [x] Palette filtering does not mutate layout, note IDs, playback events,
  transpose state, repeat expansion, Library, or Diagnostics.

## Metronome MVP Checks

- [x] App exposes a Metronome ON/OFF control in the playback/display control
  area.
- [x] Settings exposes the same Metronome ON/OFF setting.
- [x] Metronome enabled state persists through `AppStorage`.
- [x] Mock runtime tests confirm Play starts clicks only when enabled.
- [x] Mock runtime tests confirm Pause / Stop / Reset / playback end stop the
  metronome path.
- [x] Mock runtime tests confirm strong and weak generated clicks use distinct
  pitches and velocities.
- [x] Mock runtime tests confirm enabling Metronome during playback waits for
  the next beat boundary instead of treating the toggle moment as beat 1.
- [x] Mock runtime tests confirm a 3/4 MusicXML sample clicks
  strong-weak-weak before the next strong beat.
- [x] Mock runtime tests confirm the metronome click plan anchors beat 0 as a
  strong click for every 3/4 and 4/4 measure occurrence, including a
  mid-measure enable case and a pickup-measure regression.
- [x] Mock runtime tests confirm `6/8` defaults to two large beats and can
  switch to six subdivision clicks.
- [x] Mock runtime tests confirm `9/8` and `12/8` large-beat patterns.
- [x] Mock runtime tests confirm Tap Tempo averaging, long-gap reset, and BPM
  clamping.
- [x] Mock runtime tests confirm generated click sound style switching.
- [x] Tempo changes restart playback scheduling and metronome timing without
  changing the current event index.
- [ ] User-side listening QA: confirm `6/8` large-beat and subdivision modes
  feel distinct.
- [ ] User-side listening QA: confirm Tap Tempo and click sound styles are
  comfortable on Simulator or iPad hardware.
- [ ] User-side listening QA: confirm the strong click and weak click are
  audibly distinct on Simulator or iPad hardware.
- [ ] User-side listening QA: confirm clicks remain comfortable with score
  playback audio enabled.

## Measure Navigation Checks

- [x] App tests confirm total measure count is derived from the loaded score.
- [x] App tests confirm the current measure display follows the current
  playback event.
- [x] App tests confirm valid measure jumps update the playback cursor and
  current note state.
- [x] App tests confirm invalid measure numbers are rejected.
- [x] App tests confirm empty measures fall forward to the next available event.
- [x] App tests confirm repeated measures jump to the first expanded playback
  occurrence.
- [x] App tests confirm jumping during playback pauses and silences audio.
- [ ] Manual iPad QA: transport row shows current measure / total measures
  between Previous and Next.
- [ ] Manual iPad QA: inline measure input accepts a target measure.
- [ ] Manual iPad QA: valid input scrolls the score to the requested measure.
- [ ] Manual iPad QA: invalid input shows an error and does not move.
- [ ] Manual iPad QA: Practice Mode and repeat samples update the measure
  display correctly.

## Pinch Zoom Checks

- [x] App tests cover zoom clamping and continuous percent formatting.
- [x] SDK transform tests cover scaled view/layout coordinate conversion.
- [x] SDK scroll-follow tests cover scaled target offsets.
- [ ] Manual iPad QA: pinch in and confirm the score enlarges without losing
  tap selection.
- [ ] Manual iPad QA: pinch out and confirm the score shrinks without clipping
  the current note follow path.
- [ ] Manual iPad QA: Previous / Next and Practice stepping still keep the
  current note visible after pinch zoom.
- [ ] Manual iPad QA: Settings Reset Zoom returns the score to `1.0x`.
- [ ] Manual iPad QA: Sample Reload, opening a different Library sample, and
  importing a file reset the visible score zoom to `1.0x`.
- [ ] Manual iPad QA: the main screen no longer shows the horizontal/A4 layout
  switcher or zoom percentage; those controls remain in Settings.

## Playback Performance Checks

- [x] `ScoreCanvasView` keeps static score rendering separate from playback
  cursor/highlight updates.
- [x] Runtime score rendering uses visible-rect culling and cached CoreText /
  SMuFL text lines.
- [x] Highlight updates use lightweight overlay shapes instead of forcing full
  score redraws.
- [x] Large A4/performance-layout playback avoids all-note geometry work and
  repeated recentering, but still follows when the current note leaves the
  viewport margin.
- [x] Current-note text updates are throttled during playback so audio
  scheduling is not blocked by every UI label update.
- [x] `SimpleToneAudioEngine` caches generated note buffers.
- [x] Full DoReMi Palette App tests passed after the performance hardening
  pass.
- [x] Heavy sample simulator spot checks were recorded for Canon in D, Mozart
  Piano Sonata No. 16, and Fur Elise under
  `/tmp/DoReMiPaletteQA/performance-final/`.
- [x] Critical regression simulator spot checks confirmed upright SMuFL glyphs,
  restored current-note follow, and metronome meter sync evidence under
  `/tmp/DoReMiPaletteQA/critical-regression/`.
- [x] Metronome meter sync critical fix records click-plan evidence under
  `/tmp/DoReMiPaletteQA/metronome-meter-fix/`: 3/4 and 4/4 measures start on
  strong beat 0, 6/8 large-beat/subdivision plans use the expected offsets, and
  mid-playback ON uses the next planned click instead of restarting the cycle.
- [ ] User-side listening QA: confirm on a physical iPad that heavy samples do
  not audibly drift or stutter with the selected audio route.

Palette editor screenshot targets:

- `/tmp/doremipalette_palette_button.png`
- `/tmp/doremipalette_palette_sheet_all_on.png`
- `/tmp/doremipalette_palette_sheet_c_off.png`
- `/tmp/doremipalette_palette_preview_keyboard.png`
- `/tmp/doremipalette_palette_preview_score.png`

## Screenshot Targets

- `/tmp/doremipalette_phase13_part1_ipad_initial.png`
- `/tmp/doremipalette_phase13_part1_ipad_import.png`
- `/tmp/doremipalette_phase13_part1_ipad_error.png` - not captured in retry;
  invalid-file selection still needs fixtures available inside Simulator Files.
- `/tmp/doremipalette_phase13_part1_iphone_initial.png`
- `/tmp/doremipalette_phase13_part1_iphone_diagnostics.png`
- `/tmp/doremipalette_phase13_part1_iphone_keyboard.png`
- `/tmp/doremipalette_phase13_part2_ipad_keyboard_on.png`
- `/tmp/doremipalette_phase13_part2_ipad_keyboard_off.png` - attempted, but
  Simulator UI tap did not toggle the iPad switch in this retry; iPhone visual
  confirmation and app tests cover the OFF path.
- `/tmp/doremipalette_phase13_part2_ipad_diagnostics.png`
- `/tmp/doremipalette_phase13_part2_ipad_settings.png`
- `/tmp/doremipalette_phase13_part2_iphone_keyboard_on.png`
- `/tmp/doremipalette_phase13_part2_iphone_keyboard_off.png`
- `/tmp/doremipalette_phase13_part2_iphone_diagnostics.png`

## Known Limitations

- Files picker selection is still partly manual and depends on files being
  placed in the Simulator Files app.
- Manual invalid-file selection through the iPad Files picker was not completed
  in the retry because the test fixtures were not available from the Simulator
  Files app. The app loader tests cover invalid and unsupported import errors,
  diagnostics updates, and keeping the existing score after a failed import.
- iPhone manual retry confirmed launch, bundled sample visibility, reachable
  controls, diagnostics sheet display, keyboard setting reachability, and
  `1.0x` score visibility.
- Phase 13 part 2 confirmed keyboard visibility/highlight behavior, diagnostics
  presentation, settings persistence keys, and app integration behavior with
  additional app-model tests.
- iPad Keyboard OFF visual confirmation was attempted through Simulator UI
  automation, but the tap did not toggle the switch during this retry. The
  iPhone ON/OFF screenshots and app tests cover the behavior.
- Phase 13 did not implement library persistence or recent files; Phase 14 adds
  the MVP.
- Phase 15 adds MVP generated-tone audio playback.
- iPhone UI is minimum viable only, not final optimization.

## Phase 14 Library / Recent Files Checks

Scope:

- Library / Recent files metadata model
- bundled sample item metadata
- imported score item metadata
- local JSON persistence for metadata only
- import success adding or updating a recent item
- import failure preserving current score and not adding a recent item
- Library / Recent files sheet
- sample reload from Library
- recent imported reload
- remove from recent
- missing-file message
- app relaunch-equivalent metadata restore

Pass criteria:

- [x] Sample and imported items have distinct source types.
- [x] Duplicate imported files update an existing item rather than creating
  another recent entry.
- [x] Corrupt persisted JSON loads as an empty metadata list and does not crash.
- [x] App tests confirm import success adds metadata and resets
  `currentNoteID`.
- [x] App tests confirm import failure leaves the loaded score and library
  metadata unchanged.
- [x] Raw MusicXML / MXL file contents are not persisted.
- [x] Library sheet can show sample and recent imported sections.
- [x] App tests confirm sample items can be opened through the Library path.
- [x] App tests confirm recent reload success opens the score and updates
  metadata.
- [x] App tests confirm recent reload failure keeps the current score.
- [x] App tests confirm nil bookmark/missing file is handled as a recoverable
  error.
- [x] App tests confirm remove from recent updates persisted metadata.

Remaining after Phase 14:

- Full real-device security-scoped bookmark QA.
- Provider-dependent reselect flows for files that cannot be resolved.
- iCloud sync and advanced library organization.
- Simulator screenshots cover the Library/sample-list sheet. Recent imported,
  missing-file, and remove-from-recent behavior are covered by app tests; full
  Files picker walkthrough remains manual QA.

## Remaining For Phase 14 And Later

- Optional full Files picker import walkthrough after fixtures are made
  available inside the Simulator Files app.
- Physical app lifecycle persistence check beyond isolated defaults tests.
- Practice mode.

## Phase 15 Playback Checks

Scope:

- Play / Pause / Stop / Reset
- tempo control
- generated-tone audio startup
- score highlight synchronization
- keyboard highlight synchronization
- rest and tie-continuation behavior
- library and diagnostics regression after playback

Pass criteria:

- [x] App tests cover playback runtime state transitions.
- [x] App tests cover tempo duration calculation.
- [x] App tests cover tempo changes while stopped, paused, playing, and empty.
- [x] App tests cover invalid tempo clamping without invalid note state.
- [x] App tests cover chord playback pitch lists through a mock audio engine.
- [x] App tests cover rest events not calling audio play.
- [x] App tests cover tie continuations not retriggering audio.
- [x] App tests cover repeated same-pitch events producing separate audio play
  calls.
- [x] App tests cover a minimum audible generated-tone duration for very short
  pitched notes.
- [x] App tests cover playback task restart and audio silence during playing
  tempo changes.
- [x] App tests cover audio startup failure without app crash.
- [x] App tests cover playback step changes without mutating layout identity.
- [x] Manual iPad check confirms Play advances the current-note highlight.
- [x] Manual iPad check confirms Pause / Stop / Reset behavior.
- [x] Manual iPad screenshot confirms keyboard highlight during playback.
- [x] Manual iPad screenshot confirms tempo control is reachable.
- [ ] Manual audible generated tone output still needs user-side confirmation.

## Phase 16.5 Stabilization QA

Scope:

- Rhythm Values Sample and Notation Coverage Sample
- notation bounds and clipping
- playback scroll follow
- generated-tone playback reliability
- Practice Mode / PlaybackRuntime coexistence

Pass criteria before Phase 17:

- [x] `swift test` covers SDK layout, rendering, scroll, playback, and
  diagnostics regressions.
- [x] App tests cover Library/Recent, import, Practice Mode, playback runtime,
  noteGateRatio, repeated pitches, mixed tie-continuation attacks, and rest
  scheduling.
- [x] Rhythm Values Sample is listed and loads from the sample catalog.
- [x] Notation Coverage Sample is listed and loads from the sample catalog.
- [x] Layout bounds tests cover high/low notes, stems, flags, rests, clefs,
  ledger lines, and scroll-content padding.
- [x] Current-note follow tests cover visible notes, offscreen notes, rest/nil
  recovery, scale changes, and edge-anchor behavior.
- [x] Playback tests cover pitch events, rests, tie continuations, mixed
  attack/continuation events, chords, repeated pitches, tempo changes, and
  minimum audible duration.
- [x] Practice step movement keeps `PlaybackRuntime` synchronized before
  returning to normal playback.
- [x] User iPad Simulator confirmation reported that scroll follow works after
  the latest follow fixes.
- [x] User iPad Simulator confirmation reported that upper-edge clipping is
  resolved after layout bounds fixes.
- [ ] User-side audible confirmation is still required for generated-tone
  output on real device.

Manual sample checks:

- [ ] Rhythm Values Sample: whole / half / quarter / eighth notes are visually
  distinct.
- [ ] Rhythm Values Sample: rests and dotted notes are visible.
- [ ] Rhythm Values Sample: repeated same pitch sounds as separate notes.
- [ ] Notation Coverage Sample: clef, time/key signature, accidentals, repeats,
  rests, chord, and continuation highlights are visible as MVP notation.
- [ ] Notation Coverage Sample: unsupported tie/slur arcs, dynamics, tempo
  text, tuplets, and advanced beams match `NOTATION_SUPPORT_MATRIX.md`.
- [ ] Playback: Play / Pause / Stop / Reset remain stable.
- [ ] Practice: ON/OFF, Next, Previous, Reset, keyboard highlight, and note-name
  display remain stable.
- [ ] Ode to Joy and Fur Elise diagnostics no longer include direct
  `unsupported.tied`, `unsupported.stem`, `unsupported.bar-style`,
  `unsupported.pedal`, or `tempo.metronomeUnsupported` warnings.
- [ ] Fur Elise repeat barline, explicit stem/beam grouping, and pedal text do
  not visually regress in A4 mode.

Screenshot targets:

- `/tmp/doremipalette_phase16_5_rhythm_values.png`
- `/tmp/doremipalette_phase16_5_notation_coverage.png`
- `/tmp/doremipalette_phase16_5_scroll_follow.png`
- `/tmp/doremipalette_phase16_5_practice.png`
- `/tmp/doremipalette_phase16_5_playback.png`
- [ ] Manual tempo-perception check still needs user-side confirmation.

Screenshot targets:

- `/tmp/doremipalette_phase15_playback_initial.png`
- `/tmp/doremipalette_phase15_playing.png`
- `/tmp/doremipalette_phase15_paused.png`
- `/tmp/doremipalette_phase15_stopped.png`
- `/tmp/doremipalette_phase15_tempo.png`
- `/tmp/doremipalette_phase15_keyboard_highlight.png`

Known limitations:

- Audio quality is simple generated tone only.
- Simulator audio audibility can depend on host settings.
- Background audio, MIDI, external instruments, repeat expansion, precise
  tuplet playback timing, and latency tuning are not Phase 15 goals.

Follow-up QA:

- [x] Layout element bounds are covered by SDK tests.
- [x] Scroll follow uses measured current-note bounds instead of center-only
  heuristics.
- [x] Mixed tie-continuation/new-attack events still send attack pitches to
  audio.
- [ ] User-side audible confirmation remains required for generated tones.
- [ ] Manual smooth-scroll feel should be checked on the target iPad Simulator
  or device.

## Tie Continuation Highlight Checks

Scope:

- attack notes that start a new generated tone
- tie continuation notes that are visually current but do not retrigger audio
- mixed events containing both attack and continuation notes
- score highlight and keyboard highlight consistency

Pass criteria:

- [x] Attack-only events use the normal strong score highlight.
- [x] Continuation-only tie events use the weaker continuation score highlight.
- [x] Mixed events show attack and continuation notes at the same time.
- [x] Keyboard attack pitches use the strong highlight.
- [x] Keyboard continuation pitches use the weaker highlight.
- [x] Attack and continuation overlap on the same pitch prioritizes attack.
- [x] Rest events leave the keyboard unhighlighted.
- [x] Previous / Next and Practice Mode use the same highlight classification.

Manual QA:

- Open a sample with tie continuations.
- Play through a mixed event and confirm the newly sounding note is stronger
  than the tied continuation.
- Step through the same event with Previous / Next.
- In Practice Mode, confirm the same visual distinction appears.
- Confirm the keyboard does not imply that a tie continuation retriggers sound.

## Phase 16 Practice Mode QA

- [ ] Practice Mode ON/OFF works.
- [ ] Next advances one practice event.
- [ ] Previous returns one practice event.
- [ ] Reset returns to the first event.
- [ ] Written note name is visible.
- [ ] Solfege / ドレミ display is visible.
- [ ] Chord events show chord-style text when present.
- [ ] Rest events show `休符` when present.
- [ ] Score highlight follows the practice step.
- [ ] Keyboard highlight follows the practice step.
- [ ] Enabling Practice Mode stops playback and audio.
- [ ] Pressing Play from Practice Mode returns to normal playback.
- [ ] Palette selection changes colors without changing layout or playback.
- [ ] Library / Recent files still open.
- [ ] Diagnostics sheet still opens.

Screenshots:

- `/tmp/doremipalette_phase16_practice_initial.png`
- `/tmp/doremipalette_phase16_practice_next.png`
- `/tmp/doremipalette_phase16_practice_note_name.png`
- `/tmp/doremipalette_phase16_practice_keyboard.png`
- `/tmp/doremipalette_phase16_practice_palette.png`
- `/tmp/doremipalette_phase16_practice_playback_interop.png`

## Note Gate / Rhythm Values QA

- [ ] Open `Rhythm Values Sample` from Library / sample scores.
- [ ] Whole note playback is longer than quarter note playback.
- [ ] Half note playback is longer than quarter note playback.
- [ ] Eighth note playback is shorter than quarter note playback.
- [ ] Quarter rest and eighth rest do not sound.
- [ ] Consecutive C4 notes are separated as repeated notes.
- [ ] Tempo 60 / 120 / 150 changes do not crash.
- [ ] Score highlight timing still follows the full event duration.
- [ ] Keyboard highlight still follows the current event.

Screenshots:

- `/tmp/doremipalette_gate_ratio_rhythm_sample.png`
- `/tmp/doremipalette_gate_ratio_playing.png`
- `/tmp/doremipalette_gate_ratio_tempo.png`

## Note Value Rendering QA

- [ ] Open `Rhythm Values Sample` from Library / sample scores.
- [ ] Whole notes are hollow noteheads with no stem.
- [ ] Half notes are hollow noteheads with stems.
- [ ] Quarter notes are filled noteheads with stems.
- [ ] Eighth notes are filled noteheads with stems and visible flags.
- [ ] Quarter and eighth rests are visually distinct.
- [ ] Dotted notes show a dot to the right of the notehead.
- [ ] Single-voice stems follow the MVP middle-line rule: below the middle line
  stems up, on/above the middle line stems down.
- [ ] Chord tones at the same onset share one stem direction; mixed up/down
  stems inside a single chord should not appear.
- [ ] Note Color ON/OFF keeps hollow noteheads readable.
- [ ] Staff Color ON/OFF does not obscure note value differences.
- [ ] Playback, keyboard highlight, and tempo controls still work on the rhythm
  values sample.

Screenshots:

- `/tmp/doremipalette_note_values_sample.png`
- `/tmp/doremipalette_note_values_note_color_on.png`
- `/tmp/doremipalette_note_values_note_color_off.png`
- `/tmp/doremipalette_note_values_playing.png`

## Chord Stem And Scroll Follow Regression QA

- [ ] Open `Notation Coverage Sample` or another score with a chord.
- [ ] Chord stems do not mix up/down directions inside the same chord.
- [ ] Note Color ON/OFF does not break chord noteheads or stems.
- [ ] Press Play and confirm the current-note highlight remains visible without
  repeatedly snapping back to a fixed score position.
- [ ] Use Previous / Next and confirm the highlighted note scrolls into view
  only when it leaves the viewport margin.
- [ ] Turn Practice Mode on, use Next / Previous / Reset, and confirm the
  practice step follows the same current-note scroll path.
- [ ] Tap a note and confirm the selected note remains visible.
- [ ] Repeat the scroll-follow check at `1.0x`, `1.5x`, and `2.0x`.
- [ ] Confirm playback scroll follow does not stop midway through Rhythm Values
  Sample or Notation Coverage Sample.
- [ ] Confirm rest/nil current-note moments do not permanently disable follow;
  the next pitched event should be visible again.

## Layout Bounds / Clipping Regression QA

- [ ] Open Rhythm Values Sample or Notation Coverage Sample.
- [ ] Confirm the highest noteheads, stems, and flags are not clipped.
- [ ] Confirm the lowest noteheads, stems, and flags are not clipped.
- [ ] Confirm ledger lines, rests, clefs, barlines, and repeat marks are inside
  the visible canvas.
- [ ] Repeat at `1.0x`, `1.5x`, and `2.0x`.
- [ ] Confirm Note Color ON/OFF and Staff Color ON/OFF do not introduce
  clipping.

Screenshots:

- `/tmp/doremipalette_fix_layout_bounds.png`
- `/tmp/doremipalette_fix_smooth_scroll_playing.png`
- `/tmp/doremipalette_fix_smooth_scroll_zoom2.png`
- `/tmp/doremipalette_fix_audio_missing_notes.png`
- `/tmp/doremipalette_fix_playback_after_rest.png`

Screenshots:

- `/tmp/doremipalette_fix_chord_stems.png`
- `/tmp/doremipalette_fix_scroll_follow_playing.png`
- `/tmp/doremipalette_fix_scroll_follow_next.png`
- `/tmp/doremipalette_fix_scroll_follow_practice.png`
- `/tmp/doremipalette_fix_scroll_follow_zoom2.png`

## Notation Coverage QA

- [ ] Open `Notation Coverage Sample` from Library / sample scores.
- [ ] Treble clef is visible on the upper staff.
- [ ] Bass clef is visible on the lower staff.
- [ ] Time signature is visible.
- [ ] Key signature is visible.
- [ ] Sharp, flat, and natural accidentals are visible.
- [ ] Whole, half, quarter, and eighth rests are visible and distinguishable.
- [ ] Dotted note dot is visible.
- [ ] Chord notes are visible as one event/onset.
- [ ] Ledger-line notes are visible.
- [ ] Repeat start/end barlines are visible.
- [ ] Same-system tie content is present and MVP tie curves are visible.
- [ ] Same-system slur content is present and MVP slur curves are visible.
- [ ] S6 sample simple beam groups are visible, and rests break beams.
- [ ] S6 sample mixed eighth/sixteenth beams show a primary beam plus secondary
  segment, connected to stem tips.
- [ ] S6 sample basic triplets show a bracket and number `3`.
- [ ] Dynamics / tempo text support is checked against
  `NOTATION_SUPPORT_MATRIX.md`.
- [ ] Play / Pause / Stop / Reset still work on this sample.
- [ ] Tempo changes still work on this sample.
- [ ] Library / Recent files and Diagnostics still open.

Screenshots:

- `/tmp/doremipalette_notation_coverage_initial.png`
- `/tmp/doremipalette_notation_coverage_symbols.png`
- `/tmp/doremipalette_notation_coverage_playing.png`

## SMuFL Rendering QA

SMuFL S1-S5 is active. Bravura glyph rendering is implemented in the SDK
renderer path and must remain layout-driven.

- [ ] Confirm Bravura loads in the app and SDK Example.
- [ ] Confirm fallback drawing is used when the font is unavailable.
- [ ] Confirm clef glyphs improve `Notation Coverage Sample` without shifting
  hit-test coordinates.
- [ ] Confirm accidental and rest glyphs respect note color / staff color
  settings.
- [ ] Confirm repeat dots and time signature glyphs remain layout-driven.
- [ ] Confirm dynamics remain documented as diagnostic-only unless represented
  by existing text annotations.
- [ ] Confirm notehead and flag glyph changes preserve `NoteID` and
  `ScoreElementID` stability.
- [ ] Confirm noteheads, accidentals, rests, flags, clefs, and time-signature
  digits are large enough to read on iPad without crowding nearby notes.
- [ ] Confirm whole, half, and black noteheads have a natural size balance.
- [ ] Confirm stems meet notehead edges and eighth/sixteenth flags attach to
  the stem end with the correct up/down direction.
- [ ] Confirm accidentals are readable but not oversized, and clef / key
  signature / time signature prefixes do not overlap.
- [ ] Confirm note accidentals sit close enough to their noteheads without
  colliding with the clef/key/time prefix area.
- [ ] Confirm whole, half, quarter, eighth, and sixteenth rests use a consistent
  readable size policy.
- [ ] Confirm `Notation Coverage Sample` visibly shows the 4/4 time signature
  on both treble and bass staves.
- [ ] Confirm `Rhythm Values Sample` still distinguishes whole, half, quarter,
  and eighth notes.
- [ ] Review snapshot diffs before recording new baselines.
- [ ] Confirm Library, Playback, Practice Mode, and Diagnostics behavior are
  unchanged by glyph rendering changes.

## Print MVP QA

- [ ] `印刷` button is visible in the top toolbar when a score is loaded.
- [ ] `譜面レイアウト` can switch between `横一段`, `A4`, and `トラック`.
- [ ] `横一段` keeps the existing single horizontal score flow.
- [ ] `A4` wraps measures into normal page-width systems.
- [ ] `トラック` shows keyboard-aligned falling playback-event bars and keeps the
  keyboard pitch alignment consistent with the regular keyboard view.
- [ ] Switching layouts does not change playback position, highlights, Library,
  Diagnostics, or imported score state.
- [ ] Tapping `印刷` opens the standard iOS print sheet.
- [ ] Print preview uses the A4 score layout even when the on-screen layout is
  `横一段` or `トラック`.
- [ ] Note Color / Staff Color settings are reflected in the generated PDF.
- [ ] Cancelling the print sheet returns to the score without changing
  playback, Practice Mode, Library, or Diagnostics state.
- [ ] Imported scores can also be sent to the print sheet.

## Phase S7 Repeat Playback QA

- [ ] `S7 Repeat Playback Sample` is covered by development fixtures/tests.
- [ ] `S7 Repeat Playback Sample` is not expected in the TestFlight-facing Library.
- [ ] Repeat start and repeat end barlines are visible.
- [ ] Playback order is Measure 1, Measure 2, Measure 3, Measure 2, Measure 3,
  Measure 4.
- [ ] Current-note score highlight returns to Measure 2 on the second pass.
- [ ] Keyboard highlight returns to the repeated measures on the second pass.
- [ ] Scroll follow returns to the repeated measures without losing manual
  scroll behavior.
- [ ] Practice Mode Next / Previous steps through the expanded repeat sequence.
- [ ] Reset returns to the expanded playback sequence start.
- [ ] Backward repeat without a start shows a warning diagnostic and falls back
  to the beginning.
- [ ] Nested repeats, endings, and D.C./D.S./Coda remain documented limitations.

## Phase S8 Repeat Endings QA

- [ ] `S8 Repeat Endings Sample` is covered by development fixtures/tests.
- [ ] App launch does not use `S8 Repeat Endings Sample` for TestFlight readiness.
- [ ] Repeat start and repeat end barlines are visible.
- [ ] First/second ending playback order is Measure 1, Measure 2, Measure 3,
  Measure 4, Measure 2, Measure 3, Measure 5, Measure 6.
- [ ] Measure 4 first ending is skipped on the second pass.
- [ ] Measure 5 second ending is skipped on the first pass and played on the
  second pass.
- [ ] Current-note score highlight, keyboard highlight, and scroll follow return
  to the repeated body and then continue to the second ending.
- [ ] Practice Mode Next / Previous steps through the expanded ending sequence.
- [ ] Unsupported nested repeat and complex ending cases are diagnostic-only
  rather than silent failures. Basic jump-only D.S. al Fine / al Coda cases are
  covered by Phase S10.

## Phase S9 Repeat Visuals QA

- [ ] `S9 Repeat Visuals Sample` is covered by development fixtures/tests.
- [ ] `S9 Repeat Visuals Sample` is not expected in the TestFlight-facing Library.
- [ ] App launch does not use `S9 Repeat Visuals Sample` for TestFlight
  readiness; Phase 17B uses `Ode to Joy Easy Variation`.
- [ ] First ending and second ending numbers are visible above the staff.
- [ ] Ending bracket lines and hooks are visible and do not replace repeat
  start/end barlines.
- [ ] Playback order still follows the S8 first/second ending sequence.
- [ ] Practice Mode Next / Previous still steps through the expanded sequence.
- [ ] Jump-marker structures outside the S10 jump-only MVP are visible in
  Diagnostics when present in a sample.
- [ ] Non-repeat samples still load, play, and show diagnostics normally.

## Phase S10 Complete Repeat Symbols QA

- [ ] S10 D.C./D.S./Coda and diagnostics cases are covered by development
  fixtures/tests.
- [ ] `S10 All Repeat Symbols Sample` is not expected in the TestFlight-facing
  Library; when restored in a development fixture set it should show repeat
  start/end, first/second endings, Segno, To Coda, Fine, D.C., D.C. al Fine,
  D.C. al Coda, D.S., D.S. al Fine, Coda, and D.S. al Coda for visual QA.
- [ ] D.C. al Fine playback order is 1, 2, 3, 4, 1, 2, 3.
- [ ] D.S. al Fine playback order is 1, 2, 3, 4, 2, 3.
- [ ] D.C. al Coda playback order is 1, 2, 3, 1, 2, 4, 5.
- [ ] D.S. al Coda playback order is 1, 2, 3, 4, 2, 3, 5, 6.
- [ ] Fine, D.C., D.S., Segno, Coda, and To Coda markers are visible as MVP
  text markers above the staff.
- [x] SDK parser tests cover MusicXML title fallback from
  `<credit-type>title</credit-type>` / `<credit-words>`.
- [x] SDK parser/playback tests cover clear jump-only D.C./D.S./Coda metadata
  encoded as MusicXML `<sound>` attributes, including `segno`, `coda`,
  `tocoda`, `dalsegno`, `dacapo`, and `fine`.
- [ ] Unsupported nested repeats, third endings, repeat+jump mixtures, and
  multiple Segno/Coda cases appear in Diagnostics instead of silently
  misplaying.
- [ ] Practice Mode, Previous / Next, score highlight, keyboard highlight, and
  scroll follow use the expanded S10 playback order.
- [ ] Non-repeat bundled samples load and play; historical S7/S8/S9 repeat QA
  coverage is maintained through development fixtures/tests rather than the
  TestFlight Library.

## Phase 17B TestFlight Readiness QA

- [ ] App launch opens `Ode to Joy Easy Variation` as the bundled MXL default.
- [ ] The Library shows only the two retained musetrainer-derived learning
  samples: `Ode to Joy Easy Variation` and `Fur Elise - Beginner Piano`.
- [ ] QA-only samples, including `Articulation & Dynamics Coverage Sample`,
  `D.S. / Coda Behavior Sample`, and `美女と野獣`, are not listed in the
  bundled app sample catalog or copied into the app bundle.
- [ ] `Happy Birthday To You Piano` is not listed in the bundled sample catalog
  or app bundle after the pre-TestFlight rights review. `12 Variations of
  Twinkle Twinkle Little Star`, `Canon in D`, and `The Entertainer` are also not
  listed.
- [ ] Prior S6/S7/S8/S9/S10/T2 QA samples are no longer expected in the bundled
  app sample catalog after the sample replacement; keep that coverage in
  development fixtures and automated tests rather than user-facing Library
  entries.
- [ ] Release build succeeds for `generic/platform=iOS`.
- [ ] Archive succeeds, or any failure is classified as signing / provisioning
  requiring user-side Apple Developer action.
- [ ] App display name is `DoReMi Palette`.
- [ ] Bundle identifier, version, build number, signing style, app icon, and
  launch screen settings are recorded in the release checklist.
- [ ] Privacy notes confirm no account, ads, tracking, analytics, or server
  upload of imported MusicXML.
- [ ] Import hardening confirms empty files and supported files larger than
  50 MB are rejected before parsing, with the existing score preserved.
- [ ] `ASSET_LICENSES.md` and `THIRD_PARTY_NOTICES.md` record Bravura 1.392,
  ZIPFoundation, the app icon, and the user-provided bundled MXL sample set.
- [ ] `Scripts/check-licenses.sh` and `Scripts/build-docc.sh` pass.
- [ ] `swift run DoReMiRendererDiagnostics LocalSamples` completes.
- [ ] iPad Simulator launches and captures Phase 17B screenshots under
  `/tmp/DoReMiPaletteQA/phase-17b/`.

## Articulation / Dynamics MVP QA

- [x] Parser tests cover staccato, accent, tenuto, fermata, dynamic marks, and
  crescendo / decrescendo wedges.
- [x] Layout and painter tests cover articulation marks, dynamic text, and
  hairpin elements without changing `NoteID` / `PlaybackEvent` identity.
- [x] Playback tests confirm normal notes remain full enough to distinguish
  staccato, tenuto uses a longer gate, fermata extends note/rest duration with
  a bounded clamp, accents increase velocity, and dynamics / hairpins affect
  velocity.
- [x] Layout tests confirm staccato, tenuto, and fermata marks remain close to
  their owning notes, upward/downward flagged fermatas use the correct glyph,
  cross-measure hairpins layout within a system, and dynamic text / hairpin
  lanes keep a minimum vertical separation.
- [x] Collision-lane tests cover expression marks against noteheads, stems,
  flags, beams, lyrics, fingerings, and articulations, including the Ode to Joy
  A4 measure 8 hairpin regression.
- [ ] Manual iPad QA: use a development fixture or imported local MusicXML with
  expression coverage to confirm staccato dots, accents, tenuto lines,
  fermatas, p/mp/mf/f/ff marks, and hairpins are visible and upright.
- [ ] Manual iPad QA: play the expression fixture and confirm normal notes are
  not too short, staccato is clearly shorter, accents are stronger, and
  dynamics / hairpins are audible at an MVP level. Final perceived volume and
  articulation balance still requires real-device listening.
- [ ] Expression hardening evidence should also be saved under
  `/tmp/DoReMiPaletteQA/expression-hardening/`.

## Piano Transpose MVP QA

- [x] App tests cover transpose model clamping to `-12...+12`.
- [x] App tests cover playback transpose for single notes and chords.
- [x] App tests cover rest and tie-continuation behavior remaining silent.
- [x] App tests cover keyboard highlight transposition without changing written
  `NoteID` / `ScoreLayout`.
- [x] App tests cover written versus sounding current-note display.
- [x] App tests cover written and sounding key display for major/minor keys.
- [x] App tests cover transpose setting persistence through `AppStorage` keys.
- [ ] Simulator manual check: key picker selection above the written key raises
  generated audio, score layout, and keyboard highlight together.
- [ ] Simulator manual check: key picker selection below the written key lowers
  generated audio, score layout, and keyboard highlight together.
- [ ] Practice Mode uses the same transpose setting for sounding note display
  and keyboard highlight.
- [ ] Repeat / D.C. / D.S. / Coda samples still play without crashing under a
  nonzero transpose.

## Phase T2 Score Display Transpose QA

- [x] SDK tests cover display transpose layout pitch changes without changing
  original note IDs.
- [x] SDK tests cover transposed key-signature layout and simple accidental
  rendering.
- [x] Parser tests cover MusicXML `<transpose>` metadata retention and
  diagnostics.
- [x] App tests cover display transpose relayout preserving playback event
  identity.
- [x] T2 display-transpose behavior is covered by SDK/app tests and
  development fixtures. The historical T2 sample files are not part of the
  TestFlight-facing Library.
- [ ] Simulator manual check: key picker (`C`, `C#`, `D`, ...) moves score
  notes, key signature, playback, and keyboard highlights together.
- [ ] Simulator manual check: score display transpose is enabled by default and
  there is no `譜面も移調` toggle in the control bar or settings.
- [ ] Simulator manual check: transposed accidentals are visible and not
  obviously duplicated.
- [ ] Simulator manual check: MusicXML transpose sample shows a diagnostic
  notice and does not silently apply concert-pitch conversion.
- [ ] Repeat / D.C. / D.S. / Coda samples still load and play with display
  transpose toggled on and off.

## Phase 17A Real iPad QA

Phase 17A must use a physical iPad, not only the Simulator. Record the device,
build, and runtime status before moving to TestFlight preparation.

Device/build status:

- [x] Physical iPad detected by `xcrun xctrace list devices`:
  `iPad Pro 2nd`, iPadOS `26.4.2`, device ID
  `00008027-001905583CC3802E`.
- [x] The device appears as an `xcodebuild -showdestinations` iOS destination.
- [x] Debug device build succeeds with
  `-destination 'platform=iOS,id=00008027-001905583CC3802E'`.
- [x] App bundle identifier is `com.doremipalette.app`.
- [ ] `devicectl` install / launch from Codex: blocked by a CoreDeviceService
  initialization timeout in the local developer environment.
- [ ] Manual Xcode Run install / launch on the physical iPad.

Runtime QA to complete after install/launch:

- [ ] App launches on the physical iPad.
- [ ] Bundled sample, `Rhythm Values Sample`, and `Notation Coverage Sample`
  open and render without clipping.
- [ ] Play / Pause / Stop / Reset work and generated audio is audible from the
  iPad or selected output route.
- [ ] Tempo 60 / 90 / 120 / 150 changes are audible and do not crash.
- [ ] Repeated same pitch, rest, tie continuation, mixed event, and chord
  playback match the Phase 16.5 rules.
- [ ] Current-note score highlight, keyboard highlight, and scroll follow work
  at `1.0x`, `1.5x`, and `2.0x`.
- [ ] Practice Mode ON/OFF, Next, Previous, Reset, note name, and solfege work.
- [ ] Files import succeeds for `.musicxml`, `.xml`, and `.mxl`.
- [ ] Invalid file and unsupported extension failures do not crash and preserve
  the current score.
- [ ] Library / Recent files open, reload recent entries, remove entries, and
  show missing-file recovery UI.
- [ ] Diagnostics opens and reflects parse/import status.
- [ ] Settings persist across app relaunch: note color, staff color, keyboard
  visibility, zoom, current-note display, and palette selection.

If `devicectl` reports a CoreDeviceService timeout, use Xcode's device window
and Product > Run path, then record the manual result here before treating
Phase 17A as complete.

## Playback Timing Hardening QA

- [x] Debug timing logs can be collected with `DOREMI_PLAYBACK_TIMING_LOG=1`
  and the autoplay launch environment.
- [x] Canon in D timing log saved:
  `/tmp/DoReMiPaletteQA/playback-timing/01_canon_timing.txt`.
- [x] Mozart Piano Sonata No. 16 timing log saved:
  `/tmp/DoReMiPaletteQA/playback-timing/02_mozart_timing.txt`.
- [x] Fur Elise - Beginner Piano timing log saved:
  `/tmp/DoReMiPaletteQA/playback-timing/03_fur_elise_timing.txt`.
- [x] The Entertainer timing log saved:
  `/tmp/DoReMiPaletteQA/playback-timing/04_entertainer_timing.txt`.
- [x] Twinkle Twinkle Little Star timing log saved:
  `/tmp/DoReMiPaletteQA/playback-timing/05_twinkle_timing.txt`.
- [x] Timing summary saved:
  `/tmp/DoReMiPaletteQA/playback-timing/05_summary.txt`.
- [ ] Real iPad listening check: confirm that the generated audio feels stable
  after the Simulator timing pass.
