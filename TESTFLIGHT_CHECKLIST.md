# TestFlight Checklist

## Internal Testing Scope

- TestFlight upload candidate: `0.1.1 (2)`.
- Wait for App Store Connect processing, then attach the build to internal
  testing and complete export compliance prompts.
- Formal App Store release candidate is tracked separately as `1.0 (3)`.

- Open the default `Ode to Joy Easy Variation` sample.
- Open the bundled samples from Library:
  - Ode to Joy Easy Variation
  - Fur Elise - Beginner Piano
  - Articulation & Dynamics Coverage Sample
- Confirm `Happy Birthday To You Piano` is not present in the bundled Library
  or app bundle; it remains only as a development fixture pending rights
  confirmation.
- Confirm no historical S6/S7/S8/S9/S10/T2 QA samples appear in the
  TestFlight-facing Library.
- Confirm the first-use guide can be completed or skipped and replayed from
  Settings.
- Verify Playback: Play, Pause, Stop, Reset, tempo picker, repeat/jump order,
  tied continuation behavior, and no stuck notes.
- Verify large-score playback performance on at least two heavier samples.
  The 2026-05-26 final pass spot-checked Canon in D, Mozart Piano Sonata No. 16,
  and Fur Elise with CPU readings saved under
  `/tmp/DoReMiPaletteQA/performance-final/`.
- Verify playback timing/jitter on heavy samples. The 2026-05-27 iPad Simulator
  timing pass saved Canon, Mozart, Fur Elise, The Entertainer, and Twinkle logs
  under `/tmp/DoReMiPaletteQA/playback-timing/`; all measured p95 jitter values
  were below 50 ms. Real iPad listening is still required before final sign-off.
- Verify the critical regression pass: score symbols draw upright, current-note
  follow moves the score during playback, and metronome clicks follow parsed
  meter. Evidence is saved under
  `/tmp/DoReMiPaletteQA/critical-regression/`.
- Verify the metronome meter-sync follow-up: 3/4 and 4/4 click plans put strong
  beat 0 at every measure head, 6/8 large-beat/subdivision plans use the
  expected offsets, and mid-playback ON starts from the next planned click.
  Evidence is saved under `/tmp/DoReMiPaletteQA/metronome-meter-fix/`.
- Verify Articulation / Dynamics MVP: the self-authored coverage sample shows
  staccato, accent, tenuto, fermata, dynamic marks, and crescendo/decrescendo
  hairpins; staccato, tenuto, and fermata marks sit close to their owning
  notes; upward/downward flagged fermatas face correctly; dynamic text and
  hairpins do not visibly collide; playback makes staccato shorter than normal
  notes, tenuto longer, applies bounded fermata extension, and applies audible
  velocity changes for accents, dynamics, and hairpins. User-side listening
  remains required for final musical judgment.
- Verify Practice Mode stepping, current-note marker, next-note marker, and
  keyboard highlight.
- Verify transpose key picker and display-transposed score.
- Verify palette drawer, seven-note color controls, line/all mode, keyboard
  color setting, and persistence.
- Verify measure display and inline measure jump between Previous and Next.
- Verify pinch zoom and that opening/reloading a score resets zoom to 100%.
- Verify MusicXML / MXL import, invalid-file diagnostics, Library / Recent
  reload, and missing-file handling.

## Known Limitations To Tell Testers

- Engraving is MVP quality, not publishing quality.
- Complex MusicXML may show diagnostics or partial rendering.
- Third endings, nested repeats, and complex jump mixtures remain limited.
- Full transposing-instrument concert pitch handling is diagnostic-only.
- Palette editing is note-class based; arbitrary RGB/HEX editing is not
  available.
- First-use guide anchors are best-effort SwiftUI coach marks; if an anchor
  cannot be measured, the guide falls back rather than blocking use.
- No account, cloud sync, iCloud library, MIDI input, microphone scoring, or
  background audio.

## Screenshot Folder

Use `/tmp/DoReMiPaletteQA/phase-17b/` for Phase 17B manual screenshots.
