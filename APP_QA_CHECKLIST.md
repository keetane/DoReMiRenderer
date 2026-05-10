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
- [x] Bundled sample score appears.
- [x] Note color and staff color are visible.
- [x] `Previous` / `Next` controls are reachable.
- [x] Zoom controls are visible.
- [x] Keyboard can be shown with score still visible.
- [x] Keyboard current-note highlight is visible.
- [x] Diagnostics sheet opens without breaking score display.
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
- [x] Score is visible at `1.0x`.

## Import Checks

- [x] `.musicxml` fixture loads through the app loader.
- [x] `.xml` fixture loads through the app loader.
- [x] `.mxl` fixture loads through the app loader.
- [x] Invalid MusicXML enters an error state.
- [x] Unsupported extension enters an error state.
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
- [x] Note/staff color changes do not change layout or playback identity.
- [x] Zoom scale does not change the layout coordinate hit-test model.
- [ ] Full relaunch persistence manual check on physical app lifecycle.

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
- [ ] Tie content is present in the sample; visual tie arcs are currently not
  rendered and should be checked against `NOTATION_SUPPORT_MATRIX.md`.
- [ ] Slur content is present in the sample; current support is diagnostic-only.
- [ ] Dynamics / tempo text support is checked against
  `NOTATION_SUPPORT_MATRIX.md`.
- [ ] Play / Pause / Stop / Reset still work on this sample.
- [ ] Tempo changes still work on this sample.
- [ ] Library / Recent files and Diagnostics still open.

Screenshots:

- `/tmp/doremipalette_notation_coverage_initial.png`
- `/tmp/doremipalette_notation_coverage_symbols.png`
- `/tmp/doremipalette_notation_coverage_playing.png`

## Future SMuFL Rendering QA

SMuFL implementation is not active yet. The plan is tracked in
`SMUFL_INTEGRATION_PLAN.md`; this checklist is for future S2+ implementation
passes.

- [ ] Confirm the selected SMuFL font loads in the app and SDK Example.
- [ ] Confirm fallback drawing is used when the font is unavailable.
- [ ] Confirm clef glyphs improve `Notation Coverage Sample` without shifting
  hit-test coordinates.
- [ ] Confirm accidental and rest glyphs respect note color / staff color
  settings.
- [ ] Confirm repeat, dynamics, and time signature glyphs remain layout-driven.
- [ ] Confirm notehead and flag glyph changes preserve `NoteID` and
  `ScoreElementID` stability.
- [ ] Confirm `Rhythm Values Sample` still distinguishes whole, half, quarter,
  and eighth notes.
- [ ] Review snapshot diffs before recording new baselines.
- [ ] Confirm Library, Playback, Practice Mode, and Diagnostics behavior are
  unchanged by glyph rendering changes.

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
