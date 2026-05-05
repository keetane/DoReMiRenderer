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
- Private user files stay out of the repository.
- iCloud / cloud sync can come later.

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

## Phase 17: Real iPad / TestFlight Preparation

Purpose:

- Validate on-device behavior and prepare for TestFlight distribution.

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

1. Phase 14: Library / recent files
2. Phase 15: Audio playback
3. Phase 16: Practice mode
4. Phase 17: Real iPad / TestFlight preparation

If Phase 13 reveals a serious file-import issue, fix it before moving to Phase 14.
If Phase 15 reveals missing playback data, feed the requirement back into the SDK.
If Phase 16 reveals missing `NoteID`, pitch, or staff data, extend the SDK read
model minimally.

