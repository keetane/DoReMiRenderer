# Playback Audio Design

Phase 15 adds MVP audio playback to the DoReMi Palette app. Audio is an app feature, not a DoReMiRendererKit SDK feature.

## Responsibility Boundary

- DoReMiRendererKit provides `PlaybackEvent` and playback metadata.
- DoReMi Palette consumes `PlaybackEvent` through an app-side playback runtime.
- The audio engine lives under the DoReMi Palette app target.
- `DoReMiRendererKit` must not import AVFoundation.
- Renderer code must not own playback, scheduling, or audio state.
- Playback runtime must not depend on SwiftUI, ScrollView, or renderer internals.
- App state owns `currentNoteID` / current note IDs for score and keyboard highlighting.
- Playback must not mutate `ScoreLayout`, regenerate `NoteID`, or recalculate layout coordinates.

## MVP Runtime

The app playback runtime advances over the existing `PlaybackEvent` sequence.

- `Play` starts automatic cursor movement.
- `Pause` keeps the current event index.
- `Stop` stops audio and holds the current event.
- `Reset` returns the cursor to the first event.
- `Previous` / `Next` continue to move by event.
- Tempo is controlled by an app-side BPM value. The default is 120 BPM.
- Tempo changes are clamped to the safe BPM range used by the runtime. While
  stopped or paused, changing tempo only updates the app-side BPM value. While
  playing, the runtime cancels the current scheduling task, silences audio,
  keeps the current event index, and resumes from that event with the new tempo.

## Audio Engine

Phase 15 uses a generated tone audio engine in the app target.

- No external audio assets are required.
- No new external dependencies are added.
- Chords are played as the event's MIDI pitches at the same time.
- Rests do not trigger audio.
- Tie continuations do not trigger a new attack.
- If audio startup fails, the UI cursor can still advance.

## Known MVP Limits

- Tone quality is intentionally simple.
- Background audio is not supported.
- Full tuplet duration interpretation remains limited.
- Score-display transposition is not implemented. The app can transpose the
  generated playback and keyboard highlights by semitone, but written notation,
  key signature drawing, and accidentals remain unchanged.
- Latency optimization is not a Phase 15 goal.

## Piano Transpose MVP

DoReMi Palette has an app-side piano transpose setting for practice use.

- `transposeSemitones` is persisted with `AppStorage`, clamped to `-12...+12`,
  and defaults to `0`.
- `PlaybackSequenceBuilder` still emits written-pitch `PlaybackEvent` values.
- `PalettePlaybackRuntime` applies transpose immediately before calling the
  audio engine: `event.midiPitches.map { $0 + transposeSemitones }`.
- Out-of-range MIDI pitches are skipped safely; rests and tie-continuation-only
  events still do not call audio playback.
- Chords transpose every attack pitch. Repeated same-pitch events remain
  separate attacks after transposition.
- Score highlighting remains tied to written `NoteID` positions. Keyboard
  attack/continuation highlights use the sounding MIDI pitches.
- The current-note UI can show written note and sounding note side by side, for
  example `表示: C4 / ド` and `再生: D4 / レ (+2)`.
- Written key is derived from the parsed MusicXML key signature when available;
  sounding key is displayed by semitone-shifting that key for the active
  transpose value. The score itself is not re-keyed.

## Note Gate Ratio

Playback uses two durations:

- Event scheduling duration: the musical `PlaybackEvent.nominalDuration` converted by tempo.
- Sound duration: `eventDuration * noteGateRatio`.

The default `noteGateRatio` is `0.85`, clamped to `0.50...1.00`. This shortens
only the generated tone length. It does not change `PlaybackEvent`, `ScoreLayout`,
`NoteID`, current-note cursor timing, or score highlighting.

The runtime also applies a small minimum audible duration to pitched generated
tones. The minimum is capped by the event scheduling duration, so short notes do
not become longer musical events and rests/tie continuations still do not sound.

Before each pitched event, the app audio runtime silences the current generated
tone and then starts the next tone. Consecutive events with the same MIDI pitch,
such as `C4 -> C4`, therefore receive a small audible separation instead of
joining into a longer note. Rests and tie continuations still do not trigger a
new tone.

## Attack And Tie Continuation Display

`PlaybackEvent.noteIDs` and `PlaybackEvent.midiPitches` have separate roles:

- `noteIDs` are the notes that are visually current on the score. They may
  include tie continuations.
- `midiPitches` are the notes that start a new generated tone in that event.
  Tie stop-only notes are intentionally excluded.

