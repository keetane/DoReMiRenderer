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
- Repeat expansion is not implemented.
- Full tuplet duration interpretation remains limited.
- Transposition-aware playback remains limited.
- Latency optimization is not a Phase 15 goal.

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
