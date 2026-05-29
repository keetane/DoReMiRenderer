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

## Playback Performance Hardening

The TestFlight readiness performance pass separates audio scheduling from heavy
score UI work so large bundled MXL samples do not make playback drift.

- `ScoreCanvasView` keeps static score drawing keyed separately from current
  note cursor updates. Runtime playback uses a UIKit static canvas path, while
  XCTest/snapshot rendering falls back to SwiftUI Canvas for deterministic
  flattened screenshots.
- Current-note highlights are drawn as lightweight overlays instead of
  repainting the full score on every cursor tick.
- Large A4/performance layouts avoid all-note geometry measurement and repeated
  recentering during playback. Current-note follow uses stable measure anchors
  and only scrolls when the playback note leaves the viewport margin, while
  manual navigation and measure jump remain immediate.
- Current-note text updates are throttled while playback is running. The audio
  event scheduler remains independent from those UI refreshes.
- `ScorePainter` uses visible-rect culling and caches CoreText/SMuFL text lines
  to avoid redrawing offscreen notation and rebuilding glyph text each frame.
- `SimpleToneAudioEngine` caches generated audio buffers and reuses short
  single-pitch buffers instead of rebuilding tones for every event.
- The layout lookup table tolerates duplicate structural `ScoreElementID`
  values by keeping the first element for reference lookup, avoiding crashes on
  large third-party samples while preserving note IDs and playback events.
- The static UIKit/CoreGraphics rendering path compensates CoreText/SMuFL glyph
  drawing for the flipped y-axis locally in the glyph helper; `ScoreLayout`
  coordinates and hit testing remain unchanged.

Final Simulator spot checks on 2026-05-26 covered Canon in D, Mozart Piano
Sonata No. 16, and Fur Elise. Point-in-time CPU samples stayed in the low
single-to-low-double digit range in the iPad Pro 13-inch (M5) simulator, and
`ScoreStaticCanvasUIView.draw(_:)` was not observed as a continuous hot path in
the sampled playback windows. Real-device audible timing should still be
confirmed before broad external TestFlight distribution.

The 2026-05-27 critical regression pass rechecked the playback path after
restoring current-note follow and fixing SMuFL glyph orientation. Ode to Joy
Simulator timing recorded average jitter around 11.6 ms and p95 around 26.3 ms
under `/tmp/DoReMiPaletteQA/critical-regression/`, with follow restored through
measure anchors rather than all-note anchor measurement.

## Audio Engine

Phase 15 uses a generated tone audio engine in the app target.

- No external audio assets are required.
- No new external dependencies are added.
- Chords are played as the event's MIDI pitches at the same time.
- Rests do not trigger audio.
- Tie continuations do not trigger a new attack.
- If audio startup fails, the UI cursor can still advance.

## Metronome MVP

The metronome is also app-owned. DoReMiRendererKit does not import
AVFoundation and the renderer does not know about metronome state.

- `metronomeEnabled` is persisted in DoReMi Palette app settings and defaults
  to OFF.
- `PalettePlaybackRuntime` starts the metronome when Play starts and the
  setting is enabled.
- Pause, Stop, Reset, and playback end cancel the metronome task and silence
  generated audio through the existing app audio layer.
- The click interval follows the current runtime tempo. Tempo changes while
  playing restart runtime scheduling and resync the metronome from the current
  playback event.
- The runtime builds an app-side metronome click plan from the expanded
  `PlaybackEvent` sequence. Each planned click records the measure occurrence,
  score measure ID, beat index within that measure, absolute playback time,
  time signature, and accent. This keeps every 3/4 and 4/4 measure anchored so
  beat 0 is strong, including after repeat and jump expansion.
- Turning the metronome ON during playback does not treat that toggle moment as
  beat 1. The runtime uses the current event's monotonic start time plus the
  precomputed measure-based click plan, then starts from the next planned click
  boundary.
- Strong, medium, and weak clicks use generated tones with distinct pitch,
  duration, and velocity. Click sound styles (`Classic`, `Soft`, `Wood`, and
  `Electronic`) change those generated parameters without adding audio assets.
- The runtime reads parsed MusicXML time signatures from playback metadata and
  carries them forward by measure. Simple meters such as 3/4 use the score's
  beat count for each measure occurrence, so beat 1 is accented every measure,
  not merely every N clicks from playback start. If no time signature is
  available, the app falls back to 4/4.
- Compound meters `6/8`, `9/8`, and `12/8` support two modes. `大拍`
  groups dotted-quarter large beats by default (`6/8` becomes two clicks per
  measure), while `細分` clicks each written eighth subdivision with medium
  accents on secondary large beats.