DoReMi Palette derives an app-side highlight model from those two fields and
public score pitch lookup:

- Attack notes use the primary score and keyboard highlight.
- Tie continuation notes use a weaker secondary highlight.
- Mixed events can show both states at the same onset. Audio plays only the
  attack MIDI pitches.
- Rests do not highlight the keyboard.

Audio triggering follows the same rule: if an event has `midiPitches`, those
pitches are played even when the visual `noteIDs` also include tied
continuations. If `midiPitches` is empty, the event is silent.

Tie and slur curve drawing remains separate notation-rendering work. This rule
only explains why a visually current tied note may not produce a new sound.

## Repeat Playback Expansion

Phase S7/S8 expand repeat playback in `PlaybackSequenceBuilder`, before the
app-side runtime receives events:

- Simple forward/backward repeat sections are played for two passes.
- Phase S8 adds a first/second ending MVP for one clear repeat section: the
  first ending is played only on the first pass, the repeated body is revisited,
  and the second ending is played only on the second pass.
- A backward repeat without a forward start falls back to the beginning and
  emits a warning diagnostic.
- Jump markers are parsed into playback metadata. Basic D.C. al Fine is expanded
  only for jump-only scores without repeats/endings; D.S., Segno, Coda, To Coda,
  and complex jump combinations remain diagnostic-only.
- The original `ScoreDocument`, `ScoreLayout`, `NoteID`, and `PlaybackEvent`
  identity model are preserved; repeated passes reuse the same score note IDs.
- `PalettePlaybackRuntime` does not interpret MusicXML repeat syntax. It only
  advances over the already-expanded event sequence.
- Practice Mode uses the same expanded sequence, so repeated measures and
  supported endings are revisited by step navigation as well as automatic
  playback.
- Phase S9 adds first/second ending visual bracket rendering in layout and
  painting only; it does not change the expanded playback event order.
- Phase S10 hardens jump-only repeat navigation before TestFlight. D.S. al Fine,
  D.C. al Coda, and D.S. al Coda are expanded in `PlaybackSequenceBuilder` for
  clear scores without repeats/endings. D.C. al Fine remains supported.
- S10 also honors simple repeat counts up to four passes. Missing counts default
  to two; invalid or excessive counts emit diagnostics, with excessive counts
  clamped to the MVP safety limit.
- Loop prevention is explicit: expansion is bounded by jump-count and expanded
  event-count limits, and unsupported mixed structures fall back with
  diagnostics rather than risking infinite playback.

Unsupported repeat structures such as third endings, nested repeats, ambiguous
endings, repeat+jump mixtures, multiple Segno/Coda markers, and complex jumps
remain diagnostic-only.

## Piano Transpose And Display Transpose

DoReMi Palette treats piano transpose as an app-side setting:

- `transposeSemitones` is clamped to `-12...+12` and persists in `AppStorage`.
- Playback transposes `PlaybackEvent.midiPitches` immediately before audio
  output. Rests and tie-continuation-only events remain silent.
- Chords transpose every attack pitch, and repeated same-pitch events remain
  separate attacks after transposition.
- Keyboard attack/continuation highlights use the sounding MIDI pitches.

Phase T2 adds score display transpose as the app's default transpose mode:

- The app key picker (`C`, `C#`, `D`, ...) stores the selected target key as the
  existing clamped `transposeSemitones` value.
- The app asks the loader to rebuild layout from the original score with a
  display transpose option. Playback events are not rebuilt or renamed, and the
  runtime still only plays the already-expanded event list.
- `ScoreLayout` applies display-only pitch positions, key signatures, and
  simple accidental recomputation. Renderer and playback runtime do not parse
  MusicXML and do not perform score transposition themselves.

MusicXML `<transpose>` metadata is parsed and diagnosed, but automatic
transposing-instrument concert-pitch conversion is not enabled in this piano
MVP. This avoids hidden pitch changes for imported scores until the app has an
explicit concert/written pitch policy.

## Phase 16.5 Stabilization

Phase 16.5 treats generated-tone playback as stable enough to gate Phase 17 only
when the following remain true:

- pitch events call audio play;
- rests and continuation-only tie events do not start a new tone;
- mixed events play only the attack `midiPitches`;
- repeated same-pitch events remain separate attacks;
- short notes keep a minimum audible generated-tone duration without changing
  event scheduling;
- Practice Mode step movement keeps `PalettePlaybackRuntime` aligned before
  returning to normal playback.

Simulator and mock tests cover these rules, but real-device listening remains a
Phase 17 gate item because Simulator audio availability and latency can differ
from hardware.
