# TestFlight Checklist

## Internal Testing Scope

- Open the default `Canon in D` sample.
- Open the bundled MXL samples from Library:
  - Canon in D
  - Fur Elise - Beginner Piano
  - Happy Birthday To You Piano
  - Ode to Joy Easy Variation
  - The Entertainer
- Verify Playback: Play, Pause, Stop, Reset, tempo picker, repeat/jump order,
  tied continuation behavior, and no stuck notes.
- Verify Practice Mode stepping, current-note marker, next-note marker, and
  keyboard highlight.
- Verify transpose key picker and display-transposed score.
- Verify palette drawer, seven-note color controls, line/all mode, keyboard
  color setting, and persistence.
- Verify MusicXML / MXL import, invalid-file diagnostics, Library / Recent
  reload, and missing-file handling.

## Known Limitations To Tell Testers

- Engraving is MVP quality, not publishing quality.
- Complex MusicXML may show diagnostics or partial rendering.
- Third endings, nested repeats, and complex jump mixtures remain limited.
- Full transposing-instrument concert pitch handling is diagnostic-only.
- Palette editing is note-class based; arbitrary RGB/HEX editing is not
  available.
- No account, cloud sync, iCloud library, MIDI input, microphone scoring, or
  background audio.

## Screenshot Folder

Use `/tmp/DoReMiPaletteQA/phase-17b/` for Phase 17B manual screenshots.