- Tap tempo records the most recent tap intervals, resets after long gaps, and
  clamps the result to the runtime's 30...240 BPM range. During playback it is
  treated as a tempo change and resyncs the metronome from the current
  playback position.
- User-edited arbitrary accent patterns, imported click samples, standalone
  practice metronome, and sample-accurate scheduling remain future work.
- Practice Mode does not start a standalone metronome. If the user presses Play
  from Practice Mode, the normal playback path is used and the metronome follows
  the same Play behavior.

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

The default `noteGateRatio` is `1.00`, clamped to `0.50...1.00`. Lower manual
values shorten only the generated tone length. They do not change
`PlaybackEvent`, `ScoreLayout`, `NoteID`, current-note cursor timing, or score
highlighting.

The runtime also applies a small minimum audible duration to pitched generated
tones. The minimum is capped by the event scheduling duration, so short notes do
not become longer musical events and rests/tie continuations still do not sound.

Before each pitched event, the app audio runtime silences the current generated
tone and then starts the next tone. Consecutive events with the same MIDI pitch,
such as `C4 -> C4`, therefore receive a small audible separation instead of
joining into a longer note. Rests and tie continuations still do not trigger a
new tone.

## Playback Expression MVP

Articulation and dynamics remain SDK-domain data and app-side audio behavior:

- `PlaybackEvent.expression` carries articulation kinds, a gate scale, a
  velocity scale, the active dynamic mark, and bounded fermata duration
  extension metadata.
- Normal articulation expression changes generated tone length and velocity.
  Fermata is the only MVP expression that extends event scheduling duration;
  it is clamped to avoid tempo drift and does not reshape the metronome click
  plan. `NoteID` and `ScoreLayout` identity remain stable.
- Normal notes keep the app's full-length `noteGateRatio` behavior and the
  generated-tone buffer now allows a longer audible sustain window. Staccato
  scales the sound window to less than half of the note duration; tenuto can
  extend slightly beyond the normal gate within a bounded safety margin; accent
  and marcato increase generated-tone velocity.
- Dynamic marks map to coarse generated-tone velocity levels (`p`, `mp`, `mf`,
  `f`, `ff`, etc.). Crescendo and decrescendo wedges apply a coarse linear
  velocity interpolation in the MVP. The velocity range is intentionally broad
  enough for user testing to distinguish dynamics with the generated-tone
  engine.
- Velocity is passed to the app audio engine and participates in the existing
  bounded audio-buffer cache. No audio asset or SDK AVFoundation dependency is
  added.

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
- DoReMi Palette's measure jump UI also uses the expanded sequence. A jump to
  a score measure selects the first matching event in that sequence, updates
  current-note state, and pauses active playback before moving so generated
  audio and metronome scheduling cannot continue from the previous position.
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

## Playback Timing Hardening

The DoReMi Palette app runtime now schedules playback against a monotonic
absolute clock. Each event has an expected elapsed playback time, and the next
sleep duration is calculated from the original playback start plus accumulated
musical intervals. This prevents a late wake-up, SwiftUI update, or scroll/highlight
delay from shifting every later event.

Generated audio is still an app-side responsibility. `DoReMiRendererKit` has no
AVFoundation dependency and does not know about playback scheduling. Before
playback starts, the app prewarms the generated-tone engine and prepares
upcoming pitch/duration buffers so first-use buffer synthesis is not performed
inside the note onset path. `SimpleToneAudioEngine` still performs immediate
player-node scheduling; sample-accurate future scheduling remains outside the
MVP.

DEBUG builds support timing capture with:

- `DOREMI_AUTOPLAY_PLAYBACK=1`
- `DOREMI_AUTOPLAY_SAMPLE_RESOURCE=<resourceName>`
- `DOREMI_PLAYBACK_TIMING_LOG=1`
- `DOREMI_PLAYBACK_TIMING_LOG_PATH=/tmp/DoReMiPaletteQA/playback-timing/<file>.txt`

The 2026-05-27 iPad Simulator timing pass measured:

- Canon in D: average 6.542 ms, p95 15.295 ms, max 19.200 ms.
- Mozart Piano Sonata No. 16: average 6.052 ms, p95 14.922 ms, max 28.474 ms.
- Fur Elise - Beginner Piano: average 9.914 ms, p95 17.391 ms, max 18.768 ms.
- The Entertainer: average 8.117 ms, p95 18.273 ms, max 26.375 ms.
- Twinkle Twinkle Little Star: average 15.715 ms, p95 31.072 ms, max 32.440 ms.

Simulator timing is a regression signal, not a substitute for final real-device
listening. Real iPad listening remains required before treating playback feel as
fully signed off.
